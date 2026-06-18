# 缝隙阵列参数审计（当前 4x4 MATLAB + HFSS 版本）

## 1. 这份审计的目的

当前工程已经能生成几何，也已经做了 HFSS 参数化，但“能画出来”不等于“参数链是对的”。

这份文档只回答 3 个问题：

1. 缝隙阵列常规设计里，哪些量应该按固定公式或标准流程来定。
2. 当前代码里，哪些量已经接近这个流程，哪些还是开发期的经验占位。
3. 下一步应该保留哪些顶层参数，哪些参数必须降级为派生量、隐藏量或提取量。

## 2. 常规的缝隙阵列设计链

对现在这个中心馈电、主馈波导耦合到多条支路、支路上再开纵向辐射缝的结构，比较常规的初始设计链应当是：

1. 系统指标
   频率 `f0`、目标增益、极化、旁瓣、效率、阵面规模。
2. 波导与模参数
   选定矩形波导后，先算自由空间波长 `lambda0 = c / f0`，再算工作模导波波长 `lambda_g`。
3. 阵列规模与间距
   阵元数 `Nx, Ny`，以及支路间距、缝间距。
   对驻波谐振缝隙阵列，常用起点是相邻缝中心距约 `lambda_g / 2`。
4. 支路辐射缝初值
   包括缝长、缝宽、偏置、末端短路距离。
   常见起点是：
   - 相邻缝中心距约 `lambda_g / 2`
   - 最外侧缝到短路端约 `lambda_g / 4`
   - 缝宽先取较窄的固定值
   - 缝长先取接近谐振长度，再做单支路提取修正
   - 缝偏置由目标归一化电导反算
5. 主馈耦合斜缝初值
   这一步不能直接照搬辐射缝公式。
   它应当有自己的耦合模型，最少也要有单元提取曲线，通常由斜缝角度、长度、偏置共同决定耦合量。
6. 提取与回标
   先做单辐射缝提取、再做主馈耦合缝提取、再做单支路、最后做整板。
   也就是说，整板不是第一性原理直接一步到位，而是最后一级验证。

## 3. 文献里比较稳定的几条基线

下面这些属于可以作为“初始模型常识”的东西：

- 矩形波导 TE10 模的导波波长由波导截面和频率决定，不应手调。
- 谐振支路上的相邻辐射缝中心距，常用 `lambda_g / 2` 作为起点。
- 最外侧辐射缝到短路端，常用 `lambda_g / 4` 作为起点。
- 辐射缝宽常先取较小固定值，再结合加工能力和提取结果修正。
- 辐射缝偏置与归一化电导之间有标准近似关系，偏置不是任意拍脑袋给比例。
- 主馈耦合斜缝的耦合量不能只靠“角度越大耦合越强”这种口头规律，需要专门的阻抗/导纳关系或 HFSS 提取曲线。

可参考：

