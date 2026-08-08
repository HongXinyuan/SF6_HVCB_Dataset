function ds = loadDRDataset(folder, cfg)
% loadDRDataset  读取文件夹内所有 .dat 动态电阻数据并完成清洗

if ~isfolder(folder)
    error('数据文件夹不存在：%s', folder);
end

files = dir(fullfile(folder, '*.dat'));
if isempty(files)
    error('文件夹中没有任何 .dat 文件：%s', folder);
end

ds = struct('name', {}, 'file', {}, 'length', {}, 't', {}, 'R', {}, ...
            'validMask', {}, 'numValid', {});

for k = 1:numel(files)
    fn = files(k).name;
    fp = fullfile(folder, fn);

    % ---- (1) 从文件名解析触头长度 ----
    L = parseLengthFromFilename(fn);
    if isnan(L)
        warning('无法从文件名解析触头长度，已跳过：%s', fn);
        continue;
    end

    % ---- (2) 读取两列数据（时间 s，动态电阻 mΩ） ----
    M = [];
    try
        M = readmatrix(fp, 'FileType', 'text');
    catch
        try
            M = load(fp);  % 兜底：纯数值 ASCII 文件
        catch
            warning('文件读取失败，已跳过：%s', fp);
            continue;
        end
    end
    if isempty(M)
        warning('文件为空，已跳过：%s', fp);
        continue;
    end
    if size(M, 2) < 2
        warning('文件列数不足 2（需要 [时间, 电阻]），已跳过：%s', fp);
        continue;
    end

    % ---- (3) 数据清洗：剔除 NaN/Inf、时间排序去重、生成 R<10 有效掩码 ----
    c = cleanDRData(M(:, 1), M(:, 2), cfg);
    if c.numValid < cfg.minValidPoints
        warning('文件有效点数(%d)少于阈值(%d)，已跳过：%s', ...
            c.numValid, cfg.minValidPoints, fn);
        continue;
    end

    ds(end+1) = struct('name', fn, 'file', fp, 'length', L, ...
        't', c.t, 'R', c.R, 'validMask', c.validMask, ...
        'numValid', c.numValid); %#ok<AGROW>
end

if isempty(ds)
    error('文件夹 %s 中没有任何可用数据文件。', folder);
end

% ---- (4) 按触头长度升序排序，便于后续最近邻配对 ----
[~, ord] = sort([ds.length]);
ds = ds(ord);

fprintf('  目录 %s\n', folder);
fprintf('  共找到 %d 个 .dat 文件，成功载入 %d 条曲线，长度范围 %.2f ~ %.2f mm\n', ...
    numel(files), numel(ds), min([ds.length]), max([ds.length]));
end
