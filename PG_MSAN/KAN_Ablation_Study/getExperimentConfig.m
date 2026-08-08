function cfg = getExperimentConfig(experimentName)
% getExperimentConfig  集中管理 M1-M8 消融实验配置
% -------------------------------------------------------------------------
% 输入:
%   experimentName : 字符串 "M1"~"M8"，默认 "M1"
% 输出:
%   cfg            : 实验配置结构体，包含路径、数据集、模型开关、损失、训练超参等
% -------------------------------------------------------------------------
% 消融实验表 (与论文一致):
%   Model TrainingData        Correction PhysFeat Attention Loss
%   M1    Dr                   No         Yes      Yes       Lreg   真实数据基准
%   M2    Da                   No         Yes      Yes       Lreg   人工数据基准
%   M3    Ds                   No         Yes      Yes       Lreg   仿真数据基准
%   M4    Dr+Da+Ds             No         Yes      Yes       Lreg   直接融合
%   M5    Dr+Da~+Ds~           Yes        No       No        Lreg   只验证修正融合
%   M6    Dr+Da~+Ds~           Yes        Yes      No        Lreg   验证物理特征
%   M7    Dr+Da~+Ds~           Yes        Yes      Yes       Lreg   验证注意力
%   M8    Dr+Da~+Ds~           Yes        Yes      Yes       Full   完整模型
% -------------------------------------------------------------------------
% 使用方法:
%   只需修改 main.m 中的 experimentName 即可切换实验，无需改动主流程。
% -------------------------------------------------------------------------

    if nargin < 1 || isempty(experimentName)
        experimentName = "M1";
    end
    experimentName = string(experimentName);

    %% ===== 1. 通用配置 (所有实验共享) =====
    cfg = struct();
    cfg.experimentName = experimentName;

    % --- 路径配置(集中管理, 按需修改) ---
    cfg.dataRoot   = 'C:\Users\Hong\Desktop\PG_MSAN\Database';  % 数据集根目录
    cfg.resultRoot = fullfile(pwd, 'results');                  % 结果输出根目录
    cfg.figDir     = fullfile(cfg.resultRoot, 'figures');
    cfg.metricDir  = fullfile(cfg.resultRoot, 'metrics');
    cfg.modelDir   = fullfile(cfg.resultRoot, 'models');
    cfg.predDir    = fullfile(cfg.resultRoot, 'predictions');

    % 五类数据集文件夹名称(与磁盘目录一致)
    cfg.datasetFolders = struct( ...
        'Dr',     'Dr_Real_Erosion_Dataset', ...
        'Da',     'Da_Artificial_Dataset', ...
        'Ds',     'Ds_Simulation_Dataset', ...
        'DaTilde','Da~_Artificial-to-Real_Dataset', ...
        'DsTilde','Ds~_Simulation-to-Real_Dataset');

    % --- 数据清洗 / 物理参数 ---
    cfg.truncationThreshold = 10;     % R >= 10 mOhm 为采样截断的无效值, 必须剔除
    cfg.peakWindow          = [14 15];% 第一波峰 Rmax 搜索时间窗 (ms)
    cfg.curveLength         = 256;    % 曲线重采样固定长度
    cfg.commonTimeWindow    = [];     % [] = 按每条曲线自身时间跨度重采样;
                                      % 也可设为 [t1 t2] 在统一绝对时间窗对齐
    cfg.curveNormMethod     = 'fixedscale'; % 按截断阈值统一缩放, 保留绝对幅值

    % Dlow 局部低阻持续时间检测参数
    cfg.dlowDropRatio = 0.5;   % tpeak 之后电阻下降到 Rmax 的该比例视为进入低阻区
    cfg.dlowRiseRatio = 0.9;   % 之后回升到 Rmax 的该比例视为离开低阻区

    % --- 物理特征 ---
    cfg.numPhysicalFeatures = 7;      % [Rmax Rmean Smax AR tpeak Dlow Cas]
    cfg.physicalFeatureNames = {'Rmax','Rmean','Smax','AR','tpeak','Dlow','Cas'};
    cfg.casDefault          = 0.5;    % 无真实模板可比时 Cas 余弦相似度默认值

    % --- 数据集划分 ---
    cfg.trainRatio = 0.70;
    cfg.valRatio   = 0.15;
    cfg.testRatio  = 0.15;
    cfg.randomSeed = 2024;            % 复现实验随机种子

    % --- 训练超参 ---
    cfg.maxEpochs       = 200;
    cfg.miniBatchSize   = 16;
    cfg.initialLR       = 1e-3;
    cfg.lrDropFactor    = 0.5;
    cfg.lrDropPeriod    = 80;         % 每多少 epoch 衰减一次学习率
    cfg.l2Reg           = 1e-4;       % 权重 L2 正则系数
    cfg.validationPatience = 40;      % 早停容忍 epoch 数
    cfg.executionEnvironment = 'auto';% 'auto'/'cpu'/'gpu'
    cfg.verbose         = true;

    % --- 模型结构超参 ---
    cfg.encoderChannels = [16 32 64]; % 1D CNN 各层通道数
    cfg.encoderFilter   = 5;          % 卷积核大小
    cfg.curveFeatDim    = 64;         % 曲线特征维度 Dc
    cfg.physFeatDim     = 32;         % 物理特征分支维度 Dp
    cfg.attnDim         = 64;         % 注意力融合公共维度 d
    cfg.kanHiddenDim    = 32;         % KAN 隐藏维度 H
    cfg.kanNumCenters   = 8;          % KAN 每条边的基函数(RBF)数量 K
    cfg.kanGridRange    = [-1 1];     % KAN 基函数网格范围(配合 tanh 压缩)
    cfg.minCurveAttention = 0.65;     % 曲线注意力权重硬下限
    cfg.physModalityDropout = 0.25;   % 训练时随机屏蔽物理模态的样本比例

    %% ===== 2. 各实验差异化配置 =====
    F = cfg.datasetFolders;
    switch experimentName
        case "M1"   % 真实数据基准
            cfg.useDatasets        = {F.Dr};
            cfg.useCorrection      = false;
            cfg.usePhysicalFeatures= true;
            cfg.useAttentionFusion = true;
            cfg.lossType           = "Lreg";
        case "M2"   % 人工数据基准
            cfg.useDatasets        = {F.Da};
            cfg.useCorrection      = false;
            cfg.usePhysicalFeatures= true;
            cfg.useAttentionFusion = true;
            cfg.lossType           = "Lreg";
        case "M3"   % 仿真数据基准
            cfg.useDatasets        = {F.Ds};
            cfg.useCorrection      = false;
            cfg.usePhysicalFeatures= true;
            cfg.useAttentionFusion = true;
            cfg.lossType           = "Lreg";
        case "M4"   % 直接融合 Dr+Da+Ds
            cfg.useDatasets        = {F.Dr, F.Da, F.Ds};
            cfg.useCorrection      = false;
            cfg.usePhysicalFeatures= true;
            cfg.useAttentionFusion = true;
            cfg.lossType           = "Lreg";
        case "M5"   % 只验证修正融合(无物理特征/无注意力)
            cfg.useDatasets        = {F.Dr, F.DaTilde, F.DsTilde};
            cfg.useCorrection      = true;
            cfg.usePhysicalFeatures= false;
            cfg.useAttentionFusion = false;
            cfg.lossType           = "Lreg";
        case "M6"   % 验证物理特征(有物理特征/无注意力)
            cfg.useDatasets        = {F.Dr, F.DaTilde, F.DsTilde};
            cfg.useCorrection      = true;
            cfg.usePhysicalFeatures= true;
            cfg.useAttentionFusion = false;
            cfg.lossType           = "Lreg";
        case "M7"   % 验证注意力模块
            cfg.useDatasets        = {F.Dr, F.DaTilde, F.DsTilde};
            cfg.useCorrection      = true;
            cfg.usePhysicalFeatures= true;
            cfg.useAttentionFusion = true;
            cfg.lossType           = "Lreg";
        case "M8"   % 完整模型(Full Loss)
            cfg.useDatasets        = {F.Dr, F.DaTilde, F.DsTilde};
            cfg.useCorrection      = true;
            cfg.usePhysicalFeatures= true;
            cfg.useAttentionFusion = true;
            cfg.lossType           = "Full";
        otherwise
            error('getExperimentConfig:unknown', '未知实验名: %s (应为 M1~M8)', experimentName);
    end

    %% ===== 3. 完整损失权重 (Full 模式生效) =====
    % 优先级: Lreg > lambdaAlign*Lalign > lambdaMono*Lmono
    cfg.lambdaAlign = 0.025;    % 分布对齐损失权重
    cfg.lambdaMono  = 0.0175;   % 物理单调约束权重
    cfg.regLossType = 'mse';  % 基础回归损失: 'mse' 或 'mae'

    % 标记哪些数据集属于"真实域"(用于对齐损失中的真实端)
    cfg.realDomainFolders = {F.Dr};
end
