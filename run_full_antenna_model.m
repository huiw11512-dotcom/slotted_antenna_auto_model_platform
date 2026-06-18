% Unified interactive entry for the slotted-waveguide array model.
% Supports both HFSS and CST generation from the same parameter GUI.

clear; clc;
repoRoot = fileparts(mfilename('fullpath'));
addpath(genpath(repoRoot));
cd(repoRoot);
fprintf('Slotted waveguide designer GUI: split-tab direct-CST build 2026-04-27-1\n');

local_run_main(repoRoot);

function local_run_main(repoRoot)
baseSpec = build_demo_spec();
if local_has_modern_ui()
    local_get_spec_from_app(baseSpec, repoRoot);
    return;
end

spec = local_get_spec_from_console(baseSpec, repoRoot);
if isempty(spec)
    return;
end
local_generate_model(spec, repoRoot);
end

function [result, ok] = local_generate_model(spec, repoRoot)
result = [];
ok = false;
try
    fprintf('\n--- 设计输入 ---\n');
    fprintf('频率: %.3f GHz, 扫频 %.3f-%.3f GHz\n', ...
        spec.f0_Hz/1e9, spec.hfss.sweep_f1_GHz, spec.hfss.sweep_f2_GHz);
    fprintf('阵列: %d x %d, 幅度分布 %s, 目标副瓣 %.1f dB\n', ...
        spec.array.Nx, spec.array.Ny, spec.synth_x.type, spec.sll_dB);
    fprintf('波导: %s, a=%.4f mm, b=%.4f mm, 壁厚=%.4f mm\n', ...
        spec.waveguide.name, spec.waveguide.a_mm, spec.waveguide.b_mm, spec.waveguide.t_mm);
    fprintf('仿真后端: %s\n', upper(spec.solver));
    fprintf('输出目录: %s\n', spec.output_dir);

    waitHandle = local_open_progress_dialog(spec);
    cleanupWait = onCleanup(@() local_close_progress_dialog(waitHandle));

    result = synthesize_waveguide_panel_model(spec);

    disp('--- 完整天线模型已生成 ---');
    disp(result.summary);
    disp('--- 生成文件 ---');
    disp(result.generated_files);

    local_show_success_dialog(spec, result);
    ok = true;
catch ME
    local_handle_run_error(ME, repoRoot);
end
end

function tf = local_has_modern_ui()
tf = usejava('awt') && usejava('swing') && ...
    exist('uifigure', 'file') == 2 && exist('uigridlayout', 'file') == 2;
end

function local_get_spec_from_app(baseSpec, repoRoot)
db = utils.waveguide_db();
defaultGuide = local_recommend_waveguide_for_band(baseSpec, db);
defaultHfssPath = local_find_hfss_executable(baseSpec);
defaultCstPath = local_find_cst_executable(baseSpec);
defaultPythonPath = local_find_python_executable(baseSpec);

screenSize = get(groot, 'ScreenSize');
figW = min(1860, max(1500, screenSize(3) - 70));
figH = min(980, max(820, screenSize(4) - 110));
figX = max(30, screenSize(1) + 0.5 * (screenSize(3) - figW));
figY = max(30, screenSize(2) + 0.5 * (screenSize(4) - figH));

fig = uifigure( ...
    'Name', '缝隙波导阵列设计器 - HFSS/CST 版 - 分栏Tab 2026-04-27-1', ...
    'Position', [figX figY figW figH], ...
    'Color', [0.945 0.953 0.965], ...
    'CloseRequestFcn', @onCancel);

root = uigridlayout(fig, [1 2]);
root.ColumnWidth = {760, '1x'};
root.RowHeight = {'1x'};
root.Padding = [16 16 16 16];
root.ColumnSpacing = 16;
root.BackgroundColor = fig.Color;

left = uipanel(root, 'Title', '参数设置', ...
    'FontWeight', 'bold', 'FontSize', 13, ...
    'BackgroundColor', [0.980 0.984 0.990]);
left.Layout.Row = 1;
left.Layout.Column = 1;

leftGrid = uigridlayout(left, [3 1]);
leftGrid.RowHeight = {'1x', 92, 58};
leftGrid.Padding = [14 12 14 14];
leftGrid.RowSpacing = 10;
leftGrid.BackgroundColor = left.BackgroundColor;

tabGroup = uitabgroup(leftGrid);
tabGroup.Layout.Row = 1;
designTab = uitab(tabGroup, 'Title', '设计参数');
runtimeTab = uitab(tabGroup, 'Title', '运行与路径');

designGrid = uigridlayout(designTab, [1 2]);
designGrid.ColumnWidth = {'1x', '1x'};
designGrid.RowHeight = {'1x'};
designGrid.Padding = [10 10 10 10];
designGrid.ColumnSpacing = 14;
designGrid.BackgroundColor = [0.980 0.984 0.990];

designLeftGrid = uigridlayout(designGrid, [2 1]);
designLeftGrid.RowHeight = {176, '1x'};
designLeftGrid.Padding = [0 0 0 0];
designLeftGrid.RowSpacing = 10;
designLeftGrid.BackgroundColor = designGrid.BackgroundColor;
designLeftGrid.Layout.Row = 1;
designLeftGrid.Layout.Column = 1;

designRightGrid = uigridlayout(designGrid, [1 1]);
designRightGrid.RowHeight = {'1x'};
designRightGrid.Padding = [0 0 0 0];
designRightGrid.BackgroundColor = designGrid.BackgroundColor;
designRightGrid.Layout.Row = 1;
designRightGrid.Layout.Column = 2;

runtimeGrid = uigridlayout(runtimeTab, [1 1]);
runtimeGrid.RowHeight = {'1x'};
runtimeGrid.Padding = [10 10 10 10];
runtimeGrid.BackgroundColor = [0.980 0.984 0.990];

freqPanel = local_panel(designLeftGrid, '频率设置');
freqGrid = local_form_grid(freqPanel, 3);
f1Edit = local_numeric_field(freqGrid, '扫频起点 f1 (GHz)', baseSpec.hfss.sweep_f1_GHz);
f2Edit = local_numeric_field(freqGrid, '扫频终点 f2 (GHz)', baseSpec.hfss.sweep_f2_GHz);
f0Edit = local_numeric_field(freqGrid, '设计/求解频率 f0 (GHz)', baseSpec.f0_Hz/1e9);

arrayPanel = local_panel(designLeftGrid, '阵列与幅度分布');
arrayGrid = local_form_grid(arrayPanel, 5);
nxSpin = local_spinner(arrayGrid, 'Nx 辐射波导数（偶数）', baseSpec.array.Nx, 2, 200, 2);
nySpin = local_spinner(arrayGrid, 'Ny 每根波导缝隙数（偶数）', baseSpec.array.Ny, 2, 200, 2);
sllEdit = local_numeric_field(arrayGrid, '目标副瓣 |SLL| (dB)', abs(baseSpec.sll_dB));
taperDrop = local_dropdown(arrayGrid, '幅度分布', {'taylor', 'chebyshev', 'uniform'}, baseSpec.synth_x.type);
nbarSpin = local_spinner(arrayGrid, 'Taylor nbar', baseSpec.synth_x.nbar, 1, 20, 1);

