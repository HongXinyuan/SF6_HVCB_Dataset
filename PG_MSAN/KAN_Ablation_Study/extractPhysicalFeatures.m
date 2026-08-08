function feat = extractPhysicalFeatures(t, r, cfg)
% extractPhysicalFeatures  从清洗后的动态电阻曲线提取 6 个本地物理特征
% -------------------------------------------------------------------------
%       .Rmax   动态电阻第一波峰局部极大值
%       .Rmean  有效动态电阻平均值
%       .Smax   第一波峰出现前(t<=tpeak)的最大变化斜率
%       .AR     动态电阻曲线积分面积 trapz(t,r)
%       .tpeak  第一波峰出现时刻 (ms)
%       .Dlow   局部低阻持续时间 (ms)
%       .vector [Rmax Rmean Smax AR tpeak Dlow] 前 6 维(Cas 在外部单独计算)

    t = double(t(:));
    r = double(r(:));

    feat = struct('Rmax', NaN, 'Rmean', NaN, 'Smax', NaN, ...
                  'AR', NaN, 'tpeak', NaN, 'Dlow', NaN, 'vector', []);

    if numel(t) < 3
        feat.vector = [0 0 0 0 0 0];
        return;
    end

    %% 1) Rmax & tpeak —— 仅在 [14,15] ms 区间内搜索第一波峰
    pw = cfg.peakWindow;
    inWin = (t >= pw(1)) & (t <= pw(2));
    if any(inWin)
        rWin = r(inWin);
        tWin = t(inWin);
        [Rmax, kk] = max(rWin);
        tpeak = tWin(kk);
    else
        % 若该时间窗内无采样点, 退化为使用最接近窗口中心的点(容错)
        [~, kc] = min(abs(t - mean(pw)));
        Rmax  = r(kc);
        tpeak = t(kc);
    end
    feat.Rmax  = Rmax;
    feat.tpeak = tpeak;

    %% 2) Rmean —— 有效动态电阻平均值(仅清洗后有效值)
    feat.Rmean = mean(r);

    %% 3) Smax —— 第一波峰出现前(t<=tpeak)的最大变化斜率
    preMask = (t <= tpeak);
    if sum(preMask) >= 2
        tp = t(preMask); rp = r(preMask);
        dt = diff(tp);
        dr = diff(rp);
        dt(dt == 0) = eps;
        slope = dr ./ dt;
        feat.Smax = max(slope);
    else
        feat.Smax = 0;
    end

    %% 4) AR —— 曲线积分面积
    feat.AR = trapz(t, r);

    %% 5) Dlow —— 局部低阻持续时间
    %   物理含义: tpeak 之后电阻急速下降进入低阻区, 一段时间后又急剧上升(直至超过10被截断)。
    %   Dlow 即"下降进入低阻"到"重新回升"之间的短暂时间区域时长。
    feat.Dlow = computeDlow(t, r, Rmax, tpeak, cfg);

    %% 组装前 6 维特征向量(Cas 由 computeCosineSimilarityFeature 在外部补全)
    feat.vector = [feat.Rmax, feat.Rmean, feat.Smax, feat.AR, feat.tpeak, feat.Dlow];
    feat.vector(~isfinite(feat.vector)) = 0;   % 兜底, 避免 NaN 进入模型
end

% ===================== 局部函数: Dlow 计算 =====================
function Dlow = computeDlow(t, r, Rmax, tpeak, cfg)
% 在 tpeak 之后寻找低阻谷区的持续时间。
% 思路:
%   - 进入低阻: tpeak 之后电阻首次下降到 dropRatio*Rmax 以下的时刻 t_enter
%   - 离开低阻: t_enter 之后电阻首次回升到 riseRatio*Rmax 以上的时刻 t_leave
%   - Dlow = t_leave - t_enter
    Dlow = 0;
    dropTh = cfg.dlowDropRatio * Rmax;
    riseTh = cfg.dlowRiseRatio * Rmax;

    afterIdx = find(t > tpeak);
    if numel(afterIdx) < 2
        return;
    end
    ta = t(afterIdx);
    ra = r(afterIdx);

    % 进入低阻区
    kEnter = find(ra <= dropTh, 1, 'first');
    if isempty(kEnter)
        return;   % 未出现明显下降谷
    end
    tEnter = ta(kEnter);

    % 离开低阻区(回升)
    kLeave = find(ra(kEnter:end) >= riseTh, 1, 'first');
    if isempty(kLeave)
        % 若未回升到阈值(可能后段已被截断剔除), 取低阻区末端
        tLeave = ta(end);
    else
        tLeave = ta(kEnter + kLeave - 1);
    end

    Dlow = max(0, tLeave - tEnter);
end
