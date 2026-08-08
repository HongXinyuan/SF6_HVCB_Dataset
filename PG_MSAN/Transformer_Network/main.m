%% ========================================================================
%  main.m
%  SF6 断路器触头动态电阻曲线：人工数据 -> 真实烧蚀数据 的 Transformer 校准

clear; clc; close all;

%% ----------------------- 1. 路径集中定义（按需修改） --------------------
dbDir         = 'C:\Users\Hong\Desktop\PG_MSAN\Database';                      % 数据库根目录(Note: Please modify according to your address)
realDir       = fullfile(dbDir, 'Dr_Real_Erosion_Dataset');                    % 真实烧蚀数据
artificialDir = fullfile(dbDir, 'Ds_Simulation_Dataset');                      % 人工制造数据(Note: Please modify after traning: 'Da_Artificial_Dataset')
outDir        = fullfile(dbDir, 'Ds~_Simulation-to-Real_Dataset');             % 校准后 .dat 输出(Note: Please modify after traning: 'Da~_Artificial-to-Real_Dataset')
allModifyFile = fullfile(dbDir, 'AllModify.xlsx');                             % 校准总表
meanTableFile = fullfile(dbDir, 'FeatureCompare_AllMean.xlsx');                % 平均特征总表
metricsTableFile   = fullfile(dbDir, 'CurveMetricsCompare.xlsx');              % 新增：曲线校准度量总表(校准前/后对比)
featureCompareFile = fullfile(dbDir, 'FeatureCompare.xlsx');                   % 新增：人工输出 vs 真实加权虚拟目标特征对比表
featTableDir  = fullfile(dbDir, 'FeatureCompareTables');                       % 每个真实数据的特征对比表
figDir        = fullfile(dbDir, 'Figures');                                    % 图片输出目录
trainedModelFile = fullfile(dbDir, 'TransformerCorrectionModel.mat');          % 模型保存路径

%% ----------------------- 2. 全部可调参数 cfg ----------------------------
cfg = struct();

% ---- 数据清洗 / 物理约定 ----
cfg.Rcut            = 10;      % 动态电阻截断阈值（mΩ）：R >= 10 视为无效（趋近无穷大）
cfg.minValidPoints  = 20;      % 单条曲线最少有效点数，少于该数的文件将被跳过
cfg.cleanSmooth     = false;   % 清洗阶段是否对有效段做平滑（默认关闭，特征提取内部另有平滑）
cfg.cleanSmoothWindow = 5;     % 清洗阶段平滑窗口（仅 cleanSmooth=true 时生效）

% ---- 重采样 ----
cfg.N               = 512;     % 统一时间网格点数（模型输入序列长度），可改为 1024
cfg.NExcel          = 1000;    % AllModify.xlsx 公共时间网格点数

% ---- 特征提取 ----
cfg.smoothWindow    = 5;       % 特征提取内部平滑窗口（movmean，仅在有效连续段内平滑）
cfg.peakProminence  = 0.2;     % 第一波峰检测的最小突出度（mΩ），按数据噪声水平调整
cfg.DlowThreshold   = 5;       % 局部低阻判定阈值（mΩ），可配置：低于该值视为"低阻"
cfg.RmaxWindow      = [14, 15]; % Rmax/tpeak 固定在该时间窗内取有效点最大值

% ---- Transformer 结构 ----
cfg.numInputChannels = 4;      % 输入通道：[归一化时间; 归一化人工电阻; 有效掩码; 归一化触头长度]
cfg.hiddenSize      = 64;      % 隐层维度（必须能被注意力头数整除）
cfg.numHeads        = 4;       % 注意力头数
cfg.numBlocks       = 2;       % Transformer 编码器层数（小样本下不宜过深）
cfg.ffnSize         = 128;     % 前馈网络维度
cfg.dropout         = 0.1;     % dropout 概率（小样本正则化）
cfg.usePositionEmbedding = true; % 是否使用可学习位置嵌入（不可用时自动退化）

