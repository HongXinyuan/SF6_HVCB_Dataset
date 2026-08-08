function visualizeResults(res, cfg)
% visualizeResults  生成并保存全部结果图(每张图独立 try/catch, 互不影响)
% -------------------------------------------------------------------------

    if ~exist(cfg.figDir, 'dir'); mkdir(cfg.figDir); end
    tag = char(cfg.experimentName);

    %% 图1: 训练/验证损失曲线
    safePlot(@() plotLossCurves(res.history, cfg, tag), '损失曲线');

    %% 图2: 真实 vs 预测散点
    safePlot(@() plotScatter(res.testTable, cfg, tag), '真实-预测散点');

    %% 图3: 误差分布直方图
    safePlot(@() plotErrorHist(res.testTable, cfg, tag), '误差直方图');

    %% 图4: 逐样本误差曲线
    safePlot(@() plotPerSampleError(res.testTable, cfg, tag), '逐样本误差');

    %% 图5: 不同数据源曲线对比
    safePlot(@() plotSourceCurves(res.data, cfg, tag), '数据源曲线对比');

    %% 图6: 典型样本 Rmax 标注
    safePlot(@() plotRmaxAnnotation(res.data, cfg, tag), 'Rmax标注');

    %% 图7: 物理特征相关性热力图
    safePlot(@() plotFeatureCorr(res.data, cfg, tag), '特征相关性热力图');

    %% 图8: 注意力权重可视化
    if cfg.usePhysicalFeatures && cfg.useAttentionFusion
        safePlot(@() plotAttention(res.model, res.data, res.split, cfg, tag), '注意力权重');
    end

    fprintf('[visualizeResults] 全部图片已保存至 %s\n', cfg.figDir);
end

% ============ 安全绘图封装 ============
function safePlot(fn, name)
    try
        fn();
    catch ME
        warning('绘图[%s]失败: %s', name, ME.message);
    end
end

% ============ 图1 ============
function plotLossCurves(history, cfg, tag)
    f = figure('Visible','off','Color','w','Position',[100 100 700 460]);
    ep = (1:numel(history.trainLoss))';
    valid = ~isnan(history.trainLoss);
    plot(ep(valid), history.trainLoss(valid), '-', 'LineWidth', 1.6); hold on;
    plot(ep(valid), history.valLoss(valid),   '--','LineWidth', 1.6);
    grid on; xlabel('Epoch'); ylabel('Loss');
    legend({'训练损失','验证损失'}, 'Location','northeast');
    title(sprintf('%s 训练/验证损失曲线', tag));
    saveFig(f, cfg, [tag '_01_loss_curves']);
end

% ============ 图2 ============
function plotScatter(T, cfg, tag)
    if isempty(T); return; end
    f = figure('Visible','off','Color','w','Position',[100 100 560 540]);
    yt = T.TrueLength_mm; yp = T.PredLength_mm;
    scatter(yt, yp, 45, 'filled'); hold on;
    lo = min([yt;yp]); hi = max([yt;yp]);
    plot([lo hi],[lo hi],'k--','LineWidth',1.3);
    grid on; axis equal;
    xlabel('真实触头长度 (mm)'); ylabel('预测触头长度 (mm)');
    title(sprintf('%s 真实 vs 预测', tag));
    saveFig(f, cfg, [tag '_02_scatter_true_pred']);
end

% ============ 图3 ============
function plotErrorHist(T, cfg, tag)
    if isempty(T); return; end
    f = figure('Visible','off','Color','w','Position',[100 100 640 440]);
    err = T.PredLength_mm - T.TrueLength_mm;
    histogram(err, max(5, round(sqrt(numel(err)))));
    grid on; xlabel('预测误差 (mm)'); ylabel('样本数');
    title(sprintf('%s 预测误差分布', tag));
    saveFig(f, cfg, [tag '_03_error_hist']);
end

% ============ 图4 ============
function plotPerSampleError(T, cfg, tag)
    if isempty(T); return; end
    f = figure('Visible','off','Color','w','Position',[100 100 760 440]);
    plot(T.AbsError_mm, '-o', 'LineWidth', 1.3, 'MarkerSize', 4);
    grid on; xlabel('测试样本序号'); ylabel('绝对误差 (mm)');
    title(sprintf('%s 测试样本逐样本误差', tag));
    saveFig(f, cfg, [tag '_04_per_sample_error']);
end

