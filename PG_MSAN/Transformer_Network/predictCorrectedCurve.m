function res = predictCorrectedCurve(model, rec, cfg)
% predictCorrectedCurve  对一条人工曲线进行校准，显式按公式输出：
%
%       R_a_tilde(t) = alpha * R_a(t) + beta + DeltaR_a(t)


g = rec.grid;
T = numel(g.tGrid);

% ---- (1) 构造与训练完全一致的 4 通道输入 ----
RaN = g.RGrid / cfg.Rcut;
RaN(~g.MGrid) = 1;                                     % 无效处填 1（与训练一致）
Lnorm = (rec.length - model.Lmin) / (model.Lmax - model.Lmin);
Lnorm = min(max(Lnorm, 0), 1);                         % 超范围裁剪到 [0,1]

X = single([g.tGrid; RaN; double(g.MGrid); Lnorm * ones(1, T)]);   % 4 x T
X = dlarray(reshape(X, 4, 1, T), 'CBT');               % C x B(=1) x T

Ra  = dlarray(reshape(single(RaN), 1, 1, T), 'CBT');
Min = dlarray(reshape(single(g.MGrid), 1, 1, T), 'CBT');

% ---- (2) 推理（predict：关闭 dropout）并解码校准头 ----
Y = predict(model.net, X);
[~, alphaN, betaN, dRN] = applyCalibrationHead(Y, Ra, Min, cfg);

alpha  = double(gather(extractdata(alphaN)));          % 无量纲缩放因子
beta   = double(gather(extractdata(betaN))) * cfg.Rcut;        % 恢复 mΩ
dRgrid = reshape(double(gather(extractdata(dRN))), 1, T) * cfg.Rcut;  % mΩ

% ---- (3) 将网格上的 DeltaR 插值回人工曲线"原始有效时间点" ----
% 网格时间是有效窗 [t0, t1] 的归一化坐标，故先把原始有效时间归一化。
tv = rec.t(rec.validMask);
Rv = rec.R(rec.validMask);
tn = (tv - g.t0) / max(g.t1 - g.t0, eps);
tn = min(max(tn, 0), 1);
dRo = interp1(g.tGrid, dRgrid, tn, 'linear');
dRo = fillmissing(dRo, 'nearest');                     % 边界安全兜底

% ---- (4) 在原始时间点上按校准公式合成，并执行物理约束 ----
Rcal = alpha * Rv + beta + dRo(:);
Rcal = max(Rcal, 0);                                   % 电阻非负
Rcal(Rcal >= cfg.Rcut) = cfg.Rcut;                     % 达到截断水平统一写 10

% ---- (5) 组装完整输出序列：无效截断点统一保留 10 ----
Rout = cfg.Rcut * ones(size(rec.R));
Rout(rec.validMask) = Rcal;

res.t         = rec.t;
res.R         = Rout;
res.validMask = Rout < cfg.Rcut;
res.alpha     = alpha;
res.beta      = beta;
res.dRgrid    = dRgrid;
res.tGrid     = g.tGrid;
res.name      = rec.name;
res.length    = rec.length;
end
