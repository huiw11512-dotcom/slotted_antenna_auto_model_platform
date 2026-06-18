# 耦合缝提取与拟合流程

当前结构的馈电层 longitudinal coupling slot 不再直接套用辐射缝的闭式公式，而是改成：

1. 先用理论链锁死主结构
- `p_cpl = lambda_g(cpl)/2`
- `p_rad = lambda_g(rad)/2`
- `cpl_backshort = lambda_g(cpl)/4`
- `rad_backshort = lambda_g(rad)/4`
- `a_rad = lambda_g(cpl)/2 - t`

2. 单独建立耦合缝提取模型
- 文件：`+hfssapi/build_coupling_slot_extract_model.m`
- 端口定义：
  - `Port1`：主馈波导输入
  - `Port2`：被耦合支路输出
- 输出报告：
  - `CplS11`
  - `CplS21Mag`
  - `CplS21Phase`

3. 用提取结果建立耦合缝拟合表
- 文件：`+utils/design_coupling_slot.m`
- 默认读取：
  - `spec.coupling_slot.fit_table`
- 如果没有实测/提取表，则回退到：
  - `+utils/default_coupling_slot_fit.m`

4. 主模型调用拟合表
- `build_panel_topology_model.m` 只负责把目标 `feed_pair_g` 映射到：
  - `cpl_len_xx`
  - `cpl_w_xx`
  - `cpl_off_xx`

## 建议的实操顺序

1. 先把整板改成 `uniform`
2. 跑 `coupling_slot_extract`
3. 扫 `slot_off` 和 `slot_len`
4. 找到满足目标 `|S21|` 且 `angle(S21)` 连续、`S11` 较好的点
5. 把这些点整理成 `fit_table`
6. 再切回 `Taylor` 或 `Chebyshev`

## 为什么这么做

辐射缝的导纳、偏置、谐振长度有较成熟的闭式近似；但层间 longitudinal coupling slot 在两层波导和 T 结馈电网络里，实际更敏感的是：

- 耦合量
- 相位
- 主馈驻波

这部分文献通常也是先做 HFSS 提取，再做 polynomial fit 或查表，不是直接靠一条闭式公式完成整板设计。
