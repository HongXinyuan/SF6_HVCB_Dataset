clear; clc; close all;

%% ---- 0) 路径准备: 将工程子目录加入搜索路径 ----
thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir); thisDir = pwd; end
cd(thisDir);
addpath(genpath(thisDir));    % 含 layers/ 与 utils/

%% ---- 1) 选择实验并读取配置 ----
% >>> 切换 M1~M8 只需修改这一行 <<<
experimentName = "M8";

cfg = getExperimentConfig(experimentName);

% 自动创建结果目录(若不存在)
cellfun(@(d) ~exist(d,'dir') && mkdir(d), ...
    {cfg.resultRoot, cfg.figDir, cfg.metricDir, cfg.modelDir, cfg.predDir});

fprintf('==========================================================\n');
fprintf('  SF6 断路器触头长度反演实验 (KAN Network)\n');
fprintf('==========================================================\n');
fprintf('实验编号    : %s\n', cfg.experimentName);
fprintf('数据集      : %s\n', strjoin(cfg.useDatasets, ', '));
fprintf('数据修正    : %d   物理特征: %d   注意力融合: %d\n', ...
    cfg.useCorrection, cfg.usePhysicalFeatures, cfg.useAttentionFusion);
fprintf('损失类型    : %s  (lambdaAlign=%.3g, lambdaMono=%.3g)\n', ...
    cfg.lossType, cfg.lambdaAlign, cfg.lambdaMono);
fprintf('数据根目录  : %s\n', cfg.dataRoot);
fprintf('----------------------------------------------------------\n');

%% ---- 2) 设定随机种子(实验可复现) ----
setRandomSeed(cfg.randomSeed);

%% ---- 3) 读取 + 清洗 + 特征提取 ----
fprintf('\n[1/6] 读取并预处理数据集 ...\n');
[data, loadInfo] = loadAllDatasets(cfg);

if isempty(data.labels)
    error(['未读取到任何有效样本, 请检查数据根目录 cfg.dataRoot 是否正确, ' ...
           '以及对应数据集文件夹是否存在 .dat 文件。当前 dataRoot = %s'], cfg.dataRoot);
end

fprintf('  成功样本数: %d   (失败/跳过: %d)\n', numel(data.labels), loadInfo.nFail);
fprintf('  长度标签范围: [%.2f, %.2f] mm\n', min(data.labels), max(data.labels));
uSrc = unique(data.source);
for i = 1:numel(uSrc)
    fprintf('    - %-30s : %d 条\n', uSrc{i}, sum(strcmp(data.source, uSrc{i})));
end

%% ---- 4) 划分训练/验证/测试集 ----
fprintf('\n[2/6] 划分数据集 (%.0f%%/%.0f%%/%.0f%%) ...\n', ...
    cfg.trainRatio*100, cfg.valRatio*100, cfg.testRatio*100);
split = splitDataset(data, cfg);
fprintf('  训练集: %d   验证集: %d   测试集: %d\n', ...
    numel(split.trainIdx), numel(split.valIdx), numel(split.testIdx));

% Cas 参考模板只能由训练集 Dr 构建, 再固定用于全部子集与单条预测
data = prepareCasFeatures(data, split, cfg);

%% ---- 5) 构建模型 ----
fprintf('\n[3/6] 构建 KAN 回归模型 ...\n');
model = buildKANModel(cfg);

%% ---- 6) 训练 ----
fprintf('\n[4/6] 训练模型 ...\n');
[model, history] = trainKANModel(model, data, split, cfg);

%% ---- 7) 评估(训练/验证/测试) ----
fprintf('\n[5/6] 评估模型 ...\n');
[metricsTrain, trainTable] = evaluateRegression(model, data, split.trainIdx, cfg, 'Train');
[metricsVal,   valTable]   = evaluateRegression(model, data, split.valIdx,   cfg, 'Val');
[metricsTest,  testTable]  = evaluateRegression(model, data, split.testIdx,  cfg, 'Test');

