function featureCmp = writeArtificialToRealFeatureCompare(dsReal, outDir, featureCompareFile, cfg)
% writeArtificialToRealFeatureCompare
% 自动扫描 Da~_Artificial-to-Real_Dataset 中的每一个 .dat 文件，

if ~isfolder(outDir)
    warning('人工输出目录不存在，无法生成 FeatureCompare：%s', outDir);
    featureCmp = struct([]);
    return;
end

files = dir(fullfile(outDir, '*.dat'));
if isempty(files)
    warning('人工输出目录中没有 .dat 文件，无法生成 FeatureCompare：%s', outDir);
    featureCmp = struct([]);
    return;
end

% ---- 按文件名解析长度并排序，便于结果表阅读 ----
fileLengths = nan(numel(files), 1);
for k = 1:numel(files)
    fileLengths(k) = parseLengthFromFilename(files(k).name);
end
[~, ord] = sort(fileLengths);
files = files(ord);

Lr = [dsReal.length];
if isempty(Lr)
    warning('真实数据集为空，无法生成 FeatureCompare。');
    featureCmp = struct([]);
    return;
end

featNames = {'Rmax', 'Rmean', 'Smax', 'AR', 'tpeak', 'Dlow'};
featHdrs  = {'Rmax (mΩ)', 'Rmean (mΩ)', 'Smax (mΩ/s)', ...
             'AR (mΩ·s)', 'tpeak (s)', 'Dlow (s)'};

baseHdr = {'RowName', 'ArtificialFile', 'ArtificialLength_mm', ...
           'TargetDescription', 'RealFile1', 'Weight1', ...
           'RealFile2', 'Weight2', 'TargetValidPoints'};

colHdr = baseHdr;
for k = 1:numel(featNames)
    colHdr = [colHdr, ...
        {['Target_'     featHdrs{k}], ...
         ['Artificial_' featHdrs{k}], ...
         ['AbsErr_'     featNames{k}], ...
         ['RelErrPct_'  featNames{k}]}]; %#ok<AGROW>
end

rows = cell(0, numel(colHdr));

featureCmp = struct('artificialName', {}, 'artificialLength', {}, ...
                    'realIdx', {}, 'weights', {}, 'targetDesc', {}, ...
                    'vTarget', {}, 'vArtificial', {}, ...
                    'absErr', {}, 'relErrPct', {});

VTarget = [];
VArtificial = [];
AbsErr = [];
RelErrPct = [];

