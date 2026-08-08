function [model, history] = trainKANModel(model, data, split, cfg)
% trainKANModel  自定义训练循环(支持 Lreg / Full 损失, Adam 优化, 早停)
% -------------------------------------------------------------------------
% 损失:
%   cfg.lossType = "Lreg" : L = Lreg
%   cfg.lossType = "Full" : L = Lreg + lambdaAlign*Lalign + lambdaMono*Lmono
% -------------------------------------------------------------------------

    setRandomSeed(cfg.randomSeed);

    %% ---- 1) 取训练统计量, 标准化标签与物理特征 ----
    trI = split.trainIdx;
    yTr = data.labels(trI);
    model.fixed.yMean = mean(yTr);
    model.fixed.yStd  = std(yTr) + eps;

    fMu    = mean(data.features(trI, :), 1);
    fSigma = std(data.features(trI, :), 0, 1) + eps;
    model.fixed.featMu    = fMu;
    model.fixed.featSigma = fSigma;

    % 标准化函数
    stdY = @(y) (y - model.fixed.yMean) / model.fixed.yStd;
    stdF = @(F) (F - fMu) ./ fSigma;

    %% ---- 2) 准备各子集张量 ----
    [XcTr, XfTr, YTr, domTr, degrTr] = packBatch(data, trI, cfg, stdF, stdY);
    [XcVa, XfVa, YVa, ~, ~]          = packBatch(data, split.valIdx, cfg, stdF, stdY);

    nTrain = numel(trI);
    useFull = (cfg.lossType == "Full");

    %% ---- 3) Adam 状态 ----
    avgG = []; avgSqG = []; iter = 0;
    lr   = cfg.initialLR;

    bestValLoss = inf; bestLearn = model.learn; patienceCnt = 0;
    history.trainLoss = nan(cfg.maxEpochs, 1);
    history.valLoss   = nan(cfg.maxEpochs, 1);

    fprintf('\n========== [trainKANModel] 开始训练 (%s, loss=%s) ==========\n', ...
        cfg.experimentName, cfg.lossType);

    for epoch = 1:cfg.maxEpochs
        % 学习率阶梯衰减
        if mod(epoch, cfg.lrDropPeriod) == 0
            lr = lr * cfg.lrDropFactor;
        end

        % 打乱训练样本
        perm = randperm(nTrain);
        epochLoss = 0; nBatch = 0;

        for s = 1:cfg.miniBatchSize:nTrain
            e = min(s + cfg.miniBatchSize - 1, nTrain);
            bidx = perm(s:e);

            Xcb = XcTr(:, :, bidx);
            if ~isempty(XfTr); Xfb = XfTr(:, bidx); else; Xfb = []; end
            if ~isempty(Xfb) && cfg.physModalityDropout > 0
                keepMask = dlarray(single(rand(1, numel(bidx)) >= ...
                    cfg.physModalityDropout));
                Xfb = Xfb .* keepMask;
            end
            Yb   = YTr(:, bidx);
            domB = domTr(bidx);
            degB = degrTr(bidx);

            iter = iter + 1;
            [loss, grads] = dlfeval(@modelLoss, model, Xcb, Xfb, Yb, domB, degB, cfg, useFull);

            % L2 权重正则(对所有可学习参数)
            grads = addL2(grads, model.learn, cfg.l2Reg);

            [model.learn, avgG, avgSqG] = adamupdate(model.learn, grads, ...
                avgG, avgSqG, iter, lr);

            epochLoss = epochLoss + double(gather(extractdata(loss)));
            nBatch = nBatch + 1;
        end
        history.trainLoss(epoch) = epochLoss / max(nBatch, 1);

        %% ---- 验证 ----
        if ~isempty(YVa)
            valLoss = dlfeval(@evalLossOnly, model, XcVa, XfVa, YVa, cfg);
            history.valLoss(epoch) = double(gather(extractdata(valLoss)));
        else
            history.valLoss(epoch) = history.trainLoss(epoch);
        end

        if cfg.verbose && (mod(epoch,5)==0 || epoch==1)
            fprintf('  Epoch %3d/%3d | lr=%.2e | trainLoss=%.5f | valLoss=%.5f\n', ...
                epoch, cfg.maxEpochs, lr, history.trainLoss(epoch), history.valLoss(epoch));
        end

        %% ---- 早停 ----
        if history.valLoss(epoch) < bestValLoss - 1e-6
            bestValLoss = history.valLoss(epoch);
            bestLearn   = model.learn;
            patienceCnt = 0;
        else
            patienceCnt = patienceCnt + 1;
            if patienceCnt >= cfg.validationPatience
                fprintf('  早停触发于 epoch %d (验证损失 %.5f)\n', epoch, bestValLoss);
                break;
            end
        end
    end

    % 采用验证最优权重
    model.learn = bestLearn;
    fprintf('---- 训练结束, 最优验证损失 = %.5f ----\n', bestValLoss);
    fprintf('================================================================\n');
