function [metrics, predTable, yPredAll] = evaluateRegression(model, data, idx, cfg, setName)
% evaluateRegression  在给定样本子集上评估回归性能并输出逐样本结果

    if nargin < 5; setName = ''; end

    metrics = emptyMetrics();
    predTable = table();
    yPredAll = [];
    if isempty(idx)
        return;
    end

    %% ---- 前向推理(批量) ----
    yPredAll = runInference(model, data, idx, cfg);    % mm
    yTrue    = data.labels(idx);

    absErr = abs(yPredAll - yTrue);
    relErr = absErr ./ max(abs(yTrue), eps) * 100;     % %

    %% ---- 指标 ----
    metrics.MAE   = mean(absErr);
    metrics.RMSE  = sqrt(mean((yPredAll - yTrue).^2));
    metrics.MaxAE = max(absErr);
    metrics.MeanRelError = mean(relErr);               % 平均相对误差(%)
    ssRes = sum((yTrue - yPredAll).^2);
    ssTot = sum((yTrue - mean(yTrue)).^2);
    if ssTot < eps
        metrics.R2 = NaN;
    else
        metrics.R2 = 1 - ssRes / ssTot;
    end

    %% ---- 逐样本表 ----
    src = data.source(idx);
    files = data.files(idx);
    predTable = table(string(src(:)), string(files(:)), yTrue(:), yPredAll(:), ...
        absErr(:), relErr(:), ...
        'VariableNames', {'Source','FilePath','TrueLength_mm','PredLength_mm','AbsError_mm','RelError_pct'});

    if cfg.verbose
        fprintf('[评估-%s] MAE=%.4f  RMSE=%.4f  R2=%.4f  MaxAE=%.4f  MeanRel=%.2f%%  (n=%d)\n', ...
            setName, metrics.MAE, metrics.RMSE, metrics.R2, metrics.MaxAE, metrics.MeanRelError, numel(idx));
    end
end

% ===================== 局部函数: 批量推理 =====================
function yPred = runInference(model, data, idx, cfg)
    curves = data.curves(idx, :);
    n = size(curves, 1); L = size(curves, 2);
    Xc = dlarray(single(reshape(curves.', [L, 1, n])));

    if model.fixed.usePhysicalFeatures
        Fm = (data.features(idx, :) - model.fixed.featMu) ./ model.fixed.featSigma;
        Xf = dlarray(single(Fm.'));
    else
        Xf = [];
    end

    predStd = kanModelForward(model, Xc, Xf);          % 1 x n 标准化空间
    predStd = double(gather(extractdata(predStd)));
    yPred = predStd(:) * model.fixed.yStd + model.fixed.yMean;   % 反标准化 -> mm
end

function m = emptyMetrics()
    m = struct('MAE',NaN,'RMSE',NaN,'R2',NaN,'MaxAE',NaN,'MeanRelError',NaN);
end