for i = 1:numel(files)
    fn = files(i).name;
    fp = fullfile(outDir, fn);

    % ---- (1) 从人工输出文件名解析目标尺寸 ----
    La = parseLengthFromFilename(fn);
    if isnan(La)
        warning('无法从人工输出文件名解析尺寸，已跳过：%s', fn);
        continue;
    end

    % ---- (2) 超出真实数据范围则跳过，不做外推 ----
    if La < min(Lr) || La > max(Lr)
        warning(['人工输出文件 %s 的尺寸 %.2f mm 超出真实数据范围 %.2f ~ %.2f mm，', ...
                 '已跳过，不进行外推。'], fn, La, min(Lr), max(Lr));
        continue;
    end

    % ---- (3) 找左右相邻真实文件，并计算线性插值权重 ----
    [realIdx, weights, targetDesc, ok] = findNeighborRealForFeatureCompare(dsReal, La);
    if ~ok
        warning('人工输出文件 %s 找不到对应左右相邻真实文件，已跳过。', fn);
        continue;
    end

    % ---- (4) 读取并清洗人工输出曲线 ----
    try
        art = readCleanDatForFeatureCompare(fp, cfg);
    catch ME
        warning('读取人工输出文件失败，已跳过：%s。原因：%s', fn, ME.message);
        continue;
    end

    if art.numValid < cfg.minValidPoints
        warning('人工输出文件 %s 有效点数不足（%d），已跳过。', fn, art.numValid);
        continue;
    end

    % ---- (5) 在人工输出曲线时间轴上合成真实加权虚拟目标 ----
    [tTar, RTar, MTar] = synthesizeWeightedRealTargetForFeatureCompare( ...
        dsReal, realIdx, weights, art.t, art.validMask, cfg);

    if nnz(MTar) < cfg.minValidPoints
        warning('人工输出文件 %s 对应的真实虚拟目标有效点数不足（%d），已跳过。', fn, nnz(MTar));
        continue;
    end

    % ---- (6) 复用已有特征提取函数 ----
    % 说明：
    %   Rmean / Smax / AR / tpeak / Dlow 仍然基于真实加权合成虚拟目标曲线 RTar 计算。
    %   但 Target_Rmax 的底层逻辑需要特殊处理：
    %       Target_Rmax = w1 * Rmax(real1) + w2 * Rmax(real2)
    %   而不是对合成后的 RTar 再取一次 Rmax。
    fTarget = extractDRFeatures(tTar, RTar, MTar, cfg);
    fArt    = extractDRFeatures(art.t, art.R, art.validMask, cfg);

    % 覆盖 Target_Rmax：由左右真实曲线各自 Rmax 加权平均得到。
    % 每条真实曲线自身的 Rmax 仍由 extractDRFeatures 计算，
    % 因此仍严格遵循 cfg.RmaxWindow = [13, 16] 的底层定义。
    fTarget.Rmax = weightedTargetRmaxForFeatureCompare(dsReal, realIdx, weights, cfg);

    vTarget = featureVectorForFeatureCompare(fTarget, featNames);
    vArt    = featureVectorForFeatureCompare(fArt,    featNames);

    absErr = abs(vArt - vTarget);
    relErrPct = 100 * absErr ./ abs(vTarget);
    relErrPct(~isfinite(relErrPct)) = NaN;

    % ---- (7) 生成机器可读的左右真实文件信息 ----
    realFile1 = dsReal(realIdx(1)).name;
    weight1   = weights(1);

    if numel(realIdx) >= 2
        realFile2 = dsReal(realIdx(2)).name;
        weight2   = weights(2);
    else
        realFile2 = '';
        weight2   = NaN;
    end

    rowName = sprintf('Artificial_%s', fn);

    row = {rowName, fn, La, targetDesc, ...
           realFile1, weight1, realFile2, weight2, nnz(MTar)};

    for k = 1:numel(featNames)
        row = [row, {vTarget(k), vArt(k), absErr(k), relErrPct(k)}]; %#ok<AGROW>
    end

    rows(end+1, :) = row; %#ok<AGROW>

    VTarget(end+1, :)     = vTarget;    %#ok<AGROW>
    VArtificial(end+1, :) = vArt;       %#ok<AGROW>
    AbsErr(end+1, :)      = absErr;     %#ok<AGROW>
    RelErrPct(end+1, :)   = relErrPct;  %#ok<AGROW>

    n = numel(featureCmp) + 1;
    featureCmp(n).artificialName   = fn;
    featureCmp(n).artificialLength = La;
    featureCmp(n).realIdx          = realIdx;
    featureCmp(n).weights          = weights;
    featureCmp(n).targetDesc       = targetDesc;
    featureCmp(n).vTarget          = vTarget;
    featureCmp(n).vArtificial      = vArt;
    featureCmp(n).absErr           = absErr;
    featureCmp(n).relErrPct        = relErrPct;

    fprintf('  [%2d/%2d] 人工 %-14s (%.2f mm)  <-  %s\n', ...
        i, numel(files), fn, La, targetDesc);
end

% ---- (8) 如果没有任何有效行，也写出表头，避免主流程中断 ----
if isempty(rows)
    warning('没有生成任何有效 FeatureCompare 行，仅写出表头。');
    C = colHdr;
else
    % ---- (9) Average 行：统计平均目标值、平均人工值、平均绝对误差、平均相对误差百分比 ----
    avgTarget     = mean(VTarget,     1, 'omitnan');
    avgArtificial = mean(VArtificial, 1, 'omitnan');
    avgAbsErr     = mean(AbsErr,      1, 'omitnan');
    avgRelErrPct  = mean(RelErrPct,   1, 'omitnan');

    avgRow = {'Average', '', NaN, sprintf('有效人工输出文件数 = %d', size(rows, 1)), ...
              '', NaN, '', NaN, NaN};

    for k = 1:numel(featNames)
        avgRow = [avgRow, ...
            {avgTarget(k), avgArtificial(k), avgAbsErr(k), avgRelErrPct(k)}]; %#ok<AGROW>
    end

    C = [colHdr; rows; avgRow];