end

% =====================================================================
% 局部函数: 单 batch 损失 + 梯度(用于 dlfeval)
% =====================================================================
function [loss, grads] = modelLoss(model, Xc, Xf, Y, domain, degr, cfg, useFull)
    [pred, aux] = kanModelForward(model, Xc, Xf);    % 1 x B 标准化预测

    % ---- 基础回归损失 Lreg ----
    if strcmpi(cfg.regLossType, 'mae')
        Lreg = mean(abs(pred - Y), 'all');
    else
        Lreg = mean((pred - Y).^2, 'all');
    end
    loss = Lreg;

    % ---- 完整损失附加项 ----
    if useFull
        % 分布对齐 Lalign: 真实域 vs 非真实域 的融合特征
        fused = aux.fused;                            % D x B
        realCols  = find(domain);
        otherCols = find(~domain);
        if ~isempty(realCols) && ~isempty(otherCols)
            Lalign = computeAlignmentLoss(fused(:, realCols), fused(:, otherCols), 'coral');
            loss = loss + cfg.lambdaAlign * Lalign;
        end

        % 物理单调约束 Lmono: 退化特征(degr) 与 预测长度 应单调递减
        Lmono = computeMonotonicLoss(pred, degr, 0);
        loss = loss + cfg.lambdaMono * Lmono;
    end

    grads = dlgradient(loss, model.learn);
end

% 局部函数: 仅计算损失(验证用, 无梯度)
function loss = evalLossOnly(model, Xc, Xf, Y, cfg)
    pred = kanModelForward(model, Xc, Xf);
    if strcmpi(cfg.regLossType, 'mae')
        loss = mean(abs(pred - Y), 'all');
    else
        loss = mean((pred - Y).^2, 'all');
    end
end

% 局部函数: 组装一个子集为 dlarray 张量
function [Xc, Xf, Y, dom, degr] = packBatch(data, idx, cfg, stdF, stdY)
    if isempty(idx)
        Xc = []; Xf = []; Y = []; dom = []; degr = []; return;
    end
    curves = data.curves(idx, :);            % n x L
    n = size(curves, 1);
    L = size(curves, 2);

    % 曲线 -> [L x 1 x n] (DataFormat SCB)
    Xc = reshape(curves.', [L, 1, n]);
    Xc = dlarray(single(Xc));

    % 物理特征
    if cfg.usePhysicalFeatures
        Fm = stdF(data.features(idx, :));    % n x F
        Xf = dlarray(single(Fm.'));          % F x n
    else
        Xf = [];
    end

    % 标准化标签
    Y = dlarray(single(stdY(data.labels(idx)).'));   % 1 x n

    dom  = data.domain(idx);
    % 退化特征: 取 Rmax(第 1 列)作为单调约束的退化指标
    degr = data.features(idx, 1).';
end

% 局部函数: 给梯度加 L2 正则项(对所有 dlarray 叶子)
function grads = addL2(grads, learn, lambda)
    if lambda <= 0; return; end
    grads = recurseL2(grads, learn, lambda);
end

function g = recurseL2(g, w, lambda)
    fn = fieldnames(g);
    for i = 1:numel(fn)
        if isstruct(g.(fn{i}))
            g.(fn{i}) = recurseL2(g.(fn{i}), w.(fn{i}), lambda);
        else
            g.(fn{i}) = g.(fn{i}) + lambda * w.(fn{i});
        end
    end
end