% ---- 训练超参数 ----
cfg.maxEpochs       = 360;     % 最大训练轮数
cfg.miniBatchSize   = 8;       % batch size
cfg.learnRate       = 1e-3;    % 初始学习率
cfg.lrDropFactor    = 0.5;     % 学习率衰减倍率
cfg.lrDropPeriod    = 100;     % 每多少个 epoch 衰减一次
cfg.weightDecay     = 1e-4;    % 权重衰减（L2 正则，缓解过拟合）
cfg.gradClip        = 1.0;     % 梯度 L2 裁剪阈值
cfg.valRatio        = 0.2;     % 验证集比例（按"配对"划分）
cfg.patience        = 80;      % 早停耐心轮数（验证损失不再下降则停止）
cfg.printEvery      = 10;      % 每多少个 epoch 打印一次训练信息
cfg.rngSeed         = 42;      % 随机种子（保证可复现）

% ---- 小样本数据增强（仅作用于训练集，缓解过拟合） ----
cfg.numAug          = 12;       % 每条训练曲线额外生成的增强样本数
cfg.augNoiseStd     = 0.01;    % 增强噪声标准差（归一化电阻量纲，0.01 ≈ 0.1 mΩ）
cfg.augScaleJitter  = 0.02;    % 增强幅值抖动（±2%）

% ---- 校准头约束（保证 alpha/beta/DeltaR 数值稳定） ----
cfg.alphaRange      = 0.5;     % alpha ∈ (1-0.5, 1+0.5)
cfg.betaRange       = 0.3;     % beta（归一化量纲）∈ (-0.3, 0.3)，对应物理量 ±3 mΩ
cfg.deltaScale      = 0.8;     % DeltaR（归一化量纲）∈ (-0.8, 0.8)，对应物理量 ±8 mΩ

% ---- 损失函数正则项 ----
cfg.lambdaDelta     = 1e-3;    % DeltaR 幅值惩罚：鼓励 alpha/beta 承担仿射部分
cfg.lambdaSmooth    = 1e-2;    % DeltaR 时间平滑惩罚：避免残差项高频抖动

% ---- 【新增】峰值(Rmax) / 最大上升斜率(Smax) 局部特征约束 ----
% 背景：原损失仅为整条曲线的 masked MSE，误差能量被高幅值的尾部主导，
%       而 Rmax(第一波峰，仅 ~1 mΩ) 与 Smax(峰前最大上升斜率) 属于
%       低幅值局部特征，对 MSE 贡献极小，导致网络忽略该区域，
%       甚至把原本已接近目标的首峰区破坏（Rmax/Smax 修正后反而变差）。
% 对策：(a) 在 MSE 中对首峰窗口加权；(b) 显式加入 Rmax/Smax 可微软约束。
cfg.peakWindow      = [14, 15]; % 首峰区时间窗(s)，与 extractDRFeatures 的 RmaxWindow 一致
cfg.peakWeight      = 10;       % 首峰窗口在 masked MSE 中的额外加权(0=关闭)
cfg.lambdaRmax      = 1.0;      % Rmax 软约束权重(归一化量纲，越大越强制峰值对齐)
cfg.lambdaSmax      = 0.3;      % Smax 软约束权重(归一化栅格斜率)
cfg.softmaxTau      = 50;       % soft-max 温度：越大越逼近真实 max(可微近似)
cfg.featMonitor     = true;     % 训练过程中监控 Rmax/Smax 误差并打印

% ---- 流程控制 ----
cfg.retrain         = true;    % true: 重新训练；false: 若模型文件存在则直接加载
cfg.numPlotPairs    = 4;       % 曲线对比图绘制的配对数量

%% ----------------------- 3. 环境与目录检查 ------------------------------
fprintf('================ SF6 动态电阻曲线 Transformer 校准程序 ================\n');
if exist('selfAttentionLayer', 'file') == 0
    error(['未找到 selfAttentionLayer。请确认已安装 Deep Learning Toolbox，', ...
           '并使用 MATLAB R2023a 及以上版本。']);
