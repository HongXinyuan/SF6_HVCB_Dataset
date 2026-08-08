function Cas = computeCosineSimilarityFeature(curveVec, refTemplates, cfg)
% computeCosineSimilarityFeature  计算第 7 个物理特征 Cas (曲线余弦相似度)

    if ~isfield(cfg, 'casDefault'); cfg.casDefault = 0.5; end

    % 与固定的训练集 Dr 模板比较
    if isempty(refTemplates) || ~isfield(refTemplates,'isReal') || ~refTemplates.isReal
        Cas = cfg.casDefault;   % 无真实模板可比 -> 默认值
        return;
    end

    curveVec = curveVec(:).';   % 1xL

    ref = refTemplates.meanCurve;

    Cas = cosineSim(curveVec, ref);

    % 数值兜底
    if ~isfinite(Cas)
        Cas = cfg.casDefault;
    end
    % 形状相似度裁剪到 [0,1] (负相似度无物理意义)
    Cas = max(0, min(1, Cas));
end

% ===================== 局部函数: 余弦相似度 =====================
function s = cosineSim(a, b)
    a = a(:); b = b(:);
    n = min(numel(a), numel(b));
    a = a(1:n); b = b(1:n);
    na = norm(a); nb = norm(b);
    if na < eps || nb < eps
        s = 0;
    else
        s = (a.' * b) / (na * nb);
    end
end
