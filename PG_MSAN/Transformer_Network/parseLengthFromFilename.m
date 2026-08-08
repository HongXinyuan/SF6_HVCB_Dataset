function L = parseLengthFromFilename(fn)
% parseLengthFromFilename  从 .dat 文件名中解析触头长度（mm）

tok = regexp(fn, '(\d+(\.\d+)?)\s*mm', 'tokens', 'once');
if isempty(tok)
    L = NaN;   % 文件名不符合 "xxxmm" 命名规范，由调用方决定跳过/警告
else
    L = str2double(tok{1});
end
end