wgPanel = local_panel(designRightGrid, '耦合/馈电波导');
wgGrid = uigridlayout(wgPanel, [8 2]);
wgGrid.ColumnWidth = {116, '1x'};
wgGrid.RowHeight = {30, 30, 30, 30, 30, 30, 54, '1x'};
wgGrid.Padding = [14 12 14 12];
wgGrid.RowSpacing = 6;
wgGrid.BackgroundColor = wgPanel.BackgroundColor;
wgModeDrop = local_dropdown(wgGrid, '选择方式', {'自动推荐', '标准波导', '自定义'}, '自动推荐');
stdDrop = local_dropdown(wgGrid, '标准波导', {db.name}, defaultGuide.name);
customNameEdit = local_text_field(wgGrid, '自定义名称', 'CUSTOM');
customAEdit = local_numeric_field(wgGrid, '自定义 a (mm)', baseSpec.waveguide.a_mm);
customBEdit = local_numeric_field(wgGrid, '自定义 b (mm)', baseSpec.waveguide.b_mm);
wallEdit = local_numeric_field(wgGrid, '壁厚 t (mm)', baseSpec.geometry.wall_mm);
recLabel = uilabel(wgGrid, 'Text', '', 'WordWrap', 'on', ...
    'FontSize', 11, 'FontColor', [0.16 0.22 0.30]);
recLabel.Layout.Row = [7 8];
recLabel.Layout.Column = [1 2];

envPanel = local_panel(runtimeGrid, '运行环境与输出');
envGrid = uigridlayout(envPanel, [7 4]);
envGrid.ColumnWidth = {96, '1x', 62, 78};
envGrid.RowHeight = {32, 32, 32, 32, 32, 32, 32};
envGrid.Padding = [14 12 14 12];
envGrid.RowSpacing = 8;
envGrid.ColumnSpacing = 8;
envGrid.BackgroundColor = envPanel.BackgroundColor;

local_field_label(envGrid, '仿真后端', 1);
solverDrop = uidropdown(envGrid, 'Items', {'HFSS', 'CST'}, ...
    'Value', upper(baseSpec.solver), 'FontName', 'Segoe UI', 'FontSize', 11);
solverDrop.Layout.Row = 1;
solverDrop.Layout.Column = [2 4];

local_field_label(envGrid, 'HFSS 路径', 2);
hfssPathEdit = uieditfield(envGrid, 'text', 'Value', defaultHfssPath, ...
    'FontName', 'Segoe UI', 'FontSize', 11);
hfssPathEdit.Layout.Row = 2;
hfssPathEdit.Layout.Column = 2;
hfssAutoButton = uibutton(envGrid, 'push', 'Text', '自动', 'ButtonPushedFcn', @autoFillHfssPath);
hfssAutoButton.Layout.Row = 2;
hfssAutoButton.Layout.Column = 3;
hfssBrowseButton = uibutton(envGrid, 'push', 'Text', '浏览...', 'ButtonPushedFcn', @browseHfssPath);
hfssBrowseButton.Layout.Row = 2;
hfssBrowseButton.Layout.Column = 4;

local_field_label(envGrid, 'CST 路径', 3);
cstPathEdit = uieditfield(envGrid, 'text', 'Value', defaultCstPath, ...
    'FontName', 'Segoe UI', 'FontSize', 11);
cstPathEdit.Layout.Row = 3;
cstPathEdit.Layout.Column = 2;
cstAutoButton = uibutton(envGrid, 'push', 'Text', '自动', 'ButtonPushedFcn', @autoFillCstPath);
cstAutoButton.Layout.Row = 3;
cstAutoButton.Layout.Column = 3;
cstBrowseButton = uibutton(envGrid, 'push', 'Text', '浏览...', 'ButtonPushedFcn', @browseCstPath);
cstBrowseButton.Layout.Row = 3;
cstBrowseButton.Layout.Column = 4;

local_field_label(envGrid, 'Python 路径', 4);
pythonPathEdit = uieditfield(envGrid, 'text', 'Value', defaultPythonPath, ...
    'FontName', 'Segoe UI', 'FontSize', 11);
pythonPathEdit.Layout.Row = 4;
pythonPathEdit.Layout.Column = 2;
pythonAutoButton = uibutton(envGrid, 'push', 'Text', '自动', 'ButtonPushedFcn', @autoFillPythonPath);
pythonAutoButton.Layout.Row = 4;
pythonAutoButton.Layout.Column = 3;
pythonBrowseButton = uibutton(envGrid, 'push', 'Text', '浏览...', 'ButtonPushedFcn', @browsePythonPath);
pythonBrowseButton.Layout.Row = 4;
pythonBrowseButton.Layout.Column = 4;

local_field_label(envGrid, '输出目录', 5);
outputDirEdit = uieditfield(envGrid, 'text', 'Value', baseSpec.output_dir, ...
    'FontName', 'Segoe UI', 'FontSize', 11);
outputDirEdit.Layout.Row = 5;
outputDirEdit.Layout.Column = [2 3];
outputBrowseButton = uibutton(envGrid, 'push', 'Text', '浏览...', 'ButtonPushedFcn', @browseOutputDir);
outputBrowseButton.Layout.Row = 5;
outputBrowseButton.Layout.Column = 4;

executeCheck = uicheckbox(envGrid, 'Text', '生成后执行 HFSS', ...
    'Value', logical(baseSpec.hfss.execute_hfss));
executeCheck.Layout.Row = 6;
executeCheck.Layout.Column = [1 2];
cstExecuteCheck = uicheckbox(envGrid, 'Text', '生成后执行 CST', ...
    'Value', logical(baseSpec.cst.execute_cst));
cstExecuteCheck.Layout.Row = 6;
cstExecuteCheck.Layout.Column = [3 4];

visibleCheck = uicheckbox(envGrid, 'Text', '显示 HFSS 窗口', ...
    'Value', logical(baseSpec.hfss.visible));
visibleCheck.Layout.Row = 7;
visibleCheck.Layout.Column = [1 2];
cstVisibleCheck = uicheckbox(envGrid, 'Text', '显示 CST 窗口', ...
    'Value', logical(baseSpec.cst.visible));
cstVisibleCheck.Layout.Row = 7;
cstVisibleCheck.Layout.Column = [3 4];

statusLabel = uilabel(leftGrid, 'Text', '', 'WordWrap', 'on', ...
    'FontSize', 11, 'FontColor', [0.55 0.10 0.10], ...
    'BackgroundColor', [0.952 0.970 0.952]);
statusLabel.Layout.Row = 2;

buttonGrid = uigridlayout(leftGrid, [1 3]);
buttonGrid.ColumnWidth = {'1x', 156, 96};
buttonGrid.RowHeight = {40};
buttonGrid.Padding = [0 0 0 0];
buttonGrid.BackgroundColor = left.BackgroundColor;
buttonGrid.Layout.Row = 3;
buildButton = uibutton(buttonGrid, 'push', 'Text', '生成模型文件', ...
    'FontWeight', 'bold', 'BackgroundColor', [0.13 0.33 0.58], ...
    'FontColor', [1 1 1], 'ButtonPushedFcn', @onGenerate);
buildButton.Layout.Row = 1;
buildButton.Layout.Column = 2;
cancelButton = uibutton(buttonGrid, 'push', 'Text', '取消', ...
    'ButtonPushedFcn', @onCancel);
cancelButton.Layout.Row = 1;
cancelButton.Layout.Column = 3;