end

% ---- (10) 写出 Excel 文件，sheet 名为 FeatureCompare ----
if isfile(featureCompareFile)
    delete(featureCompareFile);
end

writecell(C, featureCompareFile, 'Sheet', 'FeatureCompare');

fprintf('  FeatureCompare 已生成：%s\n', featureCompareFile);

if ~isempty(rows)
    fprintf('  平均误差摘要：\n');
    avgAbsErr    = mean(AbsErr,    1, 'omitnan');
    avgRelErrPct = mean(RelErrPct, 1, 'omitnan');

    for k = 1:numel(featNames)
        fprintf('    %-6s : 平均绝对误差 = %.6g，平均相对误差 = %.3f%%\n', ...
            featNames{k}, avgAbsErr(k), avgRelErrPct(k));
    end
end
end

%% ========================================================================
function [realIdx, weights, targetDesc, ok] = findNeighborRealForFeatureCompare(dsReal, La)
% 根据人工目标尺寸 La 找到左右相邻真实文件，并计算线性插值权重。
% 若 La 恰好等于某条真实曲线长度，则直接使用该真实曲线，权重为 1。

ok = false;
realIdx = [];
weights = [];
targetDesc = '';

Lr = [dsReal.length];
tol = 1e-9;

% 尺寸精确命中真实文件
[dmin, exactIdx] = min(abs(Lr - La));
if dmin <= tol
    realIdx = exactIdx;
    weights = 1;
    targetDesc = sprintf('真实 %s (权重 1.0000)，真实目标', dsReal(exactIdx).name);
    ok = true;
    return;
end

% 查找左邻与右邻
jLeft = find(Lr < La, 1, 'last');
jRight = find(Lr > La, 1, 'first');

if isempty(jLeft) || isempty(jRight)
    return;
end

L1 = Lr(jLeft);
L2 = Lr(jRight);

if ~(L1 < La && La < L2)
    return;
end

w2 = (La - L1) / (L2 - L1);
w1 = 1 - w2;

realIdx = [jLeft, jRight];
weights = [w1, w2];

targetDesc = sprintf('真实 %s (权重 %.4f) + %s (权重 %.4f)，加权合成虚拟目标', ...
    dsReal(jLeft).name, w1, dsReal(jRight).name, w2);

ok = true;
end

%% ========================================================================
function rec = readCleanDatForFeatureCompare(fp, cfg)
% 读取一个 .dat 文件，并复用 cleanDRData 进行清洗。

try
    M = readmatrix(fp, 'FileType', 'text');
catch
    M = load(fp);
end

if isempty(M) || size(M, 2) < 2
    error('文件为空或列数不足 2。');
end

c = cleanDRData(M(:, 1), M(:, 2), cfg);

rec.t = c.t;
rec.R = c.R;
rec.validMask = c.validMask;
rec.numValid = c.numValid;
end

%% ========================================================================
function [tTar, RTar, MTar] = synthesizeWeightedRealTargetForFeatureCompare( ...
    dsReal, realIdx, weights, tRef, validRef, cfg)
% 在人工输出曲线的时间轴 tRef 上，合成真实加权虚拟目标。
%
% 处理思想与 buildNearestPairs 保持一致：
%   1. 每条真实曲线先按自身有效时间窗归一化到 [0, 1]；
%   2. 人工输出曲线也按自身有效时间窗归一化到 [0, 1]；
%   3. 在同一归一化时间坐标下，对左右真实曲线做线性加权；
%   4. 最终将虚拟目标放回人工输出曲线的物理时间轴 tRef 上，
%      这样 Rmax/tpeak 的 [13,16] s 判定可以与人工输出曲线一致。

tRef = tRef(:);
validRef = logical(validRef(:));

tTar = tRef;
RTar = cfg.Rcut * ones(size(tRef));
MTar = false(size(tRef));

tv = tRef(validRef);
if numel(tv) < 2
    return;
end

t0Ref = tv(1);
t1Ref = tv(end);
if ~(t1Ref > t0Ref)
    return;
end

