function pairs = buildNearestPairs(dsArt, dsReal, cfg)
% buildNearestPairs  按触头长度构造 "人工曲线 -> 虚拟真实目标曲线" 的配对

Lr = [dsReal.length];                       % 真实长度（升序）
numA = numel(dsArt);

pairs = repmat(struct('aIdx', [], 'La', [], 'realIdx', [], 'weights', [], ...
                      'RtGrid', [], 'MtGrid', [], 'desc', ''), numA, 1);

for i = 1:numA
    La = dsArt(i).length;

    % ---- (1) 确定参与合成的真实曲线及其权重 ----
    if La <= Lr(1)
        realIdx = 1;            weights = 1;          % 低于范围：最近邻
    elseif La >= Lr(end)
        realIdx = numel(Lr);    weights = 1;          % 高于范围：最近邻
    else
        j = find(Lr <= La, 1, 'last');                % Lr(j) <= La < Lr(j+1)
        if Lr(j) == La
            realIdx = j;        weights = 1;          % 长度恰好相等
        else
            w2 = (La - Lr(j)) / (Lr(j+1) - Lr(j));    % 线性插值权重
            realIdx = [j, j+1];
            weights = [1 - w2, w2];
        end
    end

    % ---- (2) 在统一网格上按权重合成"虚拟真实目标曲线" ----
    % 注意：各真实曲线的网格均为其自身有效时间窗的归一化 [0,1]，
    % 即按"归一化时间对齐"进行加权（动态电阻曲线的形态在归一化时间
    % 轴上具有可比性）。无效网格点（R>=10 截断区）不参与累加。
    N = cfg.N;
    Racc = zeros(1, N);                     % 加权电阻累加器
    Wsum = zeros(1, N);                     % 有效权重累加器
    for q = 1:numel(realIdx)
        g = dsReal(realIdx(q)).grid;
        m = g.MGrid;
        Racc(m) = Racc(m) + weights(q) * g.RGrid(m);
        Wsum(m) = Wsum(m) + weights(q);
    end
    MtGrid = Wsum > 0;                      % 至少有一条有效真实曲线覆盖
    RtGrid = nan(1, N);
    RtGrid(MtGrid) = Racc(MtGrid) ./ Wsum(MtGrid);   % 按有效权重归一化

    % ---- (3) 生成配对描述字符串 ----
    if numel(realIdx) == 1
        desc = sprintf('人工 %-14s (%.2f mm)  <-  真实 %s (最近邻，权重 1.00)', ...
            dsArt(i).name, La, dsReal(realIdx).name);
    else
        desc = sprintf(['人工 %-14s (%.2f mm)  <-  真实 %s (权重 %.2f) + ', ...
            '%s (权重 %.2f)，加权合成虚拟目标'], ...
            dsArt(i).name, La, dsReal(realIdx(1)).name, weights(1), ...
            dsReal(realIdx(2)).name, weights(2));
    end

    pairs(i).aIdx    = i;
    pairs(i).La      = La;
    pairs(i).realIdx = realIdx;
    pairs(i).weights = weights;
    pairs(i).RtGrid  = RtGrid;
    pairs(i).MtGrid  = MtGrid;
    pairs(i).desc    = desc;
end
end
