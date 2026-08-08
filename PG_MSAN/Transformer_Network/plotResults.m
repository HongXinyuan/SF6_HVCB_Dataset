function plotResults(model, dsReal, dsArt, calResults, cmp, figDir, cfg)
% plotResults  绘制训练与校准效果检查图（共 4 张，自动保存 PNG）

if ~isfolder(figDir), mkdir(figDir); end

%% ---------------- 图1：训练 / 验证 loss 曲线 -----------------------------
f1 = figure('Name', '训练损失曲线', 'Color', 'w', 'Position', [80 80 760 460]);
semilogy(1:numel(model.trainLossHistory), model.trainLossHistory, ...
    'b-', 'LineWidth', 1.5); hold on;
hasVal = ~isempty(model.valLossHistory) && any(~isnan(model.valLossHistory));
if hasVal
    semilogy(1:numel(model.valLossHistory), model.valLossHistory, ...
        'r--', 'LineWidth', 1.5);
    xline(model.bestEpoch, 'k:', 'LineWidth', 1.2);
    legend({'训练损失 Train Loss', '验证损失 Val Loss', ...
            sprintf('最优 epoch = %d', model.bestEpoch)}, 'Location', 'northeast');
else
    legend({'训练损失 Train Loss'}, 'Location', 'northeast');
end
grid on;
xlabel('Epoch'); ylabel('Masked MSE Loss（对数坐标）');
title('Transformer 校准模型训练损失曲线');
saveFig(f1, fullfile(figDir, 'Fig1_TrainingLoss.png'));

%% ---------------- 图2：曲线对比（真实 / 原始人工 / 校准后） --------------
nShow = min(cfg.numPlotPairs, numel(cmp));
pick = unique(round(linspace(1, numel(cmp), nShow)));
nShow = numel(pick);
nRow = ceil(nShow / 2);  nCol = min(2, nShow);

f2 = figure('Name', '曲线校准效果对比', 'Color', 'w', ...
    'Position', [100 100 560 * nCol, 360 * nRow]);
for p = 1:nShow
    c = cmp(pick(p));
    rec = dsReal(c.rIdx);
    art = dsArt(c.aIdx);
    cal = calResults(c.aIdx);

    subplot(nRow, nCol, p); hold on; grid on;
    plot(rec.t, maskNaN(rec.R, rec.validMask), 'k-',  'LineWidth', 1.6);
    plot(art.t, maskNaN(art.R, art.validMask), 'b--', 'LineWidth', 1.2);
    plot(cal.t, maskNaN(cal.R, cal.validMask), 'r-',  'LineWidth', 1.2);
    xlabel('时间 t (s)'); ylabel('动态电阻 R (mΩ)');
    title(sprintf('真实 %s vs 人工 %s', c.realName, c.artName), ...
        'Interpreter', 'none');
    legend({'真实烧蚀曲线', '原始人工曲线', '校准后人工曲线'}, ...
        'Location', 'best');
end
sgtitle('动态电阻曲线校准前后对比（仅显示有效区间，R≥10 截断点已断开）');
saveFig(f2, fullfile(figDir, 'Fig2_CurveComparison.png'));

%% ---------------- 图3：特征平均绝对误差 校准前后对比 ---------------------
E1 = vertcat(cmp.err1);  E2 = vertcat(cmp.err2);
mAbsE1 = mean(abs(E1), 1, 'omitnan');
mAbsE2 = mean(abs(E2), 1, 'omitnan');
featNames = {'Rmax', 'Rmean', 'Smax', 'AR', 'tpeak', 'Dlow'};

f3 = figure('Name', '特征误差对比', 'Color', 'w', 'Position', [120 120 820 460]);
bar([mAbsE1(:), mAbsE2(:)]);
set(gca, 'XTickLabel', featNames);
grid on;
ylabel('平均绝对相对误差 mean(|Error|)');
legend({'校准前（误差1）', '校准后（误差2）'}, 'Location', 'northeast');
title('各特征量平均绝对误差：校准前 vs 校准后');
saveFig(f3, fullfile(figDir, 'Fig3_FeatureError.png'));

%% ---------------- 图4：Cas 校准前后对比 ----------------------------------
casB = [cmp.CasBefore];  casA = [cmp.CasAfter];
f4 = figure('Name', 'Cas 对比', 'Color', 'w', 'Position', [140 140 900 460]);
bar([casB(:), casA(:)]);
grid on;
xticks(1:numel(cmp));
xticklabels(strrep({cmp.realName}, '.dat', ''));
xtickangle(45);
ylabel('曲线匹配度 Cas（余弦相似度）');
casAll = [casB, casA];
if any(isfinite(casAll))
    ylim([min(0.9 * min(casAll(isfinite(casAll))), 0.9), 1.001]);
end
legend({'校准前 Cas', '校准后 Cas'}, 'Location', 'southeast');
title('各真实数据文件的曲线匹配度 Cas：校准前 vs 校准后');
saveFig(f4, fullfile(figDir, 'Fig4_CasCompare.png'));

fprintf('  4 张结果图已保存至：%s\n', figDir);

%% ---------------- 图5：【新增】Rmax/Smax 训练监控曲线 -------------------
% 仅当模型包含监控历史时绘制（兼容旧模型，不影响主流程）。
if isfield(model, 'rmaxErrHistory') && any(~isnan(model.rmaxErrHistory))
    f5 = figure('Name', 'Rmax/Smax 训练监控', 'Color', 'w', ...
        'Position', [160 160 900 700]);

    subplot(2, 1, 1);
    ep = 1:numel(model.rmaxErrHistory);
    plot(ep, model.rmaxErrHistory, 'b-', 'LineWidth', 1.5); hold on; grid on;
    if isfield(model, 'bestEpoch') && model.bestEpoch >= 1
        xline(model.bestEpoch, 'k:', 'LineWidth', 1.2);
    end
    xlabel('Epoch'); ylabel('Rmax 平均绝对误差 (mΩ)');
    title('训练过程中首峰 Rmax 误差(监控集，soft-max 近似)');
    legend({'RmaxErr', sprintf('最优 epoch = %d', model.bestEpoch)}, ...
        'Location', 'northeast');

    subplot(2, 1, 2);
    plot(ep, model.smaxErrHistory, 'r-', 'LineWidth', 1.5); hold on; grid on;
    if isfield(model, 'bestEpoch') && model.bestEpoch >= 1
        xline(model.bestEpoch, 'k:', 'LineWidth', 1.2);
    end
    xlabel('Epoch'); ylabel('Smax 平均绝对误差 (归一化栅格斜率)');
    title('训练过程中峰前最大上升斜率 Smax 误差(监控集，soft-max 近似)');

    saveFig(f5, fullfile(figDir, 'Fig5_RmaxSmaxMonitor.png'));
    fprintf('  Rmax/Smax 监控图已保存：%s\n', fullfile(figDir, 'Fig5_RmaxSmaxMonitor.png'));
end
end

%% ------------------------------------------------------------------------
function y = maskNaN(R, mask)
% 将无效点（R >= 10 截断点）置 NaN，使绘图曲线在无效区间自然断开。
y = R;
y(~mask) = NaN;
end

function saveFig(f, fp)
% 保存图片：优先 exportgraphics（R2020a+，150 dpi），失败回退 saveas。
try
    exportgraphics(f, fp, 'Resolution', 150);
catch
    saveas(f, fp);
end
end
