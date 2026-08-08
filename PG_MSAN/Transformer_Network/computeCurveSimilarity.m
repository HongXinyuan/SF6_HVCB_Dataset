function sim = computeCurveSimilarity(t1, R1, m1, t2, R2, m2, cfg)
% computeCurveSimilarity  计算两条动态电阻曲线之间的匹配度指标

sim = struct('Cas', NaN, 'RMSE', NaN, 'MAE', NaN, 'Corr', NaN, ...
             'R2', NaN, 'MAPE', NaN, 'MaxAE', NaN, 'NRMSE', NaN, ...
             'DTW', NaN, 'Frechet', NaN, 'numPoints', 0);

% ---- (1) 各自重采样到相同长度的归一化网格 ----
[~, Ra, Ma, infoA] = resampleDRCurve(t1(:), R1(:), logical(m1(:)), cfg.N);
[~, Rb, Mb, infoB] = resampleDRCurve(t2(:), R2(:), logical(m2(:)), cfg.N);
if ~infoA.valid || ~infoB.valid
    return;
end

% ---- (2) 公共有效掩码：两条曲线在该网格点均有效才参与比较 ----
m = Ma & Mb;
sim.numPoints = nnz(m);
if sim.numPoints < 5
    return;                          % 公共有效点过少，结果不可信
end

a = Ra(m);  b = Rb(m);

% 约定：b 为真实(参考)曲线，a 为待评估曲线(校准前=原始人工 / 校准后=校准结果)。
% R2 / MAPE / NRMSE 均以 b 为基准计算。
a = a(:);  b = b(:);

% ---- (3) 各项指标 ----
sim.Cas  = sum(a .* b) / max(norm(a) * norm(b), eps);   % 余弦相似度
sim.RMSE = sqrt(mean((a - b).^2));
sim.MAE  = mean(abs(a - b));
C = corrcoef(a, b);
if numel(C) >= 4
    sim.Corr = C(1, 2);
end

% ---- (3b) 新增指标：R2 / MAPE / MaxAE / NRMSE / DTW / Frechet ----
resid = a - b;

% R2（决定系数）：1 - SS_res / SS_tot，以真实曲线 b 为基准。
ssRes = sum(resid.^2);
ssTot = sum((b - mean(b)).^2);
if ssTot > eps
    sim.R2 = 1 - ssRes / ssTot;
end

% MaxAE（最大绝对误差，mΩ）：暴露最坏点，关键过渡点失配在此体现。
sim.MaxAE = max(abs(resid));

% MAPE（平均绝对百分比误差，%）：仅对 |b| 足够大的点计入，避免被近零电阻放大。
denom = abs(b);
okP = denom > 1e-6;
if any(okP)
    sim.MAPE = 100 * mean(abs(resid(okP) ./ denom(okP)));
end

% NRMSE（归一化 RMSE）：RMSE 除以真实曲线幅值跨度，便于跨曲线/跨量级横向比较。
rngB = max(b) - min(b);
if rngB > eps
    sim.NRMSE = sim.RMSE / rngB;
end

% DTW（动态时间规整距离，mΩ）：允许时间轴非线性对齐后比较形态，
%   对动作时刻/采样触发的轻微错位鲁棒（自实现，不依赖 Signal Processing Toolbox）。
sim.DTW = localDTW(a, b);

% Frechet（离散 Fréchet 距离，mΩ）：对曲线整体走向相似性的严格刻画。
sim.Frechet = localFrechet(a, b);
end

%% ------------------------------------------------------------------------
function d = localDTW(a, b)
% 一维序列动态时间规整距离（基础 DP 实现，代价为绝对差）。
n = numel(a);  m = numel(b);
D = inf(n + 1, m + 1);
D(1, 1) = 0;
for i = 1:n
    ai = a(i);
    for j = 1:m
        cost = abs(ai - b(j));
        D(i + 1, j + 1) = cost + min([D(i, j + 1), D(i + 1, j), D(i, j)]);
    end
end
d = D(n + 1, m + 1);
end

%% ------------------------------------------------------------------------
function d = localFrechet(a, b)
% 一维序列离散 Fréchet 距离（耦合距离的迭代 DP 实现）。
n = numel(a);  m = numel(b);
ca = -ones(n, m);
ca(1, 1) = abs(a(1) - b(1));
for i = 2:n
    ca(i, 1) = max(ca(i - 1, 1), abs(a(i) - b(1)));
end
for j = 2:m
    ca(1, j) = max(ca(1, j - 1), abs(a(1) - b(j)));
end
for i = 2:n
    for j = 2:m
        ca(i, j) = max(min([ca(i - 1, j), ca(i - 1, j - 1), ca(i, j - 1)]), ...
                       abs(a(i) - b(j)));
    end
end
d = ca(n, m);
end
