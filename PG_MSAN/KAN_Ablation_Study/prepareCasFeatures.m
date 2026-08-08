function data = prepareCasFeatures(data, split, cfg)
% prepareCasFeatures  仅使用训练集 Dr 构建 Cas 模板并统一计算全部样本 Cas
% -------------------------------------------------------------------------

    refTemplates = struct('meanCurve', [], 'isReal', false, 'nTrainReal', 0);

    trI = split.trainIdx(:);
    realTrainIdx = trI(data.domain(trI));
    if ~isempty(realTrainIdx)
        refTemplates.meanCurve = mean(data.curves(realTrainIdx, :), 1);
        refTemplates.isReal = true;
        refTemplates.nTrainReal = numel(realTrainIdx);
    end

    N = size(data.curves, 1);
    Cas = zeros(N, 1);
    for i = 1:N
        Cas(i) = computeCosineSimilarityFeature(data.curves(i, :), refTemplates, cfg);
    end

    data.features(:, 7) = Cas;
    data.refTemplates = refTemplates;

    if refTemplates.isReal
        fprintf('[prepareCasFeatures] Cas 模板仅由训练集 Dr 构建 (n=%d)\n', ...
            refTemplates.nTrainReal);
    else
        fprintf('[prepareCasFeatures] 训练集中无 Dr, Cas 使用默认值 %.3f\n', ...
            cfg.casDefault);
    end
end