right = uipanel(root, 'Title', '结构预览与派生参数', ...
    'FontWeight', 'bold', 'FontSize', 13, ...
    'BackgroundColor', [0.980 0.984 0.990]);
right.Layout.Row = 1;
right.Layout.Column = 2;

rightGrid = uigridlayout(right, [4 1]);
rightGrid.RowHeight = {34, '1x', 184, 92};
rightGrid.Padding = [12 10 12 12];
rightGrid.RowSpacing = 10;
rightGrid.BackgroundColor = right.BackgroundColor;

previewTitle = uilabel(rightGrid, ...
    'Text', '纵向缝隙波导阵列预览：结构、幅度分布和关键尺寸对应关系', ...
    'FontWeight', 'bold', 'FontSize', 14, 'FontColor', [0.12 0.17 0.24]);
previewTitle.Layout.Row = 1;

previewAxes = uiaxes(rightGrid);
previewAxes.Layout.Row = 2;
previewAxes.Toolbar.Visible = 'off';
previewAxes.Interactions = [];

derivedTable = uitable(rightGrid);
derivedTable.Layout.Row = 3;
derivedTable.ColumnName = {'参数', '数值', '说明'};
derivedTable.ColumnWidth = {170, 220, 'auto'};
derivedTable.RowName = {};
derivedTable.FontSize = 11;

notesBox = uitextarea(rightGrid, 'Editable', 'off', 'FontSize', 11);
notesBox.Layout.Row = 4;

allControls = {f1Edit, f2Edit, f0Edit, nxSpin, nySpin, sllEdit, taperDrop, nbarSpin, ...
    wgModeDrop, stdDrop, customNameEdit, customAEdit, customBEdit, wallEdit, ...
    solverDrop, hfssPathEdit, cstPathEdit, pythonPathEdit, outputDirEdit, ...
    executeCheck, visibleCheck, cstExecuteCheck, cstVisibleCheck};
for ctrlIdx = 1:numel(allControls)
    allControls{ctrlIdx}.ValueChangedFcn = @(~, ~) updatePreview();
end
solverDrop.ValueChangedFcn = @(~, ~) onSolverChanged();
wgModeDrop.ValueChangedFcn = @(~, ~) onWaveguideModeChanged();