- AUB 学位论文第 4 章给出纵向谐振缝的长度、宽度、偏置、`lambda_g / 2` 间距和 `lambda_g / 4` 端距等起始公式与设计流程。[AUB thesis PDF](https://scholarworks.aub.edu.lb/bitstream/handle/10938/10833/ed-60.pdf?sequence=3)
- 同一论文第 6 章给出主馈耦合斜缝的输入阻抗模型，说明它应由独立的耦合缝关系确定，而不是直接复用辐射缝模型。[AUB thesis PDF](https://scholarworks.aub.edu.lb/bitstream/handle/10938/10833/ed-60.pdf?sequence=3)
- 一篇综述类文章也强调了 slotted-waveguide array 的常规流程是“解析初值 + 全波提取/优化”，不是直接在整板上拍一堆自由参数。[MDPI review](https://www.mdpi.com/2079-9292/10/11/1311)

## 4. 当前代码逐项审计

### 4.1 已经比较接近标准流程的部分

#### `spec_to_array.m`

文件：[+synthesis/spec_to_array.m](../+synthesis/spec_to_array.m)

- `lambda0`、波导选择、`lambda_g` 计算路径是合理的。
- `dx_mm = 0.5 * lambda_g`、`dy_mm = 0.5 * lambda_g` 这一层作为初始阵列步长是合理起点。
- 固定 `4x4` 只是在开发期缩小模型尺寸，本身不违背设计逻辑。

判断：

- 这部分可以保留。
- 但 `dx_mm` 和 `dy_mm` 最好在命名上区分“主馈支路间距”和“支路内缝距”，避免后面混淆。

#### `power_to_conductance.m`

文件：[+synthesis/power_to_conductance.m](../+synthesis/power_to_conductance.m)

- 当前做法是先把二维口径功率分布 `Wpow` 归一化，再把支路功率和支路内缝功率拆出来。
- 对对称中心馈电的驻波谐振基线，按“一个谐振支路上的归一化电导总和约束”为 1 来分配，是可以接受的第一步。

判断：

- 这部分属于“合理的一阶口径分配基线”。
- 它不是问题的主要来源。
- 后面真正影响结果的，是这些目标电导如何映射到几何参数。

#### `build_panel_topology_model.m` 里的位置关系

文件：[+hfssapi/build_panel_topology_model.m](../+hfssapi/build_panel_topology_model.m)

- 在闭式模式下，支路间距直接取 `arrayData.dx_mm`。
- 支路内缝距取 `slotPitch = 0.5 * lambda_g`。
- 主馈长度用 `mainLen = (Nx + 1) * branchPitch`，这样最外侧耦合缝到主馈端面是 `lambda_g / 2`。

判断：

- 这些属于正确的“拓扑级位置约束”。
- 现在几何看起来顺眼，主要就是因为这一层已经从之前的乱设值回到了常规间距规则。

### 4.2 目前最不对的部分

#### `design_radiating_slot.m` 只算对了一半

文件：[+utils/design_radiating_slot.m](../+utils/design_radiating_slot.m)

当前实现里有三类情况：

1. 可以保留的
   - `slot.pitch_mm = 0.5 * lambda_g`
   - `slot.backshort_mm = 0.25 * lambda_g`
   - `slot.offset_mm` 走“目标电导反算偏置”的思路
2. 可以作为近似起点，但不能当最终公式的
   - `slot.length_mm` 现在是一个多项式映射
   - 它数值上大致落在“接近谐振长度”的区间，但这不是一个通用到可以直接宣称正确的教材公式
3. 明显可疑的
   - `slot.width_mm = b * 0.0625 / 0.9`

这一条最怪。

当前代码把缝宽写成了波导窄边 `b` 的比例，但常见初值写法是按波导宽边 `a` 给一个较小比例量级。
也就是说，当前这里至少在“参照哪个尺寸”上就已经很可疑。

判断：

- 这部分是当前“参数看起来很怪”的主要来源之一。
- 应当改成：
  - 先明确辐射缝宽到底采用哪条文献起始式
  - 如果只是初值，就明确标成“初值”
  - 不要把它伪装成已经被验证过的闭式公式

#### `design_coupling_slot.m` 目前本质上还是占位函数

文件：[+utils/design_coupling_slot.m](../+utils/design_coupling_slot.m)

当前实现是：

- 直接复用辐射缝的长度和宽度
- 再用 `thetaEq = 0.5 * asind(sqrt(gUse))` 去生一个倾角
- 然后再用 `thetaMin/thetaMax` 硬裁剪

这不是标准的主馈耦合斜缝设计。

主馈耦合缝和支路辐射缝不是一回事。
耦合斜缝的本质是“两个波导之间的耦合器”，它应该有自己的等效阻抗/导纳模型，至少要有自己的提取曲线。

判断：

- 这一块当前只能叫“开发占位”。
- 它不应该再被包装成闭式公式。
- 如果继续拿它直接推整板 S11 和方向图，结果偏差大是正常现象。

### 4.3 `main_demo.m` 里的顶层输入混进了很多不该暴露的量

文件：[main_demo.m](../main_demo.m)

目前顶层 `spec` 同时混着三类东西：

1. 应保留的系统输入
   - `f0_Hz`
   - `gain_dBi`
   - `sll_dB`
   - `efficiency`
   - `waveguide.a_mm`
   - `waveguide.b_mm`
   - `array.Nx`
   - `array.Ny`
2. 可以保留的工程输入
   - `wall_mm`
   - `feed_stem_length_mm`
   - `region_pad_mm`
3. 不应再作为“设计主参数”暴露的开发项
   - `main_margin_lambda0`
   - `branch_margin_lambda0`
   - `branch_pitch_margin_mm`
   - `rad_slot_end_clear_mm`
   - `cpl_slot_length_mm`
   - `cpl_slot_width_mm`
   - `cpl_slot_angle_seed_deg`
   - `main_stub_extra_mm`
   - `mapping.max_offset_ratio`
   - `mapping.min_offset_ratio`
   - `mapping.rad_length_ratio`
   - `mapping.cpl_angle_deg`
   - `formula.cpl_angle_min_deg`
   - `formula.cpl_angle_max_deg`

判断：

- 这些参数的共同问题不是“数量多”，而是物理身份不清楚。
- 有些本来应当是派生量。
- 有些本来应当是提取模型的输出。
- 有些只是早期为了先画出几何临时加的经验量。

## 5. 为什么现在 HFSS 的参数看起来“很多但没法调”

问题不在于“有没有参数化”，而在于“参数化的层级不对”。

当前 `build_panel_topology_model.m` 已经把很多几何量都注册成了 HFSS Local Variables，但它们大多数只是几何展开后的逐缝参数，例如：

- `x_center_01`
- `slot_y_01`
- `cpl_len_01`
- `cpl_ang_01`
- `rad_len_b01_k01`
- `rad_off_b01_k01`

这种参数化对脚本生成是有用的，但对人工调试和 Optimetrics 并不好用，因为：

- 它把“公式产生的派生量”和“真正该扫的独立变量”混在一起了。
- 它按单缝展开，破坏了对称性。
- 它让调参入口太碎，反而看不出物理规律。

所以，你觉得“参数很怪”，本质上是两件事叠加：

1. 顶层混入了不少不该保留的经验量。
2. HFSS 里暴露的是逐元素几何变量，而不是物理上真正独立的设计变量。

## 6. 建议保留的参数集

如果接下来要把模型收敛成“真能调试”的参数化版本，我建议把参数分成 4 层。

### A. 系统输入层

这层是你真正要输入的东西：

- `f0_Hz`
- `gain_dBi` 或固定 `Nx, Ny`
- `sll_dB`
- `efficiency`
- `waveguide.name` 或 `a_mm, b_mm`
- `array.mode`
- `array.Nx, array.Ny`

### B. 公式派生层

这层由程序自动算，不应该手调：

- `lambda0`
- `lambda_g`
- `branch_pitch`
- `slot_pitch`
- `main_len`
- `branch_len`
- `x_center_i`
- `slot_y_k`

### C. 初值模型层

这层是“公式初值”，可以保留为少量、清晰、成组的可调参数：

- `rad_slot_width_init`
- `rad_slot_length_init`
- `rad_offset_pair_1 ... rad_offset_pair_(Ny/2)`
- `cpl_slot_width_pair_1 ... cpl_slot_width_pair_(Nx/2)`
- `cpl_slot_length_pair_1 ... cpl_slot_length_pair_(Nx/2)`
- `cpl_slot_angle_pair_1 ... cpl_slot_angle_pair_(Nx/2)`

注意：

- 这里的“pair”是对称对，而不是每个缝各给一个变量。
- 这样既保留对称性，也保留调参自由度。

### D. 提取/拟合层

这层不应该在整板里拍脑袋，而应该来自：

- 单辐射缝提取模型
- 单耦合斜缝提取模型
- 单支路回标

也就是说，真正成熟的脚本结构应当是：

`目标口径分布 -> 目标电导 -> 提取得到几何初值 -> 单支路修正 -> 整板验证`

而不是：

`目标口径分布 -> 直接在整板里凭经验设长度/偏置/倾角`

## 7. 我对当前版本的结论

一句话总结：

当前版本的“位置关系”已经基本回到了缝隙阵列常规布局，但“几何尺寸映射”还没有回到常规设计链。

更具体一点：

- 阵列尺寸、波导、`lambda_g`、`lambda_g/2` 间距这一层，已经大体正确。
- 辐射缝的电导映射思路是对的，但缝宽和缝长公式还没整理干净。
- 主馈耦合斜缝目前还是开发占位，不应拿它代表最终设计方法。
- HFSS 虽然参数化了，但当前暴露的是“展开后的几何量”，不是“适合调试的物理参数集”。

## 8. 下一步最合理的动作

在你确认这份整理没问题之后，下一步我建议只做下面两件事，不再同时乱动很多层：

1. 先把 `design_radiating_slot.m` 整理成真正清晰的“辐射缝初值公式函数”
   - 明确缝宽初值
   - 明确缝长初值
   - 明确偏置反算公式
   - 把不属于辐射缝初值公式的经验量全部删掉
2. 再把 `design_coupling_slot.m` 降级为“提取驱动接口”
   - 不再伪装成闭式公式
   - 只保留很少的对称参数
   - 后续由耦合缝提取模型来回填

如果按这个顺序走，后面你调试时看到的参数就会是“像缝隙阵列设计参数”的样子，而不是一堆拼出来的几何碎片变量。
