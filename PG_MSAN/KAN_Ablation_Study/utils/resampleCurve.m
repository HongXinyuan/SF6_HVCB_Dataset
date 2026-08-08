function [tNew, rNew] = resampleCurve(t, r, L, timeWindow)
% resampleCurve  将不等长动态电阻曲线重采样到固定长度 L
% -------------------------------------------------------------------------
% 输入:
%   t          : 时间向量 (ms)，已清洗、已按时间升序
%   r          : 动态电阻向量 (mOhm)，与 t 等长
%   L          : 重采样后的目标点数 (例如 256)
%   timeWindow : (可选) [tmin tmax] 重采样时间窗；为空则使用 [min(t) max(t)]
% 输出:
%   tNew : 1xL 均匀时间轴
%   rNew : 1xL 重采样后的电阻序列
% -------------------------------------------------------------------------
% 说明:
%   使用线性插值 interp1 将曲线统一到固定长度，便于送入卷积编码器。
%   若提供 timeWindow，则所有曲线在同一绝对时间窗上对齐(适合峰值时刻一致的情形)。
% -------------------------------------------------------------------------
    t = double(t(:));
    r = double(r(:));

    % 去除重复时间点(插值要求自变量严格单调)
    [t, ia] = unique(t, 'stable');
    r = r(ia);
    [t, idx] = sort(t);
    r = r(idx);

    if numel(t) < 2
        % 数据点不足，直接复制
        tNew = linspace(0, 1, L);
        rNew = repmat(mean(r), 1, L);
        if isempty(r); rNew = zeros(1, L); end
        return;
    end

    if nargin < 4 || isempty(timeWindow)
        tmin = t(1); tmax = t(end);
    else
        tmin = timeWindow(1); tmax = timeWindow(2);
    end
    if tmax <= tmin
        tmax = tmin + 1;
    end

    tNew = linspace(tmin, tmax, L);
    % 线性插值，窗外用最近端点外推，避免 NaN
    rNew = interp1(t, r, tNew, 'linear', 'extrap');
    rNew = rNew(:).';     % 行向量
end
