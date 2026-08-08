function lengthMM = parseLengthFromFilename(fileName)
% parseLengthFromFilename  从文件名中解析触头长度标签 (单位 mm)
% -------------------------------------------------------------------------
% 输入:
%   fileName : 字符串或 char，例如 '278mm.dat' 或 '281.39mm.dat'
%              也可以是包含完整路径的文件名
% 输出:
%   lengthMM : double 标量，解析出的触头长度 (mm)；解析失败返回 NaN
% -------------------------------------------------------------------------
% 解析规则:
%   匹配文件名中形如  <数字>mm  的模式，支持整数与小数:
%       278mm.dat     -> 278
%       281.39mm.dat  -> 281.39
%   仅取第一个匹配到的数值作为标签。
% -------------------------------------------------------------------------
    lengthMM = NaN;
    if isempty(fileName)
        return;
    end
    % 只取文件名部分（去掉路径）
    [~, name, ext] = fileparts(char(fileName));
    fname = [name ext];

    % 正则: 一个或多个数字, 可选小数点与小数部分, 紧跟 mm (大小写不敏感)
    tok = regexpi(fname, '([0-9]+\.?[0-9]*)\s*mm', 'tokens', 'once');
    if ~isempty(tok)
        lengthMM = str2double(tok{1});
    else
        % 退化情况: 文件名中只有一串数字
        tok2 = regexp(fname, '([0-9]+\.?[0-9]*)', 'tokens', 'once');
        if ~isempty(tok2)
            lengthMM = str2double(tok2{1});
        end
    end
end