fig.UserData = struct('cancelled', true, 'spec', []);
onSolverChanged();
onWaveguideModeChanged();
updatePreview();
uiwait(fig);

    function onSolverChanged(~, ~)
        buildButton.Text = sprintf('生成 %s 模型', upper(strtrim(char(solverDrop.Value))));
        updatePreview();
    end

    function onWaveguideModeChanged(~, ~)
        mode = wgModeDrop.Value;
        useStd = strcmp(mode, '标准波导');
        useCustom = strcmp(mode, '自定义');
        stdDrop.Enable = local_onoff(useStd);
        customNameEdit.Enable = local_onoff(useCustom);
        customAEdit.Enable = local_onoff(useCustom);
        customBEdit.Enable = local_onoff(useCustom);
        updatePreview();
    end

    function onGenerate(~, ~)
        [candidate, ok, message] = readSpecFromControls(true);
        if ~ok
            uialert(fig, message, '参数设置无效');
            return;
        end
        fig.UserData = struct('cancelled', false, 'spec', candidate);
        buildButton.Enable = 'off';
        cancelButton.Enable = 'off';
        statusLabel.Text = sprintf('正在生成 %s 模型，请等待...', upper(candidate.solver));
        statusLabel.FontColor = [0.10 0.23 0.45];
        drawnow;
        cleanupControls = onCleanup(@() local_set_generate_controls_enabled(buildButton, cancelButton));
        [~, success] = local_generate_model(candidate, repoRoot);
        if isvalid(fig)
            if success
                statusLabel.Text = sprintf('完成：%s 模型文件已生成。界面保持打开，可继续修改参数。', upper(candidate.solver));
                statusLabel.FontColor = [0.12 0.36 0.18];
            else
                statusLabel.Text = '生成失败：请查看弹窗或 output\last_run_error.txt。';
                statusLabel.FontColor = [0.65 0.12 0.10];
            end
            updatePreview();
        end
        clear cleanupControls;
    end

    function onCancel(~, ~)
        fig.UserData = struct('cancelled', true, 'spec', []);
        if isvalid(fig)
            delete(fig);
        end
    end

    function autoFillHfssPath(~, ~)
        searchSpec = baseSpec;
        searchSpec.hfss.executable = '';
        foundPath = local_find_hfss_executable(searchSpec);
        if isempty(foundPath)
            uialert(fig, '未自动找到 ansysedt.exe，请用“浏览...”手动选择 HFSS 可执行文件。', '未找到 HFSS');
            return;
        end
        hfssPathEdit.Value = foundPath;
        updatePreview();
    end

    function autoFillCstPath(~, ~)
        searchSpec = baseSpec;
        searchSpec.cst.executable = '';
        foundPath = local_find_cst_executable(searchSpec);
        if isempty(foundPath)
            uialert(fig, '未自动找到 CST DESIGN ENVIRONMENT_AMD64.exe，请用“浏览...”手动选择 CST 可执行文件。', '未找到 CST');
            return;
        end
        cstPathEdit.Value = foundPath;
        updatePreview();
    end

    function autoFillPythonPath(~, ~)
        searchSpec = baseSpec;
        searchSpec.environment.python_executable = '';
        foundPath = local_find_python_executable(searchSpec);
        if isempty(foundPath)
            uialert(fig, '未自动找到 python.exe；如果后续不需要 Python 后处理，可以保持为空。', '未找到 Python');
            return;
        end
        pythonPathEdit.Value = foundPath;
        updatePreview();
    end

    function browseHfssPath(~, ~)
        startDir = local_existing_parent(hfssPathEdit.Value);
        [fileName, folderName] = uigetfile( ...
            {'ansysedt.exe', 'HFSS ansysedt.exe'; '*.exe', 'Executable (*.exe)'}, ...
            '选择 HFSS 可执行文件 ansysedt.exe', startDir);
        if isequal(fileName, 0)
            return;
        end
        hfssPathEdit.Value = fullfile(folderName, fileName);
        updatePreview();
    end

    function browseCstPath(~, ~)
        startDir = local_existing_parent(cstPathEdit.Value);
        [fileName, folderName] = uigetfile( ...
            {'*.exe', 'Executable (*.exe)'}, ...
            '选择 CST 可执行文件', startDir);
        if isequal(fileName, 0)
            return;
        end
        cstPathEdit.Value = fullfile(folderName, fileName);
        updatePreview();
    end

    function browsePythonPath(~, ~)
        startDir = local_existing_parent(pythonPathEdit.Value);
        [fileName, folderName] = uigetfile( ...
            {'python.exe', 'Python python.exe'; '*.exe', 'Executable (*.exe)'}, ...
            '选择 Python 可执行文件 python.exe', startDir);
        if isequal(fileName, 0)
            return;
        end
        pythonPathEdit.Value = fullfile(folderName, fileName);
        updatePreview();
    end

    function browseOutputDir(~, ~)
        folderName = uigetdir(local_existing_parent(outputDirEdit.Value), '选择输出目录');
        if isequal(folderName, 0)
            return;
        end
        outputDirEdit.Value = folderName;
        updatePreview();
    end

    function updatePreview()
        if ~isvalid(fig)
            return;
        end
        [previewSpec, ok, message] = readSpecFromControls(false);
        if ~ok
            statusLabel.Text = message;
            statusLabel.FontColor = [0.65 0.12 0.10];
            cla(previewAxes);
            axis(previewAxes, 'off');
            text(previewAxes, 0.5, 0.5, '参数无效，请修正左侧输入', ...
                'Units', 'normalized', 'HorizontalAlignment', 'center', ...
                'FontWeight', 'bold', 'Color', [0.65 0.12 0.10]);
            derivedTable.Data = {};
            notesBox.Value = {message};
            return;
        end

        try
            arrayData = synthesis.spec_to_array(previewSpec);
            weights = synthesis.synthesize_weights(arrayData, previewSpec);
        catch ME
            statusLabel.Text = ME.message;
            statusLabel.FontColor = [0.65 0.12 0.10];
            cla(previewAxes);
            axis(previewAxes, 'off');
            derivedTable.Data = {};
            notesBox.Value = {ME.message};
            return;
        end

        statusLabel.Text = sprintf('就绪：当前预览与 %s 建模共用同一套间距和幅度分布规则。', ...
            upper(previewSpec.solver));
        statusLabel.FontColor = [0.12 0.36 0.18];
        local_draw_preview(previewAxes, previewSpec, arrayData, weights);
        updateDerivedTable(previewSpec, arrayData);
        updateNotes(previewSpec, arrayData);
    end

    function [candidate, ok, message] = readSpecFromControls(strict)
        ok = false;
        message = '';
        candidate = baseSpec;
        try
            f1GHz = local_require_positive_number(f1Edit.Value, '扫频起点');
            f2GHz = local_require_positive_number(f2Edit.Value, '扫频终点');
            f0GHz = local_require_positive_number(f0Edit.Value, '设计频率');
            if f2GHz <= f1GHz
                error('扫频终点必须大于扫频起点。');
            end
            if f0GHz < f1GHz || f0GHz > f2GHz
                error('设计频率 f0 必须位于扫频范围内。');
            end

            Nx = local_require_even_count(nxSpin.Value, 'Nx');
            Ny = local_require_even_count(nySpin.Value, 'Ny');
            sllMag = local_require_positive_number(sllEdit.Value, '目标副瓣电平');
            nbar = local_require_positive_integer(nbarSpin.Value, 'Taylor nbar');
            taperType = local_normalize_taper(taperDrop.Value);
            wall = local_require_positive_number(wallEdit.Value, '壁厚');
            solverName = upper(strtrim(char(solverDrop.Value)));

            candidate = local_apply_basic_inputs(candidate, f1GHz, f2GHz, f0GHz, Nx, Ny, ...
                sllMag, taperType, nbar, wall, ...
                logical(executeCheck.Value), logical(visibleCheck.Value), ...
                logical(cstExecuteCheck.Value), logical(cstVisibleCheck.Value), ...
                solverName);
            candidate = local_apply_waveguide_choice(candidate, wgModeDrop, stdDrop, ...
                customNameEdit, customAEdit, customBEdit, recLabel, db);
            candidate.output_dir = local_default_output_dir(outputDirEdit.Value, repoRoot);
            candidate.hfss.executable = strtrim(char(hfssPathEdit.Value));
            candidate.cst.executable = strtrim(char(cstPathEdit.Value));
            candidate.environment.python_executable = strtrim(char(pythonPathEdit.Value));

            if strict
                if strcmpi(candidate.solver, 'HFSS') && candidate.hfss.execute_hfss
                    local_require_existing_file(candidate.hfss.executable, 'HFSS 路径');
                end
                if strcmpi(candidate.solver, 'CST') && candidate.cst.execute_cst
                    local_require_existing_file(candidate.cst.executable, 'CST 路径');
                end
                if ~isempty(candidate.environment.python_executable)
                    local_require_existing_file(candidate.environment.python_executable, 'Python 路径');
                end
            end

            candidate = local_finalize_project_name(candidate);
            local_validate_waveguide(candidate);
            ok = true;
        catch ME
            message = regexprep(ME.message, '\s+', ' ');
        end
    end

    function updateDerivedTable(previewSpec, arrayData)
        derivedTable.Data = {
            '仿真后端', upper(previewSpec.solver), '当前统一界面输出到 HFSS 或 CST';
            '输出目录', previewSpec.output_dir, '模型脚本、工程文件和快照输出位置';
            '耦合波导', sprintf('%s, a=%.3f, b=%.3f mm', ...
                arrayData.coupling_waveguide.name, ...
                arrayData.coupling_waveguide.a_mm, arrayData.coupling_waveguide.b_mm), ...
                '用户选择或自动推荐的矩形波导';
            'lambda_g,cpl / 2', sprintf('%.3f mm', 0.5*arrayData.coupling_calc.lambda_g_mm), ...
                '耦合缝隙间距，同时也是辐射波导行间距';
            'a_rad', sprintf('%.3f mm', arrayData.radiating_waveguide.a_mm), ...
                '按 a_rad = lambda_g,cpl/2 - t 推导';
            'lambda_g,rad / 2', sprintf('%.3f mm', 0.5*arrayData.radiating_calc.lambda_g_mm), ...
                '辐射缝隙间距';
            '口径估计 X x Y', sprintf('%.1f x %.1f mm', ...
                arrayData.aperture_x_mm, arrayData.aperture_y_mm), ...
                '用于增益估计的几何口径';
            '估计增益', sprintf('%.2f dBi', arrayData.estimated_gain_dBi), ...
                '仅为口径效率估计，不是全波结果';
            '当前工程名', local_get_solver_project_name(previewSpec), ...
                '按当前后端自动生成的输出前缀';
            };
    end

    function updateNotes(previewSpec, arrayData)
        notesBox.Value = {
            sprintf('1. 设计逻辑：先选耦合/馈电波导，再按 a_rad = lambda_g,cpl/2 - t 推导辐射波导。');
            sprintf('2. 间距规则：耦合缝隙间距 = lambda_g,cpl/2；辐射缝隙间距 = lambda_g,rad/2。');
            sprintf('3. 当前行间距 = %.3f mm，辐射缝隙间距 = %.3f mm，壁厚 t = %.3f mm。', ...
                arrayData.row_outer_pitch_mm, arrayData.dy_mm, previewSpec.geometry.wall_mm);
            sprintf('4. 默认采用 E-T 馈电，并使用同一套幅度分布规则映射到阵列预览与建模后端。');
            };
    end
end

function panel = local_panel(parent, titleText)
panel = uipanel(parent, 'Title', titleText, 'FontWeight', 'bold', ...
    'FontSize', 12, 'BackgroundColor', [0.965 0.973 0.984], ...
    'ForegroundColor', [0.14 0.18 0.25]);
end

function grid = local_form_grid(parent, rows)
grid = uigridlayout(parent, [rows 2]);
grid.ColumnWidth = {132, '1x'};
grid.RowHeight = repmat({30}, 1, rows);
grid.Padding = [12 10 12 10];
grid.RowSpacing = 6;
grid.BackgroundColor = parent.BackgroundColor;
end

function ctrl = local_numeric_field(parent, labelText, value)
row = local_next_row(parent);
local_field_label(parent, labelText, row);
ctrl = uieditfield(parent, 'numeric', 'Value', value, ...
    'FontName', 'Segoe UI', 'FontSize', 11);
ctrl.Layout.Row = row;
ctrl.Layout.Column = 2;
end

