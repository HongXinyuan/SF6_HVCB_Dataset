function summaryTable = plotAblationComparison(cfg, whichSet)
% plotAblationComparison  消融实验 (M1~M8) 结果对比接口
% -------------------------------------------------------------------------

    if nargin < 2 || isempty(whichSet); whichSet = 'Test'; end
    if ~exist(cfg.figDir, 'dir'); mkdir(cfg.figDir); end

    expList = {'M1','M2','M3','M4','M5','M6','M7','M8'};

    names = {}; MAE = []; RMSE = []; R2 = []; MaxAE = []; MeanRel = [];

    %% ---- 1) 扫描各实验指标文件 ----
    for i = 1:numel(expList)
        tag = expList{i};
        fcsv = fullfile(cfg.metricDir, sprintf('metrics_%s.csv', tag));
        if ~exist(fcsv, 'file')
            continue;   % 该实验尚未运行, 跳过
        end
        try
            T = readtable(fcsv);
            % 取指定子集那一行
            row = T(strcmpi(string(T.Set), whichSet), :);
            if isempty(row); continue; end
            names{end+1}  = tag;            %#ok<AGROW>
            MAE(end+1)    = row.MAE(1);     %#ok<AGROW>
            RMSE(end+1)   = row.RMSE(1);    %#ok<AGROW>
            R2(end+1)     = row.R2(1);      %#ok<AGROW>
            MaxAE(end+1)  = row.MaxAE(1);   %#ok<AGROW>
            MeanRel(end+1)= row.MeanRelError_pct(1); %#ok<AGROW>
        catch ME
            warning('读取 %s 失败: %s', fcsv, ME.message);
        end
    end

    if isempty(names)
        fprintf(['[plotAblationComparison] 未找到任何实验结果 (results/metrics/metrics_M*.csv)。\n' ...
                 '  请先运行至少一个实验 (修改 main.m 中 experimentName 后运行)。\n']);
        summaryTable = table();
        return;
    end

    %% ---- 2) 汇总表 ----
    summaryTable = table(string(names(:)), MAE(:), RMSE(:), R2(:), MaxAE(:), MeanRel(:), ...
        'VariableNames', {'Experiment','MAE','RMSE','R2','MaxAE','MeanRelError_pct'});
    outCsv = fullfile(cfg.metricDir, sprintf('ablation_summary_%s.csv', whichSet));
    try
        writetable(summaryTable, outCsv);
        fprintf('[plotAblationComparison] 汇总表已保存: %s\n', outCsv);
    catch
    end
    disp(summaryTable);

    %% ---- 3) 对比柱状图 ----
    try
        f = figure('Visible','off','Color','w','Position',[100 100 1000 620]);

        subplot(2,2,1);
        bar(MAE); grid on; title(sprintf('MAE (%s)', whichSet));
        set(gca,'XTickLabel',names); ylabel('MAE (mm)');

        subplot(2,2,2);
        bar(RMSE); grid on; title(sprintf('RMSE (%s)', whichSet));
        set(gca,'XTickLabel',names); ylabel('RMSE (mm)');

        subplot(2,2,3);
        bar(R2); grid on; title(sprintf('R^2 (%s)', whichSet));
        set(gca,'XTickLabel',names); ylabel('R^2');

        subplot(2,2,4);
        bar(MeanRel); grid on; title(sprintf('平均相对误差 (%s)', whichSet));
        set(gca,'XTickLabel',names); ylabel('MeanRelError (%)');

        sgtitle('消融实验 M1~M8 性能对比');

        fpath = fullfile(cfg.figDir, sprintf('ablation_comparison_%s.png', whichSet));
        try
            exportgraphics(f, fpath, 'Resolution', 150);
        catch
            saveas(f, fpath);
        end
        close(f);
        fprintf('[plotAblationComparison] 对比图已保存: %s\n', fpath);
    catch ME
        warning('绘制消融对比图失败: %s', ME.message);
    end
end
