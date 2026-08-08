function cmp = writeFeatureCompareTables(dsReal, dsArt, calResults, featTableDir, cfg)
% writeFeatureCompareTables  为每个真实烧蚀数据文件生成一张特征对比表

if ~isfolder(featTableDir)
    mkdir(featTableDir);
end

La = [dsArt.length];
featNames = {'Rmax', 'Rmean', 'Smax', 'AR', 'tpeak', 'Dlow'};
colHdr = {'数据类型', 'Rmax (mΩ)', 'Rmean (mΩ)', 'Smax (mΩ/s)', ...
          'AR (mΩ·s)', 'tpeak (s)', 'Dlow (s)'};

numR = numel(dsReal);
cmp = repmat(struct(), numR, 1);

for r = 1:numR
    rec = dsReal(r);

    % ---- (1) 最近邻人工文件 ----
    [~, aIdx] = min(abs(La - rec.length));
    art = dsArt(aIdx);
    cal = calResults(aIdx);

    % ---- (2) 三组特征（只在有效区间计算） ----
    fReal = extractDRFeatures(rec.t, rec.R, rec.validMask, cfg);
    fArt  = extractDRFeatures(art.t, art.R, art.validMask, cfg);
    fCal  = extractDRFeatures(cal.t, cal.R, cal.validMask, cfg);

    vReal = featVec(fReal, featNames);
    vArt  = featVec(fArt,  featNames);
    vCal  = featVec(fCal,  featNames);

    % ---- (3) 相对误差（除零/NaN 置 NaN，由平均阶段 omitnan 处理） ----
    err1 = (vArt - vReal) ./ vReal;
    err2 = (vCal - vReal) ./ vReal;
    err1(~isfinite(err1)) = NaN;
    err2(~isfinite(err2)) = NaN;

    % ---- (4) Cas（校准前/后人工曲线 vs 真实曲线；不入误差表） ----
    simBefore = computeCurveSimilarity(art.t, art.R, art.validMask, ...
                                       rec.t, rec.R, rec.validMask, cfg);
    simAfter  = computeCurveSimilarity(cal.t, cal.R, cal.validMask, ...
                                       rec.t, rec.R, rec.validMask, cfg);

    % ---- (5) 写出该真实文件的特征对比表 ----
    rows = {
        '真实烧蚀数据',     vReal
        '原始人工数据',     vArt
        '误差1',            err1
        '校准后人工数据',   vCal
        '误差2',            err2
        };
    C = colHdr;
    for k = 1:size(rows, 1)
        C = [C; [rows(k, 1), num2cell(rows{k, 2})]]; %#ok<AGROW>
    end
    [~, base, ~] = fileparts(rec.name);
    tblFile = fullfile(featTableDir, ['FeatureCompare_' base '.xlsx']);
    if isfile(tblFile), delete(tblFile); end
    writecell(C, tblFile);

    fprintf('  [%2d/%2d] 真实 %-14s <-> 人工 %-14s  (Cas: %.4f -> %.4f)\n', ...
        r, numR, rec.name, art.name, simBefore.Cas, simAfter.Cas);

    % ---- (6) 汇总返回 ----
    cmp(r).realName   = rec.name;
    cmp(r).realLength = rec.length;
    cmp(r).rIdx       = r;
    cmp(r).artName    = art.name;
    cmp(r).artLength  = art.length;
    cmp(r).aIdx       = aIdx;
    cmp(r).vReal      = vReal;
    cmp(r).vArt       = vArt;
    cmp(r).vCal       = vCal;
    cmp(r).err1       = err1;
    cmp(r).err2       = err2;
    cmp(r).CasBefore  = simBefore.Cas;
    cmp(r).CasAfter   = simAfter.Cas;
    cmp(r).simBefore  = simBefore;
    cmp(r).simAfter   = simAfter;
end

fprintf('  已生成 %d 张特征对比表（= 真实数据文件数），目录：%s\n', ...
    numR, featTableDir);
end

%% ------------------------------------------------------------------------
function v = featVec(F, featNames)
% 将特征结构体按固定顺序展开为行向量 [Rmax Rmean Smax AR tpeak Dlow]。
v = nan(1, numel(featNames));
for k = 1:numel(featNames)
    v(k) = F.(featNames{k});
end
end
