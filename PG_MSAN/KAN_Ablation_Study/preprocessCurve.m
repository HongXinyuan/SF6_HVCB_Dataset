function out = preprocessCurve(t, r, cfg)
% preprocessCurve  动态电阻曲线数据清洗 + 重采样 + 归一化
% -------------------------------------------------------------------------

    out = struct('ok', false, 'msg', '', 't', [], 'r', [], ...
                 'curveVec', [], 'tResampled', [], 'rResampled', []);

    if isempty(t) || isempty(r)
        out.msg = '空数据'; return;
    end
    t = double(t(:));
    r = double(r(:));
    if numel(t) ~= numel(r)
        n = min(numel(t), numel(r));
        t = t(1:n); r = r(1:n);
    end

    % --- 1) 删除 NaN / Inf ---
    validMask = isfinite(t) & isfinite(r);

    % --- 2) ★ 删除 R >= 截断阈值 的无效截断值 ★ ---
    %      (R 趋于无穷的采样截断, 无物理意义)
    validMask = validMask & (r < cfg.truncationThreshold);

    % --- 3) 删除明显非物理的负电阻 ---
    validMask = validMask & (r >= 0);

    t = t(validMask);
    r = r(validMask);

    if numel(t) < 5
        out.msg = sprintf('有效点过少(%d)', numel(t)); return;
    end

    % --- 4) 时间排序 + 去除重复时间点 ---
    [t, idx] = sort(t);
    r = r(idx);
    [t, ia] = unique(t, 'stable');
    r = r(ia);

    out.t = t;
    out.r = r;

    % --- 5) 重采样到固定长度 ---
    [tRe, rRe] = resampleCurve(t, r, cfg.curveLength, cfg.commonTimeWindow);
    out.tResampled = tRe;
    out.rResampled = rRe;

    % --- 6) 归一化(供曲线编码器使用) ---
    if strcmpi(cfg.curveNormMethod, 'fixedscale')
        % 使用物理固定上限统一缩放, 避免逐曲线 Min-Max 抹去绝对幅值差异
        curveNorm = rRe / cfg.truncationThreshold;
        curveNorm = max(0, min(1, curveNorm));
    else
        curveNorm = normalizeCurve(rRe, cfg.curveNormMethod);
    end
    out.curveVec = curveNorm(:).';   % 1 x L 行向量

    out.ok  = true;
    out.msg = sprintf('清洗后有效点 %d', numel(t));
end
