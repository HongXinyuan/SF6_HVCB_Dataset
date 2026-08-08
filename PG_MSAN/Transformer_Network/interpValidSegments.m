function [Rq, Mq] = interpValidSegments(t, R, validMask, tq)
% interpValidSegments  仅在"有效连续段"内部进行线性插值（核心安全插值函数）

origSize = size(tq);
tq = tq(:)';                       % 统一为行向量计算
t = t(:);  R = R(:);

Rq = nan(1, numel(tq));
Mq = false(1, numel(tq));

runs = findValidRuns(validMask);
for r = 1:size(runs, 1)
    i1 = runs(r, 1);  i2 = runs(r, 2);
    if i2 <= i1
        continue;                  % 单点段无法插值，跳过（避免伪造数据）
    end
    inSeg = tq >= t(i1) & tq <= t(i2);   % 仅段内查询点
    if any(inSeg)
        Rq(inSeg) = interp1(t(i1:i2), R(i1:i2), tq(inSeg), 'linear');
        Mq(inSeg) = true;
    end
end

Rq = reshape(Rq, origSize);
Mq = reshape(Mq, origSize);
end
