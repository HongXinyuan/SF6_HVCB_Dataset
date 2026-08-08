function model = trainTransformerCorrectionModel(pairs, dsArt, dsReal, cfg)
% trainTransformerCorrectionModel  训练 Transformer 校准模型（自定义训练循环）

rng(cfg.rngSeed);   % 固定随机种子，保证可复现

%% ---------------- 1. 长度归一化范围（训练/预测必须一致） ----------------
allL = [[dsArt.length], [dsReal.length]];
Lmin = min(allL);  Lmax = max(allL);
if Lmax <= Lmin
    Lmax = Lmin + 1;          % 极端情况：所有长度相同，避免除零
end

%% ---------------- 2. 构造样本集（按配对划分训练/验证） ------------------
numPairs = numel(pairs);
samples = cell(numPairs, 1);
for k = 1:numPairs
    samples{k} = makeSample(pairs(k), dsArt(pairs(k).aIdx), Lmin, Lmax, cfg);
end

% 按"配对"划分训练/验证集（而不是按增强样本划分，避免数据泄漏）
idxPerm = randperm(numPairs);
if numPairs >= 5
    numVal = max(1, round(cfg.valRatio * numPairs));
else
    numVal = 0;               % 配对过少时不划分验证集（早停退化为取末轮）
end
valIdx   = idxPerm(1:numVal);
trainIdx = idxPerm(numVal+1:end);

% 训练集数据增强（验证集绝不增强，保证评估客观）
trainSamples = {};
for k = trainIdx
    trainSamples{end+1} = samples{k}; %#ok<AGROW>
    for a = 1:cfg.numAug
        trainSamples{end+1} = augmentSample(samples{k}, cfg); %#ok<AGROW>
    end
end
valSamples = samples(valIdx);

fprintf('  配对总数 %d：训练配对 %d（增强后样本 %d 条），验证配对 %d\n', ...
    numPairs, numel(trainIdx), numel(trainSamples), numVal);
if numPairs < 10
    fprintf(['  警告：训练配对数(%d)较少，Transformer 在小样本下存在过拟合\n', ...
             '        风险。程序已启用 dropout/权重衰减/数据增强/早停等正则化\n', ...
             '        机制，但仍建议结合更多真实烧蚀样本进行验证。\n'], numPairs);
end

%% ---------------- 3. 构建网络与训练状态 ---------------------------------
net = buildTransformerModel(cfg);

% GPU 可用则使用 GPU 加速（不可用自动回退 CPU）
useGPU = false;
try
    useGPU = canUseGPU();
catch
    useGPU = false;
end
if useGPU
    fprintf('  检测到可用 GPU，将使用 GPU 训练。\n');
end

avgGrad = [];  avgSqGrad = [];          % Adam 状态
numTrain = numel(trainSamples);
itersPerEpoch = max(1, ceil(numTrain / cfg.miniBatchSize));

trainLossHistory = nan(cfg.maxEpochs, 1);
valLossHistory   = nan(cfg.maxEpochs, 1);
% 【新增】训练过程监控历史
dataLossHistory  = nan(cfg.maxEpochs, 1);   % 峰区加权 MSE 分量
rmaxLossHistory  = nan(cfg.maxEpochs, 1);   % Rmax 软约束分量
smaxLossHistory  = nan(cfg.maxEpochs, 1);   % Smax 软约束分量
rmaxErrHistory   = nan(cfg.maxEpochs, 1);   % 监控集 Rmax 平均绝对误差(mΩ)
smaxErrHistory   = nan(cfg.maxEpochs, 1);   % 监控集 Smax 平均绝对误差(归一化栅格斜率)
bestValLoss = inf;  bestNet = net;  bestEpoch = 0;  patienceCnt = 0;

% 监控用样本集：有验证集则用验证集，否则退化为全部训练样本(未增强的原始配对)
if ~isempty(valSamples)
    monSamples = valSamples;
else
    monSamples = samples(trainIdx);
end

