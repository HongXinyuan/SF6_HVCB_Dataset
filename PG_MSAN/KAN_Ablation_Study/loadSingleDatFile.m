function [t, r, ok, msg] = loadSingleDatFile(datFilePath)
% loadSingleDatFile  读取单个 .dat 动态电阻文件 (鲁棒读取, 不抛异常)
% -------------------------------------------------------------------------

    t = []; r = []; ok = false; msg = '';

    if ~isfile(datFilePath)
        msg = sprintf('文件不存在: %s', datFilePath);
        return;
    end

    raw = [];
    % --- 尝试 1: readmatrix (自动识别分隔符) ---
    try
        opts = detectImportOptions(datFilePath, 'FileType', 'text');
        raw = readmatrix(datFilePath, opts);
    catch
        raw = [];
    end

    % --- 尝试 2: 直接 readmatrix ---
    if isempty(raw) || size(raw,2) < 2
        try
            raw = readmatrix(datFilePath);
        catch
            raw = [];
        end
    end

    % --- 尝试 3: 手动逐行解析 ---
    if isempty(raw) || size(raw,2) < 2
        try
            txt = fileread(datFilePath);
            txt = strrep(txt, ',', ' ');
            lines = regexp(txt, '\r\n|\r|\n', 'split');
            buf = [];
            for i = 1:numel(lines)
                ln = strtrim(lines{i});
                if isempty(ln); continue; end
                nums = sscanf(ln, '%f');
                if numel(nums) >= 2
                    buf(end+1, 1:2) = nums(1:2)'; %#ok<AGROW>
                end
            end
            raw = buf;
        catch
            raw = [];
        end
    end

    if isempty(raw) || size(raw,2) < 2 || size(raw,1) < 2
        msg = sprintf('无法解析有效两列数据: %s', datFilePath);
        return;
    end

    t = raw(:,1);
    r = raw(:,2);
    ok = true;
    msg = sprintf('成功读取 %d 行', size(raw,1));
end