function ctrl = local_text_field(parent, labelText, value)
row = local_next_row(parent);
local_field_label(parent, labelText, row);
ctrl = uieditfield(parent, 'text', 'Value', value, ...
    'FontName', 'Segoe UI', 'FontSize', 11);
ctrl.Layout.Row = row;
ctrl.Layout.Column = 2;
end

function ctrl = local_spinner(parent, labelText, value, minValue, maxValue, stepValue)
row = local_next_row(parent);
local_field_label(parent, labelText, row);
ctrl = uispinner(parent, 'Value', value, 'Limits', [minValue maxValue], 'Step', stepValue, ...
    'FontName', 'Segoe UI', 'FontSize', 11);
ctrl.Layout.Row = row;
ctrl.Layout.Column = 2;
end

function ctrl = local_dropdown(parent, labelText, items, value)
row = local_next_row(parent);
local_field_label(parent, labelText, row);
ctrl = uidropdown(parent, 'Items', items, 'Value', value, ...
    'FontName', 'Segoe UI', 'FontSize', 11);
ctrl.Layout.Row = row;
ctrl.Layout.Column = 2;
end

function local_field_label(parent, labelText, row)
lbl = uilabel(parent, 'Text', labelText, 'HorizontalAlignment', 'left', ...
    'FontSize', 11, 'FontColor', [0.18 0.22 0.28]);
lbl.Layout.Row = row;
lbl.Layout.Column = 1;
end

function row = local_next_row(parent)
children = parent.Children;
rows = zeros(numel(children), 1);
for k = 1:numel(children)
    if isprop(children(k), 'Layout') && ~isempty(children(k).Layout)
        rows(k) = children(k).Layout.Row;
    end
end
row = max([0; rows]) + 1;
end

function state = local_onoff(tf)
if tf
    state = 'on';
else
    state = 'off';
end
end

function spec = local_get_spec_from_console(spec, repoRoot)
fprintf('图形界面不可用，切换到命令行输入。\n');
f1GHz = input(sprintf('扫频起点 GHz [%.3f]: ', spec.hfss.sweep_f1_GHz));
f2GHz = input(sprintf('扫频终点 GHz [%.3f]: ', spec.hfss.sweep_f2_GHz));
f0GHz = input(sprintf('设计频率 f0 GHz [%.3f]: ', spec.f0_Hz/1e9));
Nx = input(sprintf('Nx 偶数 [%d]: ', spec.array.Nx));
Ny = input(sprintf('Ny 偶数 [%d]: ', spec.array.Ny));
sllMag = input(sprintf('目标副瓣 |SLL| dB [%.1f]: ', abs(spec.sll_dB)));
taperType = input(sprintf('幅度分布 [%s]: ', spec.synth_x.type), 's');
wall = input(sprintf('壁厚 mm [%.3f]: ', spec.geometry.wall_mm));
solverName = input(sprintf('仿真后端 HFSS/CST [%s]: ', upper(spec.solver)), 's');
executeHfss = input(sprintf('执行 HFSS? 1/0 [%d]: ', spec.hfss.execute_hfss));
visibleHfss = input(sprintf('显示 HFSS 窗口? 1/0 [%d]: ', spec.hfss.visible));
executeCst = input(sprintf('执行 CST? 1/0 [%d]: ', spec.cst.execute_cst));
visibleCst = input(sprintf('显示 CST 窗口? 1/0 [%d]: ', spec.cst.visible));
outputDir = input(sprintf('输出目录 [%s]: ', spec.output_dir), 's');

if isempty(f1GHz); f1GHz = spec.hfss.sweep_f1_GHz; end
if isempty(f2GHz); f2GHz = spec.hfss.sweep_f2_GHz; end
if isempty(f0GHz); f0GHz = spec.f0_Hz/1e9; end
if isempty(Nx); Nx = spec.array.Nx; end
if isempty(Ny); Ny = spec.array.Ny; end
if isempty(sllMag); sllMag = abs(spec.sll_dB); end
if isempty(taperType); taperType = spec.synth_x.type; end
if isempty(wall); wall = spec.geometry.wall_mm; end
if isempty(solverName); solverName = spec.solver; end
if isempty(executeHfss); executeHfss = spec.hfss.execute_hfss; end
if isempty(visibleHfss); visibleHfss = spec.hfss.visible; end
if isempty(executeCst); executeCst = spec.cst.execute_cst; end
if isempty(visibleCst); visibleCst = spec.cst.visible; end
if isempty(outputDir); outputDir = fullfile(repoRoot, 'output'); end

spec = local_apply_basic_inputs(spec, f1GHz, f2GHz, f0GHz, Nx, Ny, ...
    sllMag, local_normalize_taper(taperType), spec.synth_x.nbar, wall, ...
    logical(executeHfss), logical(visibleHfss), ...
    logical(executeCst), logical(visibleCst), solverName);
spec.output_dir = outputDir;
spec = local_finalize_project_name(spec);
end

function spec = local_apply_basic_inputs(spec, f1GHz, f2GHz, f0GHz, Nx, Ny, ...
    sllMag, taperType, nbar, wall, executeHfss, visibleHfss, ...
    executeCst, visibleCst, solverName)
spec.f0_Hz = f0GHz * 1e9;
spec.sll_dB = -abs(sllMag);
spec.array.mode = 'fixed';
spec.array.Nx = Nx;
spec.array.Ny = Ny;

spec.synth_x.type = taperType;
spec.synth_y.type = taperType;
spec.synth_x.nbar = nbar;
spec.synth_y.nbar = nbar;
spec.synth_x.sll_dB = abs(spec.sll_dB);
spec.synth_y.sll_dB = abs(spec.sll_dB);

spec.geometry.wall_mm = wall;
spec.geometry.outer_shell_margin_mm = wall;
spec.waveguide.t_mm = wall;
spec.radiating_waveguide.t_mm = wall;
spec.solver = upper(strtrim(char(solverName)));

spec.hfss.sweep_f1_GHz = f1GHz;
spec.hfss.sweep_f2_GHz = f2GHz;
spec.hfss.solution_f_GHz = f0GHz;
spec.hfss.execute_hfss = logical(executeHfss);
spec.hfss.visible = logical(visibleHfss);

spec.cst.execute_cst = logical(executeCst);
spec.cst.visible = logical(visibleCst);
end

function spec = local_apply_waveguide_choice(spec, wgModeDrop, stdDrop, customNameEdit, customAEdit, customBEdit, recLabel, db)
mode = wgModeDrop.Value;
switch mode
    case '自动推荐'
        wg = local_recommend_waveguide_for_band(spec, db);
        spec.waveguide.mode = 'standard';
        spec.waveguide.name = wg.name;
        spec.waveguide.a_mm = wg.a_mm;
        spec.waveguide.b_mm = wg.b_mm;
        recLabel.Text = sprintf('%s\n当前采用自动推荐波导：%s', wg.selection_note, wg.name);
    case '标准波导'
        idx = find(strcmpi({db.name}, stdDrop.Value), 1, 'first');
        if isempty(idx)
            error('未知标准波导：%s', stdDrop.Value);
        end
        wg = db(idx);
        spec.waveguide.mode = 'standard';
        spec.waveguide.name = wg.name;
        spec.waveguide.a_mm = wg.a_mm;
        spec.waveguide.b_mm = wg.b_mm;
        recLabel.Text = sprintf('当前采用标准波导：%s, a=%.3f mm, b=%.3f mm', wg.name, wg.a_mm, wg.b_mm);
    case '自定义'
        spec.waveguide.mode = 'custom';
        spec.waveguide.name = strtrim(char(customNameEdit.Value));
        if isempty(spec.waveguide.name)
            spec.waveguide.name = 'CUSTOM';
        end
        spec.waveguide.a_mm = local_require_positive_number(customAEdit.Value, '自定义 a');
        spec.waveguide.b_mm = local_require_positive_number(customBEdit.Value, '自定义 b');
        recLabel.Text = sprintf('当前采用自定义波导：a=%.3f mm, b=%.3f mm', ...
            spec.waveguide.a_mm, spec.waveguide.b_mm);
    otherwise
        error('未知波导选择方式：%s', mode);