%% ---------------- 4. 训练主循环 -----------------------------------------
iteration = 0;
for epoch = 1:cfg.maxEpochs
    % ---- 学习率阶梯衰减 ----
    lr = cfg.learnRate * cfg.lrDropFactor ^ floor((epoch - 1) / cfg.lrDropPeriod);

    % ---- 打乱训练样本 ----
    perm = randperm(numTrain);
    epochLoss = 0;  epochCnt = 0;
    epochData = 0;  epochRmax = 0;  epochSmax = 0;

    for it = 1:itersPerEpoch
        iteration = iteration + 1;
        bIdx = perm((it-1)*cfg.miniBatchSize + 1 : min(it*cfg.miniBatchSize, numTrain));
        if isempty(bIdx), continue; end

        % ---- 组装 mini-batch（C x B x T，'CBT'） ----
        [X, Ra, Rt, Min, Mloss, Wpk, Wrise] = assembleBatch(trainSamples(bIdx), useGPU);

        % ---- 前向 + 反向（dlfeval 中计算掩码损失与梯度） ----
        [loss, grads, lossParts] = dlfeval(@modelLoss, net, X, Ra, Rt, Min, Mloss, Wpk, Wrise, cfg);

        % ---- 解耦权重衰减（L2 正则，缓解小样本过拟合） ----
        grads = dlupdate(@(g, w) g + cfg.weightDecay .* w, grads, net.Learnables);

        % ---- 梯度 L2 范数裁剪（防止小批量下梯度爆炸） ----
        grads = clipGradL2(grads, cfg.gradClip);

        % ---- Adam 更新 ----
        [net, avgGrad, avgSqGrad] = adamupdate(net, grads, avgGrad, avgSqGrad, ...
            iteration, lr);

        epochLoss = epochLoss + double(gather(extractdata(loss)));
        epochData = epochData + lossParts(1);
        epochRmax = epochRmax + lossParts(2);
        epochSmax = epochSmax + lossParts(3);
        epochCnt = epochCnt + 1;
    end
    trainLossHistory(epoch) = epochLoss / max(epochCnt, 1);
    dataLossHistory(epoch)  = epochData / max(epochCnt, 1);
    rmaxLossHistory(epoch)  = epochRmax / max(epochCnt, 1);
    smaxLossHistory(epoch)  = epochSmax / max(epochCnt, 1);

    % ---- 【新增】Rmax / Smax 监控（在监控集上以物理/栅格量纲评估） ----
    if isfield(cfg, 'featMonitor') && cfg.featMonitor && ~isempty(monSamples)
        [rmaxErrHistory(epoch), smaxErrHistory(epoch)] = ...
            evalFeatureErrors(net, monSamples, useGPU, cfg);
    end

    % ---- 验证集评估 + 早停 ----
    if ~isempty(valSamples)
        valLossHistory(epoch) = evalMaskedLoss(net, valSamples, useGPU, cfg);
        if valLossHistory(epoch) < bestValLoss - 1e-7
            bestValLoss = valLossHistory(epoch);
            bestNet = net;                  % dlnetwork 为值类，直接保存副本
            bestEpoch = epoch;
            patienceCnt = 0;
        else
            patienceCnt = patienceCnt + 1;
        end
        if patienceCnt >= cfg.patience
            fprintf('  早停触发：验证损失已连续 %d 轮未改善（最优 epoch = %d）。\n', ...
                cfg.patience, bestEpoch);
            trainLossHistory = trainLossHistory(1:epoch);
            valLossHistory   = valLossHistory(1:epoch);
            dataLossHistory  = dataLossHistory(1:epoch);
            rmaxLossHistory  = rmaxLossHistory(1:epoch);
            smaxLossHistory  = smaxLossHistory(1:epoch);
            rmaxErrHistory   = rmaxErrHistory(1:epoch);
            smaxErrHistory   = smaxErrHistory(1:epoch);
            break;
        end
    else
        bestNet = net;  bestEpoch = epoch;  % 无验证集：保留最新模型
    end

    % ---- 周期性打印 ----
    if mod(epoch, cfg.printEvery) == 0 || epoch == 1
        featStr = '';
        if isfield(cfg, 'featMonitor') && cfg.featMonitor && ~isnan(rmaxErrHistory(epoch))
            featStr = sprintf(' | RmaxErr = %.4f mΩ | SmaxErr = %.4f', ...
                rmaxErrHistory(epoch), smaxErrHistory(epoch));
        end
        if ~isempty(valSamples)
            fprintf('  epoch %4d / %4d | lr = %.2e | 训练损失 = %.6f | 验证损失 = %.6f%s\n', ...
                epoch, cfg.maxEpochs, lr, trainLossHistory(epoch), valLossHistory(epoch), featStr);
        else
            fprintf('  epoch %4d / %4d | lr = %.2e | 训练损失 = %.6f%s\n', ...
                epoch, cfg.maxEpochs, lr, trainLossHistory(epoch), featStr);
        end
    end