% ============ 图5 ============
function plotSourceCurves(data, cfg, tag)
    f = figure('Visible','off','Color','w','Position',[100 100 760 480]);
    srcU = unique(data.source);
    cmap = lines(numel(srcU)); hold on; lg = {};
    for s = 1:numel(srcU)
        idx = find(strcmp(data.source, srcU{s}), 1, 'first');  % 每源取一条代表曲线
        if isempty(idx); continue; end
        plot(data.curves(idx, :), 'Color', cmap(s,:), 'LineWidth', 1.5);
        lg{end+1} = srcU{s}; %#ok<AGROW>
    end
    grid on; xlabel('重采样点'); ylabel('归一化动态电阻');
    legend(lg, 'Interpreter','none', 'Location','best');
    title(sprintf('%s 不同数据源动态电阻曲线对比', tag));
    saveFig(f, cfg, [tag '_05_source_curves']);
end

% ============ 图6 ============
function plotRmaxAnnotation(data, cfg, tag)
    % 取一条样本, 重新读取原始数据以在真实时间轴上标注 [14,15] ms 的 Rmax
    if isempty(data.files); return; end
    fpath = data.files{1};
    [t, r, ok] = loadSingleDatFile(fpath);
    if ~ok; return; end
    pc = preprocessCurve(t, r, cfg);
    if ~pc.ok; return; end
    phf = extractPhysicalFeatures(pc.t, pc.r, cfg);

    f = figure('Visible','off','Color','w','Position',[100 100 780 460]);
    plot(pc.t, pc.r, '-', 'LineWidth', 1.3); hold on;
    % 标注峰值搜索窗
    yl = ylim;
    patch([cfg.peakWindow(1) cfg.peakWindow(2) cfg.peakWindow(2) cfg.peakWindow(1)], ...
          [yl(1) yl(1) yl(2) yl(2)], [0.9 0.9 0.2], 'FaceAlpha',0.18, 'EdgeColor','none');
    plot(phf.tpeak, phf.Rmax, 'rp', 'MarkerSize', 14, 'MarkerFaceColor','r');
    text(phf.tpeak, phf.Rmax, sprintf('  Rmax=%.3f @ %.3fms', phf.Rmax, phf.tpeak), 'Color','r');
    grid on; xlabel('时间 (ms)'); ylabel('动态电阻 (mOhm, 清洗后)');
    title(sprintf('%s 典型样本动态电阻 + 第一波峰 Rmax', tag));
    saveFig(f, cfg, [tag '_06_rmax_annotation']);
end

% ============ 图7 ============
function plotFeatureCorr(data, cfg, tag)
    F = data.features;
    if size(F,1) < 3; return; end
    C = corrcoef(F);
    f = figure('Visible','off','Color','w','Position',[100 100 640 560]);
    imagesc(C, [-1 1]); colorbar; colormap(parula);
    set(gca,'XTick',1:numel(data.featNames),'XTickLabel',data.featNames, ...
            'YTick',1:numel(data.featNames),'YTickLabel',data.featNames);
    xtickangle(45);
    title(sprintf('%s 物理特征相关性热力图', tag));
    % 叠加数值
    for i=1:size(C,1)
        for j=1:size(C,2)
            text(j,i,sprintf('%.2f',C(i,j)),'HorizontalAlignment','center','FontSize',8);
        end
    end
    saveFig(f, cfg, [tag '_07_feature_corr']);
end

% ============ 图8 ============
function plotAttention(model, data, split, cfg, tag)
    idx = split.testIdx;
    if isempty(idx); idx = split.trainIdx; end
    curves = data.curves(idx, :);
    n = size(curves,1); L = size(curves,2);
    Xc = dlarray(single(reshape(curves.', [L,1,n])));
    Fm = (data.features(idx,:) - model.fixed.featMu) ./ model.fixed.featSigma;
    Xf = dlarray(single(Fm.'));
    [~, aux] = kanModelForward(model, Xc, Xf);
    if isempty(aux.attW); return; end
    A = double(gather(extractdata(aux.attW)));   % 2 x n

    f = figure('Visible','off','Color','w','Position',[100 100 760 440]);
    bar(A.', 'stacked'); grid on;
    xlabel('测试样本序号'); ylabel('注意力权重');
    legend({'曲线特征权重','物理特征权重'}, 'Location','best');
    ylim([0 1]);
    title(sprintf('%s 多源注意力权重分布', tag));
    saveFig(f, cfg, [tag '_08_attention_weights']);
end

% ============ 保存工具 ============
function saveFig(f, cfg, name)
    fpath = fullfile(cfg.figDir, [name '.png']);
    try
        exportgraphics(f, fpath, 'Resolution', 150);
    catch
        saveas(f, fpath);   % 兼容旧版本
    end
    close(f);
end