end
spec.waveguide.t_mm = spec.geometry.wall_mm;
end

function spec = local_finalize_project_name(spec)
wgName = regexprep(lower(spec.waveguide.name), '[^a-z0-9]+', '');
if isempty(wgName)
    wgName = 'custom';
end
taperName = regexprep(lower(spec.synth_x.type), '[^a-z0-9]+', '');
freqTag = sprintf('%gg', spec.f0_Hz/1e9);
freqTag = strrep(freqTag, '.', 'p');
baseName = sprintf('waveguide_panel_v0_8_1_%s_%s_%dx%d_sll%d', ...
    wgName, freqTag, spec.array.Nx, spec.array.Ny, round(abs(spec.sll_dB)));
if ~strcmpi(taperName, 'taylor')
    baseName = [baseName '_' taperName];
end
spec.hfss.project_basename = ['hfss_' baseName];
spec.cst.project_basename = ['cst_' baseName];
end

function wg = local_recommend_waveguide_for_band(spec, db)
f0GHz = spec.f0_Hz / 1e9;
f1GHz = spec.hfss.sweep_f1_GHz;
f2GHz = spec.hfss.sweep_f2_GHz;
bandCenter = 0.5 * (f1GHz + f2GHz);
coversBand = arrayfun(@(x) f1GHz >= x.f_low_GHz && f2GHz <= x.f_high_GHz, db);
if any(coversBand)
    idxCandidates = find(coversBand);
    centers = arrayfun(@(x) 0.5*(x.f_low_GHz + x.f_high_GHz), db(idxCandidates));
    spans = arrayfun(@(x) x.f_high_GHz - x.f_low_GHz, db(idxCandidates));
    score = abs(centers - bandCenter) ./ max(spans, eps);
    [~, localIdx] = min(score);
    wg = db(idxCandidates(localIdx));
    wg.selection_note = sprintf('%s 覆盖当前 %.3f-%.3f GHz 扫频范围。', wg.name, f1GHz, f2GHz);
else
    autoSpec = spec.waveguide;
    autoSpec.mode = 'auto';
    wg = utils.recommend_waveguide(autoSpec, spec.f0_Hz);
    wg.selection_note = sprintf('标准库中没有完整覆盖 %.3f-%.3f GHz 的波导，回退到最接近 f0=%.3f GHz 的型号。', ...
        f1GHz, f2GHz, f0GHz);
end
wg.t_mm = spec.geometry.wall_mm;
end

function local_validate_waveguide(spec)
calc = local_waveguide_cutoffs(spec.waveguide.a_mm);
f1GHz = spec.hfss.sweep_f1_GHz;
f2GHz = spec.hfss.sweep_f2_GHz;
if f1GHz <= calc.fc10_GHz
    error('扫频起点 %.3f GHz 低于或过近 TE10 截止频率 %.3f GHz。', f1GHz, calc.fc10_GHz);
end
if f2GHz >= calc.fc20_GHz
    error('扫频终点 %.3f GHz 已达到 TE20 截止频率 %.3f GHz，请更换更小波导或降低频段。', ...
        f2GHz, calc.fc20_GHz);
end
end

function calc = local_waveguide_cutoffs(a_mm)
C = utils.constants();
a = a_mm * 1e-3;
calc.fc10_GHz = C.c0 / (2*a) / 1e9;
calc.fc20_GHz = C.c0 / a / 1e9;
end

function value = local_require_positive_number(value, name)
if ~isfinite(value) || value <= 0
    error('%s 必须是正数。', name);
end
end

function value = local_require_positive_integer(value, name)
value = round(local_require_positive_number(value, name));
end

function value = local_require_even_count(value, name)
value = local_require_positive_integer(value, name);
if mod(value, 2) ~= 0
    error('%s 必须为偶数。', name);
end
end

function taperType = local_normalize_taper(taperText)
taperType = lower(strtrim(char(taperText)));
switch taperType
    case {'cheb', 'dolph', 'dolph-chebyshev'}
        taperType = 'chebyshev';
    case {'tay'}
        taperType = 'taylor';
end
valid = {'taylor', 'chebyshev', 'uniform'};
if ~any(strcmp(taperType, valid))
    error('幅度分布只能选择 taylor、chebyshev 或 uniform。');
end
end

function local_require_existing_file(pathValue, labelText)
pathValue = strtrim(char(pathValue));
if isempty(pathValue)
    error('%s 不能为空。', labelText);
end
if ~exist(pathValue, 'file')
    error('%s 不存在：%s', labelText, pathValue);
end
end

function outputDir = local_default_output_dir(value, repoRoot)
outputDir = strtrim(char(value));
if isempty(outputDir)
    outputDir = fullfile(repoRoot, 'output');
end
end

function pathValue = local_find_hfss_executable(spec)
if isfield(spec, 'hfss') && isfield(spec.hfss, 'executable')
    candidate = strtrim(char(spec.hfss.executable));
    if ~isempty(candidate) && exist(candidate, 'file')
        pathValue = candidate;
        return;
    end
end
pathValue = local_where_executable('ansysedt.exe');
if ~isempty(pathValue)
    return;
end
roots = {getenv('ProgramFiles'), getenv('ProgramW6432'), getenv('ProgramFiles(x86)'), ...
    'C:\Program Files', 'D:\software', 'D:\Program Files'};
candidates = {};
for idx = 1:numel(roots)
    root = strtrim(char(roots{idx}));
    if isempty(root)
        continue;
    end
    candidates = [candidates, local_glob_files(fullfile(root, 'AnsysEM', '*', 'Win64', 'ansysedt.exe'))]; %#ok<AGROW>
    candidates = [candidates, local_glob_files(fullfile(root, 'AnsysEM*', 'Win64', 'ansysedt.exe'))]; %#ok<AGROW>
    candidates = [candidates, local_glob_files(fullfile(root, 'HFSS', 'AnsysEM*', 'Win64', 'ansysedt.exe'))]; %#ok<AGROW>
    candidates = [candidates, local_glob_files(fullfile(root, 'HFSS', '*', 'Win64', 'ansysedt.exe'))]; %#ok<AGROW>
    candidates = [candidates, local_glob_files(fullfile(root, 'ANSYS Inc', '*', 'AnsysEM', 'Win64', 'ansysedt.exe'))]; %#ok<AGROW>
    candidates = [candidates, local_glob_files(fullfile(root, 'ANSYS Inc', '*', 'AnsysEM', '*', 'Win64', 'ansysedt.exe'))]; %#ok<AGROW>