end

% 裁掉历史曲线尾部未使用的 NaN（早停时已裁剪；正常结束这里无操作）
lastT = find(~isnan(trainLossHistory), 1, 'last');
trainLossHistory = trainLossHistory(1:lastT);
valLossHistory   = valLossHistory(1:min(lastT, numel(valLossHistory)));
dataLossHistory  = dataLossHistory(1:min(lastT, numel(dataLossHistory)));
rmaxLossHistory  = rmaxLossHistory(1:min(lastT, numel(rmaxLossHistory)));
smaxLossHistory  = smaxLossHistory(1:min(lastT, numel(smaxLossHistory)));
rmaxErrHistory   = rmaxErrHistory(1:min(lastT, numel(rmaxErrHistory)));
smaxErrHistory   = smaxErrHistory(1:min(lastT, numel(smaxErrHistory)));

%% ---------------- 5. 打包模型（统一搬回 CPU，便于保存/加载） -------------
bestNet = dlupdate(@gather, bestNet);

model = struct();
model.net              = bestNet;
model.cfg              = cfg;
model.Lmin             = Lmin;
model.Lmax             = Lmax;
model.trainLossHistory = trainLossHistory;
model.valLossHistory   = valLossHistory;
model.dataLossHistory  = dataLossHistory;    % 【新增】峰区加权 MSE 分量历史
model.rmaxLossHistory  = rmaxLossHistory;    % 【新增】Rmax 软约束分量历史
model.smaxLossHistory  = smaxLossHistory;    % 【新增】Smax 软约束分量历史
model.rmaxErrHistory   = rmaxErrHistory;     % 【新增】监控集 Rmax 误差(mΩ)历史
model.smaxErrHistory   = smaxErrHistory;     % 【新增】监控集 Smax 误差历史
model.bestEpoch        = bestEpoch;
model.pairsInfo        = {pairs.desc}';
model.trainedDate      = string(datetime);

fprintf('  训练完成：最优 epoch = %d，最终训练损失 = %.6f\n', ...
    bestEpoch, trainLossHistory(end));
end

%% ========================================================================
%  以下为本文件局部函数
%% ========================================================================

function s = makeSample(pair, art, Lmin, Lmax, cfg)
% 将一个配对转换为定长训练样本（全部 single，1 x T 或 4 x T）。
g = art.grid;
T = numel(g.tGrid);

Ma = g.MGrid;                              % 人工有效掩码
Mt = pair.MtGrid;                          % 目标有效掩码

% 输入侧人工电阻：归一化 R/10；无效截断处填 1（= 10/10，物理一致）
RaN = g.RGrid / cfg.Rcut;
RaN(~Ma) = 1;

% 目标侧电阻：归一化；无效处填 0（被 Mloss 屏蔽，仅防 NaN 污染梯度）
RtN = pair.RtGrid / cfg.Rcut;
RtN(~Mt) = 0;

Lnorm = (art.length - Lmin) / (Lmax - Lmin);   % 长度归一化到 [0,1]

