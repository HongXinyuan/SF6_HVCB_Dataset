function model = buildKANModel(cfg)
% buildKANModel  构建基于 KAN 的动态电阻回归模型(函数式参数结构)
% 模型结构(与论文一致):
%   动态电阻曲线输入
%        ↓  曲线编码模块 (1D CNN x3 + 全局平均池化 + 全连接)
%        ↓  物理特征分支 (MLP, 可选)
%        ↓  多源注意力融合 (可选) / 直接拼接
%        ↓  KAN 回归头 (两层 KAN, RBF 可学习样条)
%        ↓  触头长度预测(标准化空间, 评估时反标准化)

    rng(cfg.randomSeed);   % 权重初始化可复现
    fSize = cfg.encoderFilter;
    ch    = cfg.encoderChannels;
    Dc    = cfg.curveFeatDim;
    Dp    = cfg.physFeatDim;
    dAtt  = cfg.attnDim;
    H     = cfg.kanHiddenDim;
    K     = cfg.kanNumCenters;
    F     = cfg.numPhysicalFeatures;

    he = @(fanIn) sqrt(2/max(fanIn,1));   % He 初始化标准差

    learn = struct();

    %% ---- 曲线编码器: 三层 1D 卷积 ----
    % 卷积权重维度: [filterSize, inChannels, outChannels]
    learn.enc.c1w = dl(he(fSize*1)     * randn(fSize, 1,     ch(1), 'single'));
    learn.enc.c1b = dl(zeros(ch(1), 1, 'single'));
    learn.enc.c2w = dl(he(fSize*ch(1)) * randn(fSize, ch(1), ch(2), 'single'));
    learn.enc.c2b = dl(zeros(ch(2), 1, 'single'));
    learn.enc.c3w = dl(he(fSize*ch(2)) * randn(fSize, ch(2), ch(3), 'single'));
    learn.enc.c3b = dl(zeros(ch(3), 1, 'single'));
    % 全局平均池化+最大池化后 -> 全连接到 Dc
    learn.enc.fcw = dl(he(2*ch(3)) * randn(Dc, 2*ch(3), 'single'));
    learn.enc.fcb = dl(zeros(Dc, 1, 'single'));

    %% ---- 物理特征分支(可选) ----
    if cfg.usePhysicalFeatures
        learn.phys.w1 = dl(he(F)  * randn(Dp, F,  'single'));
        learn.phys.b1 = dl(zeros(Dp, 1, 'single'));
        learn.phys.w2 = dl(he(Dp) * randn(Dp, Dp, 'single'));
        learn.phys.b2 = dl(zeros(Dp, 1, 'single'));
    end

    %% ---- 融合层 & 确定 KAN 头输入维度 fusedDim ----
    if cfg.usePhysicalFeatures && cfg.useAttentionFusion
        % 注意力融合参数
        learn.att.pc = dl(1/sqrt(Dc) * randn(dAtt, Dc, 'single'));
        learn.att.pp = dl(1/sqrt(Dp) * randn(dAtt, Dp, 'single'));
        learn.att.W  = dl(1/sqrt(dAtt)* randn(dAtt, dAtt, 'single'));
        learn.att.bw = dl(zeros(dAtt, 1, 'single'));
        learn.att.v  = dl(1/sqrt(dAtt)* randn(dAtt, 1, 'single'));
        fusedDim = dAtt;
    elseif cfg.usePhysicalFeatures && ~cfg.useAttentionFusion
        fusedDim = Dc + Dp;               % 直接拼接
    else
        fusedDim = Dc;                    % 仅曲线特征
    end

    %% ---- KAN 回归头(两层) ----
    % KAN 层 1: fusedDim -> H
    learn.kan1.Wbase   = dl(1/sqrt(fusedDim) * randn(H, fusedDim, 'single'));
    learn.kan1.Wspline = dl(0.1/sqrt(fusedDim)* randn(H, fusedDim, K, 'single'));
    learn.kan1.Bias    = dl(zeros(H, 1, 'single'));
    % KAN 层 2: H -> 1
    learn.kan2.Wbase   = dl(1/sqrt(H) * randn(1, H, 'single'));
    learn.kan2.Wspline = dl(0.1/sqrt(H)* randn(1, H, K, 'single'));
    learn.kan2.Bias    = dl(zeros(1, 1, 'single'));

    %% ---- 固定常量 ----
    centers = linspace(cfg.kanGridRange(1), cfg.kanGridRange(2), K);
    if K > 1
        hgrid = (cfg.kanGridRange(2) - cfg.kanGridRange(1)) / (K - 1);
    else
        hgrid = 1;
    end

    fixed = struct();
    fixed.usePhysicalFeatures = cfg.usePhysicalFeatures;
    fixed.useAttentionFusion  = cfg.useAttentionFusion;
    fixed.centers   = centers;
    fixed.h         = hgrid;
    fixed.fusedDim  = fusedDim;
    fixed.curveLength = cfg.curveLength;
    fixed.numFeatures = F;
    fixed.minCurveAttention = cfg.minCurveAttention;
    fixed.yMean = 0;     % 标签标准化统计(训练时填充)
    fixed.yStd  = 1;
    fixed.featMu    = zeros(1, F);   % 物理特征标准化统计(训练时填充)
    fixed.featSigma = ones(1, F);

    model = struct('learn', learn, 'fixed', fixed);

    fprintf('[buildKANModel] 模型构建完成: 融合维度=%d, KAN(%d->%d->1), 基函数K=%d\n', ...
        fusedDim, fusedDim, H, K);
end

% 小工具: 转 single dlarray
function y = dl(x)
    y = dlarray(single(x));
end