end
pathValue = local_first_existing_file(candidates);
end

function pathValue = local_find_cst_executable(spec)
if isfield(spec, 'cst') && isfield(spec.cst, 'executable')
    candidate = strtrim(char(spec.cst.executable));
    if ~isempty(candidate) && exist(candidate, 'file')
        pathValue = candidate;
        return;
    end
end
pathValue = local_where_executable('CST DESIGN ENVIRONMENT_AMD64.exe');
if ~isempty(pathValue)
    return;
end
roots = {getenv('ProgramFiles'), getenv('ProgramW6432'), getenv('ProgramFiles(x86)'), ...
    'C:\Program Files', 'D:\software', 'D:\Program Files'};
candidates = {};
for idx = 1:numel(roots)
    root = strtrim(char(roots{idx}));
    if isempty(root)
        continue;
    end
    candidates = [candidates, local_glob_files(fullfile(root, 'CST Studio Suite*', 'AMD64', 'CST DESIGN ENVIRONMENT_AMD64.exe'))]; %#ok<AGROW>
    candidates = [candidates, local_glob_files(fullfile(root, 'Dassault Systemes', 'CST Studio Suite*', 'AMD64', 'CST DESIGN ENVIRONMENT_AMD64.exe'))]; %#ok<AGROW>
    candidates = [candidates, local_glob_files(fullfile(root, 'CST*', 'AMD64', 'CST DESIGN ENVIRONMENT_AMD64.exe'))]; %#ok<AGROW>
end
pathValue = local_first_existing_file(candidates);
end

function pathValue = local_find_python_executable(spec)
pythonExe = local_get_python_path(spec);
if ~isempty(pythonExe) && exist(pythonExe, 'file')
    pathValue = pythonExe;
    return;
end
try
    envInfo = pyenv;
    if ~isempty(envInfo.Executable)
        candidate = char(envInfo.Executable);
        if exist(candidate, 'file')
            pathValue = candidate;
            return;
        end
    end
catch
end
pathValue = local_python_from_command('python');
if ~isempty(pathValue)
    return;
end
pathValue = local_python_from_command('py -3');
if ~isempty(pathValue)
    return;
end
candidates = {local_where_executable('python.exe')};
candidates = [candidates, local_glob_files(fullfile(getenv('LOCALAPPDATA'), 'Programs', 'Python', 'Python*', 'python.exe'))];
pathValue = local_first_existing_file(candidates);
end

function pathValue = local_python_from_command(commandText)
pathValue = '';
[status, out] = system([commandText, ' -c "import sys; print(sys.executable)"']);
if status ~= 0
    return;
end
lines = regexp(strtrim(out), '\r\n|\n|\r', 'split');
for idx = 1:numel(lines)
    candidate = local_clean_path(lines{idx});
    if ~isempty(candidate) && exist(candidate, 'file')
        pathValue = candidate;
        return;
    end
end
end

function pathValue = local_where_executable(exeName)
pathValue = '';
queryText = strtrim(char(exeName));
if contains(queryText, ' ')
    queryText = ['"', queryText, '"'];
end
[status, out] = system(['where ', queryText]);
if status ~= 0
    return;
end
lines = regexp(strtrim(out), '\r\n|\n|\r', 'split');
for idx = 1:numel(lines)
    candidate = local_clean_path(lines{idx});
    if ~isempty(candidate) && exist(candidate, 'file')
        pathValue = candidate;
        return;
    end
end
end

function files = local_glob_files(patternText)
files = {};
patternText = strtrim(char(patternText));
if isempty(patternText)
    return;
end
listing = dir(patternText);
for idx = 1:numel(listing)
    if ~listing(idx).isdir
        files{end+1} = fullfile(listing(idx).folder, listing(idx).name); %#ok<AGROW>
    end
end
end

function pathValue = local_first_existing_file(candidates)
pathValue = '';
if isempty(candidates)
    return;
end
if ischar(candidates)
    candidates = {candidates};
end
for idx = 1:numel(candidates)
    candidate = local_clean_path(candidates{idx});
    if ~isempty(candidate) && exist(candidate, 'file')
        pathValue = candidate;
        return;
    end
end
end

function candidate = local_clean_path(candidate)
candidate = strtrim(char(candidate));
candidate = regexprep(candidate, '^"+|"+$', '');
end

function folderName = local_existing_parent(pathValue)
folderName = pwd;
pathValue = local_clean_path(pathValue);
if isempty(pathValue)
    return;
end
if exist(pathValue, 'file')
    folderName = fileparts(pathValue);
    return;
end
if exist(pathValue, 'dir')
    folderName = pathValue;
    return;
end
candidate = pathValue;
for idx = 1:20
    parent = fileparts(candidate);
    if isempty(parent) || strcmp(parent, candidate)
        break;
    end
    if exist(parent, 'dir')
        folderName = parent;
        return;
    end
    candidate = parent;
end
end

function pythonExe = local_get_python_path(spec)
pythonExe = '';
if isfield(spec, 'environment') && isfield(spec.environment, 'python_executable')
    pythonExe = strtrim(char(spec.environment.python_executable));
end
end

function projectName = local_get_solver_project_name(spec)
switch upper(strtrim(char(spec.solver)))
    case 'CST'
        projectName = char(spec.cst.project_basename);
    otherwise
        projectName = char(spec.hfss.project_basename);
end
end

function waitHandle = local_open_progress_dialog(spec)
waitHandle = [];
if ~usejava('awt')
    return;
end
messageText = sprintf('正在生成 %s 模型，请稍候...', upper(spec.solver));
try
    waitHandle = waitbar(0.35, messageText, ...
        'Name', '缝隙波导阵列设计器', ...
        'WindowStyle', 'modal');
    drawnow;
catch
    waitHandle = [];
end
end

function local_close_progress_dialog(waitHandle)
if isempty(waitHandle)
    return;
end
try
    if isgraphics(waitHandle)
        close(waitHandle);
    end
catch
end
end

function local_set_generate_controls_enabled(buildButton, cancelButton)
try
    if isvalid(buildButton)
        buildButton.Enable = 'on';
    end
    if isvalid(cancelButton)
        cancelButton.Enable = 'on';
    end
catch
end
end

function local_show_success_dialog(spec, result)
messageText = sprintf('%s 模型已生成完成。\n\n输出目录：%s', ...
    upper(spec.solver), spec.output_dir);
if isfield(result, 'generated_files')
    fields = fieldnames(result.generated_files);
    if ~isempty(fields)
        item = result.generated_files.(fields{1});
        if isstruct(item)
            if isfield(item, 'macro_path')
                messageText = sprintf('%s\n主文件：%s', messageText, item.macro_path);
                if isfield(item, 'runner_bat') && ~isempty(item.runner_bat)
                    messageText = sprintf('%s\nCST 启动脚本：%s', messageText, item.runner_bat);
                end
                if isfield(item, 'project_path') && ~isempty(item.project_path)
                    messageText = sprintf('%s\nCST 工程目标：%s', messageText, item.project_path);
                end
            elseif isfield(item, 'vbs_path')
                messageText = sprintf('%s\n主文件：%s', messageText, item.vbs_path);
            end
        end
    end
end
if usejava('awt')
    h = msgbox(messageText, '生成完成', 'help', 'modal');
    uiwait(h);
else
    fprintf('%s\n', messageText);
end
end