% ---- 【新增】首峰窗口掩码 Wpk 与峰前上升段斜率掩码 Wrise ----
% 网格 tGrid 是有效窗 [t0,t1] 的归一化坐标，需先恢复物理时间：
%   tphys(k) = t0 + tGrid(k) * (t1 - t0)
% 这样才能按 cfg.peakWindow = [13,16] s（与特征提取一致）定位首峰区。
if isfield(cfg, 'peakWindow') && numel(cfg.peakWindow) == 2
    pw = cfg.peakWindow;
else
    pw = [13, 16];
end
if isfield(g, 't0') && isfield(g, 't1') && isfinite(g.t0) && isfinite(g.t1) && g.t1 > g.t0
    tphys = g.t0 + g.tGrid * (g.t1 - g.t0);
else
    tphys = g.tGrid;   % 兜底：缺少 t0/t1 时退化为归一化坐标
end
Mlossv = (Ma & Mt);
WpkRow   = double(Mlossv) .* double(tphys >= min(pw) & tphys <= max(pw)); % 1 x T
WriseRow = double(tphys(2:end) <= max(pw));   % 1 x (T-1)：右端点不晚于峰窗末

s.X     = single([g.tGrid; RaN; double(Ma); Lnorm * ones(1, T)]);  % 4 x T
s.Ra    = single(RaN);                     % 1 x T
s.Rt    = single(RtN);                     % 1 x T
s.Min   = single(Ma);                      % 1 x T（输入有效掩码）
s.Mloss = single(Mlossv);                  % 1 x T（损失掩码：两侧同时有效）
s.Wpk   = single(WpkRow);                  % 1 x T（首峰窗口掩码，已含损失掩码）
s.Wrise = single(WriseRow);                % 1 x (T-1)（峰前上升段斜率掩码）
end

function s = augmentSample(s, cfg)
% 训练集数据增强：幅值抖动 + 有效区高斯噪声（仅作用于有效点）。
% 目的：在样本极少的情况下提高模型对幅值/噪声扰动的鲁棒性，缓解过拟合。
Min = logical(s.Min);

scl = 1 + cfg.augScaleJitter * (2*rand - 1);        % 幅值抖动 ±augScaleJitter
Ra = double(s.Ra) * scl;
Ra = Ra + cfg.augNoiseStd * randn(size(Ra)) .* double(Min);  % 仅有效区加噪
Ra = min(max(Ra, 0), 1);                            % 限幅在 [0,1]
Ra(~Min) = 1;                                       % 无效处回填 1

s.Ra = single(Ra);
s.X(2, :) = single(Ra);                             % 同步更新输入第 2 通道
end

function [X, Ra, Rt, Min, Mloss, Wpk, Wrise] = assembleBatch(batch, useGPU)
% 将样本元胞组装为 C x B x T 的 dlarray（'CBT'）。
B = numel(batch);
T = size(batch{1}.X, 2);

X     = zeros(4, B, T, 'single');
Ra    = zeros(1, B, T, 'single');
Rt    = zeros(1, B, T, 'single');
Min   = zeros(1, B, T, 'single');
Mloss = zeros(1, B, T, 'single');
Wpk   = zeros(1, B, T, 'single');
Wrise = zeros(1, B, T-1, 'single');
for b = 1:B
    X(:, b, :)     = reshape(batch{b}.X,     4, 1, T);
    Ra(:, b, :)    = reshape(batch{b}.Ra,    1, 1, T);
    Rt(:, b, :)    = reshape(batch{b}.Rt,    1, 1, T);
    Min(:, b, :)   = reshape(batch{b}.Min,   1, 1, T);
    Mloss(:, b, :) = reshape(batch{b}.Mloss, 1, 1, T);
    Wpk(:, b, :)   = reshape(batch{b}.Wpk,   1, 1, T);
    Wrise(:, b, :) = reshape(batch{b}.Wrise, 1, 1, T-1);
end

X     = dlarray(X,     'CBT');
Ra    = dlarray(Ra,    'CBT');
Rt    = dlarray(Rt,    'CBT');
Min   = dlarray(Min,   'CBT');
Mloss = dlarray(Mloss, 'CBT');
Wpk   = dlarray(Wpk,   'CBT');
Wrise = dlarray(Wrise, 'CBT');

