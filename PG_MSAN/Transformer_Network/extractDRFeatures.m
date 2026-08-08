function F = extractDRFeatures(t, R, validMask, cfg)
% extractDRFeatures  提取动态电阻曲线特征量（全部只在有效区间内计算）

F = struct('Rmax', NaN, 'Rmean', NaN, 'Smax', NaN, ...
           'AR', NaN, 'tpeak', NaN, 'Dlow', NaN);

t = t(:);
R = R(:);
v = logical(validMask(:));

if ~isfield(cfg, 'RmaxWindow') || numel(cfg.RmaxWindow) ~= 2
    cfg.RmaxWindow = [13, 16];
end

if nnz(v) < 5
    warning('有效点过少（%d），特征提取返回 NaN。', nnz(v));
    return;
end

% ---- (0) 仅在有效连续段内平滑得到 Rs（用于斜率，Rmax 不使用平滑值） ----
Rs = R;
runs = findValidRuns(v);
for r = 1:size(runs, 1)
    idx = runs(r, 1):runs(r, 2);
    if numel(idx) >= 3
        Rs(idx) = movmean(R(idx), cfg.smoothWindow);
    end
end

% ---- (1) Rmean：有效点平均 ----
F.Rmean = mean(R(v));

% ---- (2) AR：逐有效段梯形积分累加，绝不跨越无效截断段积分 ----
AR = 0;
for r = 1:size(runs, 1)
    idx = runs(r, 1):runs(r, 2);
    if numel(idx) >= 2
        AR = AR + trapz(t(idx), R(idx));
    end
end
F.AR = AR;

% ---- (3) Rmax / tpeak：严格在 [13, 16] s 内取有效点最大值 ----
tw = cfg.RmaxWindow(:).';
t1 = min(tw);
t2 = max(tw);

peakCand = find(v & t >= t1 & t <= t2);

if isempty(peakCand)
    warning('Rmax 时间窗 [%.3f, %.3f] s 内没有有效点，Rmax/tpeak/Smax/Dlow 返回 NaN。', t1, t2);
    return;
end

[~, loc] = max(R(peakCand));     % 使用原始 R，不使用平滑后的 Rs
peakIdx = peakCand(loc);

F.Rmax  = R(peakIdx);
F.tpeak = t(peakIdx);

% ---- (4) Smax：tpeak 之前、峰所在有效段内的最大上升斜率 ----
segRow = find(runs(:, 1) <= peakIdx & runs(:, 2) >= peakIdx, 1);
if ~isempty(segRow)
    i1 = runs(segRow, 1);
    if peakIdx > i1
        idx = i1:peakIdx;
        dt = diff(t(idx));
        dR = diff(Rs(idx));
        good = dt > 0;
        if any(good)
            slope = dR(good) ./ dt(good);
            F.Smax = max(slope);
        end
    end
end

% ---- (5) Dlow：第一波峰后、末端电阻骤升截断之前的低阻段持续时间 ----
lowMask = v & (R < cfg.DlowThreshold);
lowMask(1:peakIdx) = false;

lowRuns = findValidRuns(lowMask);
if ~isempty(lowRuns)
    i1 = lowRuns(end, 1);
    i2 = lowRuns(end, 2);
    F.Dlow = t(i2) - t(i1);
end
end