function local_handle_run_error(ME, repoRoot)
reportText = getReport(ME, 'extended', 'hyperlinks', 'off');
fprintf(2, '%s\n', reportText);
logDir = fullfile(repoRoot, 'output');
if ~exist(logDir, 'dir')
    mkdir(logDir);
end
logPath = fullfile(logDir, 'last_run_error.txt');
fid = fopen(logPath, 'w');
if fid >= 0
    fwrite(fid, reportText, 'char');
    fclose(fid);
end
messageText = sprintf('模型生成失败。\n\n错误：%s\n\n详细日志：%s', ME.message, logPath);
if usejava('awt')
    h = errordlg(messageText, '运行失败', 'modal');
    uiwait(h);
else
    fprintf(2, '%s\n', messageText);
end
end

function local_draw_preview(ax, spec, arrayData, weights)
cla(ax);
hold(ax, 'on');
ax.Color = [0.985 0.988 0.992];
ax.XColor = [0.40 0.45 0.52];
ax.YColor = [0.40 0.45 0.52];
ax.FontName = 'Segoe UI';
ax.Box = 'on';

Nx = arrayData.Nx;
Ny = arrayData.Ny;
rowPitch = arrayData.row_outer_pitch_mm;
slotPitch = arrayData.dy_mm;
aRad = arrayData.radiating_waveguide.a_mm;
aCpl = arrayData.coupling_waveguide.a_mm;
lambdaGCpl = arrayData.coupling_calc.lambda_g_mm;
lambdaGRad = arrayData.radiating_calc.lambda_g_mm;
rowY = ((1:Nx) - (Nx+1)/2) * rowPitch;
slotX = ((1:Ny) - (Ny+1)/2) * slotPitch;
branchLen = (Ny - 1) * slotPitch + 0.5 * lambdaGRad;
feedLen = (Nx - 1) * rowPitch + 0.5 * lambdaGCpl;
panelX = [-branchLen/2 - 0.10*branchLen, branchLen/2 + 0.10*branchLen];
panelY = [min(rowY)-aRad/2-0.60*rowPitch, max(rowY)+aRad/2+0.60*rowPitch];

rectangle(ax, 'Position', [panelX(1), panelY(1), diff(panelX), diff(panelY)], ...
    'FaceColor', [0.90 0.93 0.97], 'EdgeColor', [0.42 0.48 0.58], 'LineWidth', 1.2);

rectangle(ax, 'Position', [-aCpl/2, -feedLen/2, aCpl, feedLen], ...
    'FaceColor', [0.76 0.82 0.90], 'EdgeColor', [0.25 0.32 0.43], 'LineWidth', 1.4);

for ix = 1:Nx
    rectangle(ax, 'Position', [-branchLen/2, rowY(ix)-aRad/2, branchLen, aRad], ...
        'FaceColor', [0.82 0.87 0.94], 'EdgeColor', [0.23 0.31 0.44], 'LineWidth', 1.0);
end

wAmp = weights.Wamp;
if size(wAmp, 1) ~= Ny || size(wAmp, 2) ~= Nx
    wAmp = ones(Ny, Nx);
end

for ix = 1:Nx
    rectangle(ax, 'Position', [-0.6, rowY(ix)-0.22*aRad, 1.2, 0.44*aRad], ...
        'FaceColor', [0.95 0.66 0.18], 'EdgeColor', [0.58 0.33 0.05], 'LineWidth', 1.0);
    for iy = 1:Ny
        amp = max(0.05, min(1.0, wAmp(iy, ix)));
        color = (1-amp) * [0.72 0.82 0.94] + amp * [0.05 0.30 0.72];
        signVal = (-1)^(iy + ix);
        slotY = rowY(ix) + signVal * 0.16 * aRad;
        rectangle(ax, 'Position', [slotX(iy)-0.18*slotPitch, slotY-0.28, 0.36*slotPitch, 0.56], ...
            'FaceColor', color, 'EdgeColor', [0.02 0.10 0.22], 'LineWidth', 0.8);
    end
end

local_dim_line(ax, slotX(1), panelY(2)+0.08*rowPitch, slotX(2), panelY(2)+0.08*rowPitch, ...
    '辐射缝间距 = lambda_g,rad / 2');
local_dim_line(ax, panelX(2)+0.04*branchLen, rowY(1), panelX(2)+0.04*branchLen, rowY(2), ...
    '行间距 = lambda_g,cpl / 2');

text(ax, panelX(1)+0.02*diff(panelX), panelY(2)-0.08*diff(panelY), ...
    sprintf('Nx = %d 根辐射波导', Nx), 'FontWeight', 'bold', 'FontSize', 11, 'Color', [0.11 0.17 0.26]);
text(ax, panelX(1)+0.02*diff(panelX), panelY(2)-0.13*diff(panelY), ...
    sprintf('Ny = 每根 %d 个辐射缝隙', Ny), 'FontWeight', 'bold', 'FontSize', 11, 'Color', [0.11 0.17 0.26]);
text(ax, panelX(1)+0.02*diff(panelX), panelY(1)+0.08*diff(panelY), ...
    '颜色深浅 = 幅度分布', 'FontSize', 10, 'Color', [0.19 0.28 0.39]);
text(ax, 0, panelY(2)+0.15*rowPitch, ...
    sprintf('a_rad = %.3f mm = lambda_g,cpl/2 - t', aRad), ...
    'HorizontalAlignment', 'center', 'FontSize', 10, 'FontWeight', 'bold', 'Color', [0.13 0.22 0.34]);

axis(ax, 'equal');
xlim(ax, [panelX(1)-0.05*branchLen, panelX(2)+0.22*branchLen]);
ylim(ax, [panelY(1)-0.20*rowPitch, panelY(2)+0.22*rowPitch]);
xlabel(ax, '辐射波导方向 X (mm)');
ylabel(ax, '馈电/行方向 Y (mm)');
title(ax, sprintf('%s  %.3f GHz, %s 分布, SLL %.1f dB', ...
    spec.waveguide.name, spec.f0_Hz/1e9, spec.synth_x.type, spec.sll_dB));
hold(ax, 'off');
end

function local_dim_line(ax, x1, y1, x2, y2, labelText)
plot(ax, [x1 x2], [y1 y2], '-', 'Color', [0.12 0.23 0.36], 'LineWidth', 1.2);
if abs(x2 - x1) >= abs(y2 - y1)
    m1 = '<';
    m2 = '>';
else
    m1 = 'v';
    m2 = '^';
end
plot(ax, x1, y1, m1, 'Color', [0.12 0.23 0.36], 'MarkerFaceColor', [0.12 0.23 0.36], 'MarkerSize', 5);
plot(ax, x2, y2, m2, 'Color', [0.12 0.23 0.36], 'MarkerFaceColor', [0.12 0.23 0.36], 'MarkerSize', 5);
text(ax, 0.5*(x1+x2), 0.5*(y1+y2), labelText, ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
    'FontSize', 9, 'FontWeight', 'bold', 'Color', [0.12 0.23 0.36], ...
    'BackgroundColor', [0.985 0.988 0.992], 'Margin', 2);
end

function textValue = local_path_or_placeholder(pathValue) %#ok<DEFNU>
if nargin < 1 || isempty(pathValue)
    textValue = '未设置';
else
    textValue = strtrim(char(pathValue));
    if isempty(textValue)
        textValue = '未设置';
    end
end
end