end
if ~isfolder(realDir),       error('真实烧蚀数据文件夹不存在：%s', realDir);       end
if ~isfolder(artificialDir), error('人工制造数据文件夹不存在：%s', artificialDir); end
if ~isfolder(outDir),        mkdir(outDir);       fprintf('已创建输出目录：%s\n', outDir);       end
if ~isfolder(featTableDir),  mkdir(featTableDir); fprintf('已创建特征表目录：%s\n', featTableDir); end
if ~isfolder(figDir),        mkdir(figDir);       fprintf('已创建图片目录：%s\n', figDir);        end

%% ----------------------- 4. 读取并清洗两个数据集 ------------------------
% 注意：loadDRDataset 内部调用 cleanDRData，对每个文件：
%   (1) 剔除 NaN/Inf 行；(2) 时间排序并去重保证单调；(3) 生成 R<10 的有效掩码。
fprintf('\n[步骤1] 读取真实烧蚀数据集...\n');
dsReal = loadDRDataset(realDir, cfg);
fprintf('\n[步骤2] 读取人工制造数据集...\n');
dsArt  = loadDRDataset(artificialDir, cfg);

%% ----------------------- 5. 统一时间网格重采样 --------------------------
% 将每条曲线的"有效时间区间"[t0, t1] 归一化到 [0,1]，重采样为 N 个点。
% 重采样只在有效连续段内进行线性插值，落在无效区间（R>=10 的时间段）的
% 网格点其掩码为 false，绝不会把无效点强行插值进有效区间。
fprintf('\n[步骤3] 统一时间网格重采样（N = %d）...\n', cfg.N);
dsReal = resampleDataset(dsReal, cfg, '真实烧蚀');
dsArt  = resampleDataset(dsArt,  cfg, '人工制造');

%% ----------------------- 6. 最近邻长度配对 ------------------------------
% 配对策略（详见 buildNearestPairs.m 注释）：
%   对每条人工曲线（长度 La），在真实数据集中寻找长度上"包夹" La 的两条
%   相邻真实曲线，按长度距离反比加权合成一条"虚拟真实目标曲线"——即假设
%   真实烧蚀数据集中本应存在一条长度恰为 La 的曲线。若 La 超出真实长度
%   范围，则退化为单一最近邻。
fprintf('\n[步骤4] 构造最近邻长度配对（人工 -> 虚拟真实目标）...\n');
pairs = buildNearestPairs(dsArt, dsReal, cfg);
for k = 1:numel(pairs)
    fprintf('  %s\n', pairs(k).desc);
end

%% ----------------------- 7. 训练 / 加载 Transformer 校准模型 ------------
if cfg.retrain || ~isfile(trainedModelFile)
    fprintf('\n[步骤5] 训练 Transformer 校准模型...\n');
    model = trainTransformerCorrectionModel(pairs, dsArt, dsReal, cfg);
    save(trainedModelFile, 'model');
    fprintf('模型已保存至：%s\n', trainedModelFile);
else
    fprintf('\n[步骤5] 检测到已有模型，直接加载：%s\n', trainedModelFile);
    S = load(trainedModelFile);
    model = S.model;
end

%% ----------------------- 8. 对所有人工曲线进行校准 ----------------------
% 输出严格体现校准结构：R_a_tilde(t) = alpha * R_a(t) + beta + DeltaR_a(t)
fprintf('\n[步骤6] 校准全部人工曲线（恢复到人工数据原始有效时间点）...\n');
calResults = repmat(struct(), numel(dsArt), 1); %#ok<NASGU>
for i = 1:numel(dsArt)
    res = predictCorrectedCurve(model, dsArt(i), cfg);
    if i == 1, calResults = repmat(res, numel(dsArt), 1); end
    calResults(i) = res;
    fprintf('  %-16s  alpha = %.4f,  beta = %+.4f mΩ\n', ...
        dsArt(i).name, res.alpha, res.beta);
end

