function writeMeanFeatureTable(cmp, meanTableFile, cfg) %#ok<INUSD>
% writeMeanFeatureTable  生成平均特征总表 FeatureCompare_AllMean.xlsx

% ---- (1) 堆叠所有文件的特征/误差并取均值（忽略 NaN） ----
VR = vertcat(cmp.vReal);          % numReal x 6
VA = vertcat(cmp.vArt);
VC = vertcat(cmp.vCal);
E1 = vertcat(cmp.err1);
E2 = vertcat(cmp.err2);

mVR = mean(VR, 1, 'omitnan');
mVA = mean(VA, 1, 'omitnan');
mVC = mean(VC, 1, 'omitnan');
mE1 = mean(E1, 1, 'omitnan');
mE2 = mean(E2, 1, 'omitnan');

% ---- (2) 误差改善率：基于平均绝对误差 ----
mAbsE1 = mean(abs(E1), 1, 'omitnan');
mAbsE2 = mean(abs(E2), 1, 'omitnan');
imp = (mAbsE1 - mAbsE2) ./ mAbsE1;
imp(~isfinite(imp)) = NaN;

% ---- (3) 平均 Cas（校准前/后） ----
meanCasBefore = mean([cmp.CasBefore], 'omitnan');
meanCasAfter  = mean([cmp.CasAfter],  'omitnan');

% ---- (4) 组装并写出总表 ----
colHdr = {'数据类型', 'Rmax (mΩ)', 'Rmean (mΩ)', 'Smax (mΩ/s)', ...
          'AR (mΩ·s)', 'tpeak (s)', 'Dlow (s)', 'Cas'};
C = colHdr;
C = [C; [{'真实烧蚀数据平均特征'},   num2cell([mVR, NaN])]];
C = [C; [{'原始人工数据平均特征'},   num2cell([mVA, meanCasBefore])]];
C = [C; [{'平均误差1'},              num2cell([mE1, NaN])]];
C = [C; [{'校准后人工数据平均特征'}, num2cell([mVC, meanCasAfter])]];
C = [C; [{'平均误差2'},              num2cell([mE2, NaN])]];
C = [C; [{'误差改善率Improvement'},  num2cell([imp, NaN])]];

if isfile(meanTableFile), delete(meanTableFile); end
writecell(C, meanTableFile);

% ---- (5) 命令行摘要 ----
featNames = {'Rmax', 'Rmean', 'Smax', 'AR', 'tpeak', 'Dlow'};
fprintf('  平均特征总表已生成：%s\n', meanTableFile);
fprintf('  整体校准效果摘要（误差改善率 > 0 表示校准有效）：\n');
for k = 1:numel(featNames)
    fprintf('    %-6s : 平均|误差| %.4f -> %.4f，改善率 %+.2f%%\n', ...
        featNames{k}, mAbsE1(k), mAbsE2(k), 100 * imp(k));
end
fprintf('    %-6s : %.4f -> %.4f（曲线匹配度，越接近 1 越好）\n', ...
    'Cas', meanCasBefore, meanCasAfter);
end
