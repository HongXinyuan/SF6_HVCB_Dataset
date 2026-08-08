function writeAllModifyExcel(dsArt, calResults, allModifyFile, cfg)
% writeAllModifyExcel  生成校准结果总表 AllModify.xlsx

numC = numel(calResults);

% ---- (1) 公共时间网格：覆盖所有曲线的时间范围 ----
tAllMin = inf;  tAllMax = -inf;
for i = 1:numC
    tAllMin = min(tAllMin, min(calResults(i).t));
    tAllMax = max(tAllMax, max(calResults(i).t));
end
tCommon = linspace(tAllMin, tAllMax, cfg.NExcel)';     % 列向量

% ---- (2) 逐曲线安全插值；默认值即截断值 10 ----
Rmat = cfg.Rcut * ones(cfg.NExcel, numC);
for i = 1:numC
    cal = calResults(i);
    [Rq, Mq] = interpValidSegments(cal.t, cal.R, cal.validMask, tCommon);
    Rmat(Mq, i) = min(Rq(Mq), cfg.Rcut);               % 有效处写入（限幅 10）
end

% ---- (3) 表头：Time + 各文件基名（如 '278mm'） ----
hdr = cell(1, numC + 1);
hdr{1} = 'Time';
for i = 1:numC
    [~, base, ~] = fileparts(dsArt(i).name);
    hdr{i + 1} = base;
end

% ---- (4) 写出 Excel ----
if isfile(allModifyFile)
    delete(allModifyFile);                             % 避免旧表残留多余区域
end
writecell([hdr; num2cell([tCommon, Rmat])], allModifyFile);

fprintf('  AllModify.xlsx 已生成：%d 行（公共时间网格） x %d 列（Time + %d 条曲线）。\n', ...
    cfg.NExcel, numC + 1, numC);
end