%% ----------------------- 9. 输出校准后的 .dat 文件 ----------------------
fprintf('\n[步骤7] 输出校准后的 .dat 文件至：%s\n', outDir);
writeCorrectedDatFiles(dsArt, calResults, outDir, cfg);

%% ----------------------- 9.5. 新增：人工输出 vs 真实加权虚拟目标 FeatureCompare ----------
fprintf('\n[步骤7.5] 生成 FeatureCompare：人工输出曲线 vs 真实加权合成虚拟目标...\n');
featureCmpArtificial = writeArtificialToRealFeatureCompare(dsReal, outDir, featureCompareFile, cfg); %#ok<NASGU>

%% ----------------------- 10. 输出 AllModify.xlsx ------------------------
fprintf('\n[步骤8] 生成总表 AllModify.xlsx ...\n');
writeAllModifyExcel(dsArt, calResults, allModifyFile, cfg);

%% ----------------------- 11. 特征提取与逐文件对比表 ----------------------
fprintf('\n[步骤9] 提取特征并生成每个真实数据的特征对比表...\n');
cmp = writeFeatureCompareTables(dsReal, dsArt, calResults, featTableDir, cfg);

%% ----------------------- 12. 平均特征总表 -------------------------------
fprintf('\n[步骤10] 生成平均特征总表 FeatureCompare_AllMean.xlsx ...\n');
writeMeanFeatureTable(cmp, meanTableFile, cfg);

%% ----------------------- 12.5. 新增：曲线校准度量总表（校准前/后对比） -----
% 在 Cas 之外，补充 R2/MAPE/MaxAE/NRMSE/DTW/Frechet 等度量，
% 汇总校准前(原始人工 vs 真实) 与 校准后(校准结果 vs 真实) 的曲线匹配度对比。
% 全部度量复用 cmp.simBefore / cmp.simAfter，不重复计算。
fprintf('\n[步骤10.5] 生成曲线校准度量总表 CurveMetricsCompare.xlsx ...\n');
writeCurveMetricsTable(cmp, metricsTableFile, cfg);

%% ----------------------- 13. 绘图 ---------------------------------------
fprintf('\n[步骤11] 绘制结果图...\n');
plotResults(model, dsReal, dsArt, calResults, cmp, figDir, cfg);

%% ----------------------- 14. 结束汇总 -----------------------------------
fprintf('\n==================== 全部完成，输出文件汇总 ====================\n');
fprintf('  校准 .dat 文件目录 : %s\n', outDir);
fprintf('  校准总表           : %s\n', allModifyFile);
fprintf('  逐文件特征对比表   : %s\n', featTableDir);
fprintf('  平均特征总表       : %s\n', meanTableFile);
fprintf('  曲线校准度量总表   : %s\n', metricsTableFile);
fprintf('  人工-真实虚拟目标特征对比表 : %s\n', featureCompareFile);
fprintf('  训练模型           : %s\n', trainedModelFile);
fprintf('  结果图片           : %s\n', figDir);
fprintf('提示：小样本条件下 Transformer 可能过拟合，建议结合更多真实烧蚀样本验证。\n');

%% ======================== 本文件局部函数 =================================
function ds = resampleDataset(ds, cfg, tag)
% 对数据集中每条曲线做统一网格重采样，并把网格信息写入 ds(i).grid。
% 重采样失败（有效点过少/有效时间跨度为 0）的曲线将被剔除并给出警告。
keep = true(numel(ds), 1);
for i = 1:numel(ds)
    [tGrid, RGrid, MGrid, info] = resampleDRCurve(ds(i).t, ds(i).R, ds(i).validMask, cfg.N);
    ds(i).grid = struct('tGrid', tGrid, 'RGrid', RGrid, 'MGrid', MGrid, ...
                        't0', info.t0, 't1', info.t1, 'valid', info.valid);
    if ~info.valid
        warning('[%s] 文件 %s 重采样失败（有效数据不足），已剔除。', tag, ds(i).name);
        keep(i) = false;
    end
end
ds = ds(keep);
fprintf('  [%s] 重采样完成，可用曲线数：%d\n', tag, numel(ds));
end
