function [data, info] = loadAllDatasets(cfg)
% loadAllDatasets  遍历指定数据集文件夹, 读取/清洗/特征提取, 组装统一数据结构
% -------------------------------------------------------------------------

    L = cfg.curveLength;
    samples = struct('curveVec',{},'feat6',{},'label',{},'source',{},'file',{});

    nOK = 0; nFail = 0; failList = {};

    fprintf('\n========== [loadAllDatasets] 开始读取数据集 ==========\n');
    fprintf('数据根目录: %s\n', cfg.dataRoot);

    %% ---- 第一遍: 读取所有曲线 + 清洗 + 提取前 6 个物理特征 ----
    for d = 1:numel(cfg.useDatasets)
        folderName = cfg.useDatasets{d};
        folderPath = fullfile(cfg.dataRoot, folderName);

        if ~isfolder(folderPath)
            warning('数据集文件夹不存在, 已跳过: %s', folderPath);
            continue;
        end

        datFiles = dir(fullfile(folderPath, '*.dat'));
        fprintf('  [%s] 发现 %d 个 .dat 文件\n', folderName, numel(datFiles));

        for k = 1:numel(datFiles)
            fpath = fullfile(datFiles(k).folder, datFiles(k).name);

            % 解析长度标签
            lab = parseLengthFromFilename(datFiles(k).name);
            if ~isfinite(lab)
                nFail = nFail + 1; failList{end+1} = [fpath ' (标签解析失败)']; %#ok<AGROW>
                continue;
            end

            % 读取原始数据(鲁棒, 不抛异常)
            [t, r, ok, ~] = loadSingleDatFile(fpath);
            if ~ok
                nFail = nFail + 1; failList{end+1} = [fpath ' (读取失败)']; %#ok<AGROW>
                continue;
            end

            % 清洗 + 重采样 + 归一化
            pc = preprocessCurve(t, r, cfg);
            if ~pc.ok
                nFail = nFail + 1; failList{end+1} = [fpath ' (清洗无效:' pc.msg ')']; %#ok<AGROW>
                continue;
            end

            % 提取前 6 个物理特征(基于清洗后有效数据)
            phf = extractPhysicalFeatures(pc.t, pc.r, cfg);

            s = struct();
            s.curveVec = pc.curveVec;     % 1xL
            s.feat6    = phf.vector;      % 1x6
            s.label    = lab;
            s.source   = folderName;
            s.file     = fpath;
            samples(end+1) = s; %#ok<AGROW>
            nOK = nOK + 1;
        end
    end

    if isempty(samples)
        error('loadAllDatasets:empty', '未读取到任何有效样本, 请检查 cfg.dataRoot 与数据集文件夹。');
    end

    %% ---- 第二遍: 组装矩阵(Cas 在数据划分后统一计算) ----
    N = numel(samples);
    curves   = zeros(N, L);
    features = zeros(N, cfg.numPhysicalFeatures);
    labels   = zeros(N, 1);
    source   = cell(N, 1);
    files    = cell(N, 1);
    domain   = false(N, 1);

    for i = 1:N
        s = samples(i);
        curves(i, :)   = s.curveVec;
        features(i, :) = [s.feat6, cfg.casDefault];
        labels(i)      = s.label;
        source{i}      = s.source;
        files{i}       = s.file;
        domain(i)      = any(strcmpi(s.source, cfg.realDomainFolders));
    end

    data = struct();
    data.curves    = curves;
    data.features  = features;
    data.labels    = labels;
    data.source    = source;
    data.domain    = domain;
    data.files     = files;
    data.featNames = cfg.physicalFeatureNames;
    data.refTemplates = struct('meanCurve', [], 'isReal', false, 'nTrainReal', 0);
                                    % 数据划分后填充, 供单条预测复用 Cas 计算

    info = struct('nOK', nOK, 'nFail', nFail, 'failList', {failList});

    fprintf('---- 读取完成: 成功 %d 条, 失败/跳过 %d 条 ----\n', nOK, nFail);
    if ~isempty(failList)
        fprintf('   (失败文件已记录于 info.failList)\n');
    end
    fprintf('=====================================================\n');
end
