function [tGrid, RGrid, MGrid, info] = resampleDRCurve(t, R, validMask, N)
% resampleDRCurve  将一条动态电阻曲线重采样到统一长度的归一化时间网格

tGrid = linspace(0, 1, N);         % 行向量
RGrid = nan(1, N);
MGrid = false(1, N);
info = struct('t0', NaN, 't1', NaN, 'valid', false);

tv = t(validMask);
if numel(tv) < 2
    return;                        % 有效点不足，无法重采样
end
t0 = tv(1);  t1 = tv(end);
if ~(t1 > t0)
    return;                        % 有效时间跨度为 0，无法重采样
end

tq = t0 + tGrid * (t1 - t0);       % 网格对应的物理时间
[RGrid, MGrid] = interpValidSegments(t, R, validMask, tq);

info.t0 = t0;
info.t1 = t1;
info.valid = nnz(MGrid) >= 2;
end