if useGPU
    X = gpuArray(X);  Ra = gpuArray(Ra);  Rt = gpuArray(Rt);
    Min = gpuArray(Min);  Mloss = gpuArray(Mloss);
    Wpk = gpuArray(Wpk);  Wrise = gpuArray(Wrise);
end
end

function [loss, grads, lossParts] = modelLoss(net, X, Ra, Rt, Min, Mloss, Wpk, Wrise, cfg)
% 前向传播 + 掩码损失 + 梯度（在 dlfeval 中调用，支持自动微分）。
%
% 损失构成（全部在归一化量纲 R' = R/Rcut 下，仅在有效掩码点计算）：
%   L = lossData(峰区加权 masked MSE)
%     + lambdaDelta  * lossDelta   (DeltaR 幅值惩罚)
%     + lambdaSmooth * lossSmooth  (DeltaR 时间平滑惩罚)
%     + lambdaRmax   * lossRmax    (首峰 Rmax 软约束) 【新增】
%     + lambdaSmax   * lossSmax    (峰前最大上升斜率 Smax 软约束) 【新增】
Y = forward(net, X);                                   % 3 x B x T

[Rpred, ~, ~, dR] = applyCalibrationHead(Y, Ra, Min, cfg);

% ---- (1) 峰区加权 masked MSE ----
% 原始 masked MSE 的误差能量被高幅值尾部主导，首峰区(~1 mΩ)几乎不被优化。
% 这里在首峰窗口 Wpk 内额外加权 peakWeight 倍，把网络注意力拉回首峰区，
% 同时仍保持 R>=10 截断点(Mloss=0)完全不参与损失。
Wmse  = Mloss .* (1 + cfg.peakWeight * Wpk);
denomW = max(sum(Wmse, 'all'), 1);
lossData = sum(Wmse .* (Rpred - Rt).^2, 'all') / denomW;

% ---- (2) DeltaR 幅值惩罚：鼓励仿射项(alpha,beta)解释系统性偏差 ----
denom = max(sum(Mloss, 'all'), 1);
lossDelta = sum((dR .* Mloss).^2, 'all') / denom;

% ---- (3) DeltaR 时间平滑惩罚：抑制残差高频抖动（小样本防过拟合） ----
dDiff = dR(1, :, 2:end) - dR(1, :, 1:end-1);
mDiff = Mloss(1, :, 2:end) .* Mloss(1, :, 1:end-1);    % 相邻两点均有效才计入
lossSmooth = sum((dDiff .* mDiff).^2, 'all') / max(sum(mDiff, 'all'), 1);

% ---- (4)【新增】Rmax 软约束：首峰窗口内的(可微)峰值对齐 ----
% 用温度 tau 的 soft-max 近似真实 max，使 Rmax 误差可反向传播。
rmaxPred = softMaxValue(Rpred, Wpk, cfg.softmaxTau);   % 1 x B
rmaxTar  = softMaxValue(Rt,    Wpk, cfg.softmaxTau);   % 1 x B
lossRmax = mean((rmaxPred - rmaxTar).^2, 'all');

% ---- (5)【新增】Smax 软约束：峰前上升段最大正斜率对齐 ----
% 斜率在统一栅格上计算（pred 与 target 同栅格，量纲一致可直接比较）。
sPred = Rpred(1, :, 2:end) - Rpred(1, :, 1:end-1);     % 1 x B x (T-1)
sTar  = Rt(1, :, 2:end)    - Rt(1, :, 1:end-1);
mSlope = Mloss(1, :, 2:end) .* Mloss(1, :, 1:end-1) .* Wrise;  % 相邻有效且在峰前上升段
smaxPred = softMaxValue(sPred, mSlope, cfg.softmaxTau);
smaxTar  = softMaxValue(sTar,  mSlope, cfg.softmaxTau);
lossSmax = mean((smaxPred - smaxTar).^2, 'all');

loss = lossData ...
     + cfg.lambdaDelta  * lossDelta ...
     + cfg.lambdaSmooth * lossSmooth ...
     + cfg.lambdaRmax   * lossRmax ...
     + cfg.lambdaSmax   * lossSmax;

