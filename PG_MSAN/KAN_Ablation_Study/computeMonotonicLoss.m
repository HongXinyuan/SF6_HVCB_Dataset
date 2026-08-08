function Lmono = computeMonotonicLoss(predLen, degrFeat, margin)
% computeMonotonicLoss  物理单调约束损失(pairwise ranking / hinge)

    predLen  = stripdims(predLen(:)).';     % 1 x B
    degrFeat = degrFeat(:).';               % 1 x B (普通数值, 不需梯度)
    B = numel(predLen);
    if B < 2
        Lmono = dlarray(single(0));
        return;
    end

    % 构造成对差(广播)
    pi = reshape(predLen, [B, 1]);          % B x 1
    pj = reshape(predLen, [1, B]);          % 1 x B
    diffPred = pi - pj;                     % B x B : predLen_i - predLen_j

    di = reshape(degrFeat, [B, 1]);
    dj = reshape(degrFeat, [1, B]);
    mask = single(di > dj);                 % B x B : degr_i > degr_j 的对

    nPairs = sum(mask(:));
    if nPairs < 1
        Lmono = dlarray(single(0));
        return;
    end

    hinge = relu(margin + diffPred);        % B x B
    Lmono = sum(sum(hinge .* mask)) / nPairs;
end