tn = (tRef - t0Ref) / max(t1Ref - t0Ref, eps);
tn = min(max(tn, 0), 1);

Racc = zeros(size(tRef));
Wsum = zeros(size(tRef));

for q = 1:numel(realIdx)
    idxReal = realIdx(q);
    rec = dsReal(idxReal);

    % 优先使用 main.m 中已经写入的 rec.grid.t0 / rec.grid.t1；
    % 若未来单独调用该函数，也提供兜底。
    if isfield(rec, 'grid') && isfield(rec.grid, 't0') && isfield(rec.grid, 't1') ...
            && isfinite(rec.grid.t0) && isfinite(rec.grid.t1) && rec.grid.t1 > rec.grid.t0
        t0Real = rec.grid.t0;
        t1Real = rec.grid.t1;
    else
        tvReal = rec.t(rec.validMask);
        if numel(tvReal) < 2
            continue;
        end
        t0Real = tvReal(1);
        t1Real = tvReal(end);
    end

    tq = t0Real + tn * (t1Real - t0Real);

    [Rq, Mq] = interpValidSegments(rec.t, rec.R, rec.validMask, tq);
    Rq = Rq(:);
    Mq = logical(Mq(:));

    Racc(Mq) = Racc(Mq) + weights(q) * Rq(Mq);
    Wsum(Mq) = Wsum(Mq) + weights(q);
end

% 仅在人工输出曲线本身有效的时间范围内比较，避免末端 R=10 截断段参与目标特征。
MTar = validRef & (Wsum > 0);
RTar(MTar) = Racc(MTar) ./ Wsum(MTar);
end

%% ========================================================================
function v = featureVectorForFeatureCompare(F, featNames)
% 将特征结构体按固定顺序展开为行向量。

v = nan(1, numel(featNames));

for k = 1:numel(featNames)
    if isfield(F, featNames{k})
        v(k) = F.(featNames{k});
    end
end
end
%% ========================================================================
function RmaxTarget = weightedTargetRmaxForFeatureCompare(dsReal, realIdx, weights, cfg)
% weightedTargetRmaxForFeatureCompare
% 计算真实加权虚拟目标的 Target_Rmax。
%
% 关键定义：
%   Target_Rmax 不是先合成真实虚拟目标曲线 RTar 后再取 Rmax，
%   而是先分别计算左右真实曲线各自的 Rmax，然后按插值权重加权平均：
%
%       Target_Rmax = w1 * Rmax(real1) + w2 * Rmax(real2)
%
% 其中每条真实曲线自身的 Rmax 仍然复用 extractDRFeatures，
% 因此仍然遵循 cfg.RmaxWindow = [13, 16] 的底层定义。

RmaxTarget = NaN;

if isempty(realIdx) || isempty(weights)
    warning('weightedTargetRmaxForFeatureCompare: realIdx 或 weights 为空，Target_Rmax 返回 NaN。');
    return;
end

realIdx = realIdx(:).';
weights = weights(:).';

if numel(realIdx) ~= numel(weights)
    warning('weightedTargetRmaxForFeatureCompare: realIdx 与 weights 数量不一致，Target_Rmax 返回 NaN。');
    return;
end

RmaxEach = nan(size(realIdx));

for q = 1:numel(realIdx)
    idx = realIdx(q);

    if idx < 1 || idx > numel(dsReal)
        warning('weightedTargetRmaxForFeatureCompare: 真实曲线索引越界：%d，Target_Rmax 返回 NaN。', idx);
        return;
    end

    rec = dsReal(idx);

    Fq = extractDRFeatures(rec.t, rec.R, rec.validMask, cfg);
    RmaxEach(q) = Fq.Rmax;
end

if any(~isfinite(RmaxEach))
    warning('weightedTargetRmaxForFeatureCompare: 左右真实曲线存在无效 Rmax，Target_Rmax 返回 NaN。');
    return;
end

if any(~isfinite(weights)) || sum(weights) <= 0
    warning('weightedTargetRmaxForFeatureCompare: 权重无效，Target_Rmax 返回 NaN。');
    return;
end

% 防止浮点误差导致权重和不是严格 1。
weights = weights / sum(weights);

RmaxTarget = sum(weights .* RmaxEach);
end
