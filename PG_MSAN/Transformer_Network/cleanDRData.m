function out = cleanDRData(t, R, cfg)
% cleanDRData  动态电阻数据清洗（本项目最核心的数据预处理函数）

t = t(:);  R = R(:);

% ---- (1) 剔除非有限值（NaN/Inf）行，保证后续数值运算安全 ----
fin = isfinite(t) & isfinite(R);
t = t(fin);  R = R(fin);

% ---- (2) 保证时间单调递增：先排序，再去除重复时间戳（保留首次出现） ----
[t, ord] = sort(t);
R = R(ord);
[t, iu] = unique(t, 'stable');   % sort 后 'stable' 即升序去重
R = R(iu);

% ---- (3) 生成有效掩码：严格执行 "R >= Rcut(=10) 即无效" ----
validMask = R < cfg.Rcut;

% ---- (4) 可选平滑：只在有效"连续段"内部做滑动平均 ----
% 注意：绝不能把无效截断点（R>=10）卷入平滑窗口，否则会污染有效数据；
% 因此逐个有效连续段独立平滑。平滑后电阻可能轻微越过阈值，需重判掩码。
if isfield(cfg, 'cleanSmooth') && cfg.cleanSmooth
    runs = findValidRuns(validMask);
    for r = 1:size(runs, 1)
        idx = runs(r, 1):runs(r, 2);
        if numel(idx) >= 3
            R(idx) = movmean(R(idx), cfg.cleanSmoothWindow);
        end
    end
    validMask = R < cfg.Rcut;   % 平滑后重新判定有效性
end

% ---- (5) 打包输出 ----
out.t         = t;
out.R         = R;
out.validMask = validMask;
out.tValid    = t(validMask);
out.RValid    = R(validMask);
out.numValid  = nnz(validMask);
end