printFinalMetrics('训练集', metricsTrain);
printFinalMetrics('验证集', metricsVal);
printFinalMetrics('测试集', metricsTest);

%% ---- 8) 组装结果结构体 ----
res = struct();
res.cfg          = cfg;
res.data         = data;
res.split        = split;
res.model        = model;
res.history      = history;
res.metricsTrain = metricsTrain;
res.metricsVal   = metricsVal;
res.metricsTest  = metricsTest;
res.trainTable   = trainTable;
res.valTable     = valTable;
res.testTable    = testTable;

%% ---- 9) 可视化 ----
fprintf('\n[6/6] 生成结果图与保存 ...\n');
visualizeResults(res, cfg);

%% ---- 10) 保存模型 / 指标 / 预测 / 划分 ----
saveExperimentResults(res, cfg);

fprintf('\n==========================================================\n');
fprintf('  实验 %s 完成! 结果已保存到: %s\n', cfg.experimentName, cfg.resultRoot);
fprintf('==========================================================\n');

%% ---- (可选) 批量单条曲线预测示例 ----
% 训练完成后, 如需对 Dr_Real_Erosion_Dataset 中所有 .dat 文件逐条预测并保存表格,
% 取消下面整段注释即可运行:
% modelPath = fullfile(cfg.modelDir, sprintf('model_%s.mat', cfg.experimentName));
% dataFolder = fullfile(cfg.dataRoot, 'Dr_Real_Erosion_Dataset');
% if ~isfolder(dataFolder)
%     error('预测文件夹不存在: %s', dataFolder);
% end
% datFiles = dir(fullfile(dataFolder, '*.dat'));
% [~, ord] = sort({datFiles.name});
% datFiles = datFiles(ord);
% nFile = numel(datFiles);
% 
% FileName   = strings(nFile, 1);
% TrueLength = nan(nFile, 1);
% PredLength = nan(nFile, 1);
% AbsError   = nan(nFile, 1);
% Rmax       = nan(nFile, 1);
% tpeak      = nan(nFile, 1);
% OK         = false(nFile, 1);
% Msg        = strings(nFile, 1);
% 
% for i = 1:nFile
%     datFile = fullfile(datFiles(i).folder, datFiles(i).name);
%     out = predictSingleCurve(modelPath, datFile, cfg);
% 
%     FileName(i)   = string(datFiles(i).name);
%     TrueLength(i) = parseLengthFromFilename(datFile);
%     OK(i)         = out.ok;
%     Msg(i)        = string(out.msg);
% 
%     if out.ok
%         PredLength(i) = out.predLength;
%         Rmax(i)       = out.Rmax;
%         tpeak(i)      = out.tpeak;
%         if isfinite(TrueLength(i))
%             AbsError(i) = abs(PredLength(i) - TrueLength(i));
%         end
%         fprintf('单条预测: 文件=%s 预测长度=%.3f mm (Rmax=%.3f, tpeak=%.3f)\n', ...
%             datFile, out.predLength, out.Rmax, out.tpeak);
%     else
%         fprintf('单条预测失败: 文件=%s 原因=%s\n', datFile, out.msg);
%     end
% end
% 
% batchTable = table(FileName, TrueLength, PredLength, AbsError, Rmax, tpeak, OK, Msg);
% outTablePath = fullfile(thisDir, sprintf('batch_single_curve_predictions_%s.xlsx', cfg.experimentName));
% writetable(batchTable, outTablePath);
% fprintf('批量预测结果已保存: %s\n', outTablePath);

%% ====================== 局部函数: 打印指标 ======================
function printFinalMetrics(name, m)
    fprintf('  [%s] MAE=%.4f  RMSE=%.4f  R2=%.4f  MaxAE=%.4f  MeanRelErr=%.2f%%\n', ...
        name, m.MAE, m.RMSE, m.R2, m.MaxAE, m.MeanRelError);
end