grads = dlgradient(loss, net.Learnables);

% 供训练循环监控各分量（标量）
lossParts = [double(gather(extractdata(lossData))), ...
             double(gather(extractdata(lossRmax))), ...
             double(gather(extractdata(lossSmax)))];
end

function val = softMaxValue(R, M, tau)
% softMaxValue  掩码下沿时间(第3维)的可微 soft-max 近似。
%   返回每条曲线一个标量(1 x B)，tau 越大越逼近真实 max。
%   实现：对掩码外的点减去一个大常数使其在 softmax 中权重≈0，
%   再以 softmax 权重对原始值加权求和（soft-argmax 取值）。
BIG = 1e4;
Rm    = R + (M - 1) * BIG;            % 掩码外 -> 极小，不参与取最大
shift = max(Rm, [], 3);              % 1 x B x 1，数值稳定(减最大值)
e = exp(tau * (Rm - shift)) .* M;    % 掩码外≈0，并显式乘 M 清零
w = e ./ (sum(e, 3) + eps);          % softmax 权重
val = sum(w .* R, 3);                % 1 x B：用原始 R 取加权值
val = reshape(val, 1, size(R, 2));
end

function grads = clipGradL2(grads, clipVal)
% 全局 L2 范数梯度裁剪。
sq = 0;
for i = 1:height(grads)
    g = grads.Value{i};
    if isempty(g), continue; end
    sq = sq + sum(double(gather(extractdata(g))).^2, 'all');
end
gnorm = sqrt(sq);
if gnorm > clipVal && gnorm > 0
    scale = clipVal / gnorm;
    grads = dlupdate(@(g) g .* scale, grads);
end
end

function L = evalMaskedLoss(net, samples, useGPU, cfg)
% 在验证集上评估纯数据项 masked MSE（用 predict，关闭 dropout）。
[X, Ra, Rt, Min, Mloss] = assembleBatch(samples, useGPU);
Y = predict(net, X);
Rpred = applyCalibrationHead(Y, Ra, Min, cfg);
denom = max(sum(Mloss, 'all'), 1);
L = sum(((Rpred - Rt) .* Mloss).^2, 'all') / denom;
L = double(gather(extractdata(L)));
end

function [eR, eS] = evalFeatureErrors(net, samples, useGPU, cfg)
% evalFeatureErrors  在监控集上评估校准后曲线与目标曲线的 Rmax / Smax 误差。
%   eR：首峰窗口 Rmax 平均绝对误差，已换算为物理量纲 mΩ；
%   eS：峰前最大上升斜率 Smax 平均绝对误差（归一化栅格斜率，趋势监控用）。
% 说明：此处使用与损失一致的可微 soft-max 近似，作为训练过程趋势监控；
%       最终精确特征仍由 extractDRFeatures 在物理时间轴上提取。
[X, Ra, Rt, Min, Mloss, Wpk, Wrise] = assembleBatch(samples, useGPU);
Y = predict(net, X);                                   % 关闭 dropout
Rpred = applyCalibrationHead(Y, Ra, Min, cfg);

rmaxP = softMaxValue(Rpred, Wpk, cfg.softmaxTau);
rmaxT = softMaxValue(Rt,    Wpk, cfg.softmaxTau);
eR = mean(abs(rmaxP - rmaxT), 'all') * cfg.Rcut;       % 归一化 -> mΩ

sP = Rpred(1, :, 2:end) - Rpred(1, :, 1:end-1);
sT = Rt(1, :, 2:end)    - Rt(1, :, 1:end-1);
mS = Mloss(1, :, 2:end) .* Mloss(1, :, 1:end-1) .* Wrise;
sPm = softMaxValue(sP, mS, cfg.softmaxTau);
sTm = softMaxValue(sT, mS, cfg.softmaxTau);
eS = mean(abs(sPm - sTm), 'all');

eR = double(gather(extractdata(eR)));
eS = double(gather(extractdata(eS)));
end
