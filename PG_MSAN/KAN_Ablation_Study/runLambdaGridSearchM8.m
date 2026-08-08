function runLambdaGridSearchM8()
% runLambdaGridSearchM8  M8 损失权重二维循环与 Test 指标汇总
% -------------------------------------------------------------------------

    clc;

    %% ---- 0) 工程路径准备（确保 utils/resampleCurve.m 等函数可用） ----
    thisFile = mfilename('fullpath');
    thisDir = fileparts(thisFile);
    if isempty(thisDir); thisDir = pwd; end
    oldDir = pwd;
    cleanupObj = onCleanup(@() cd(oldDir)); %#ok<NASGU>
    cd(thisDir);
    addpath(genpath(thisDir));

    %% ---- 1) M8 配置与权重网格 ----
    cfg = getExperimentConfig("M8");
    lambdaAlignValues = round((8:12) * 0.0025, 4);   % lambdaAlignValues = round((0:12) * 0.005, 4)，[0, 0.3]，共 13 个值
    lambdaMonoValues  = round((4:8) * 0.0025, 4);   % lambdaMonoValues  = round((0:80) * 0.0025, 4)，[0, 0.2]，共 81 个值
    totalRuns = numel(lambdaAlignValues) * numel(lambdaMonoValues);

    if ~exist(cfg.metricDir, 'dir'); mkdir(cfg.metricDir); end
    summaryFile = fullfile(cfg.metricDir, 'lambda_weight_grid_summary_M8.csv');

    fprintf('==========================================================\n');
    fprintf('  M8 损失权重二维循环\n');
    fprintf('  lambdaAlign: 0:0.025:0.3 (%d 个值)\n', numel(lambdaAlignValues));
    fprintf('  lambdaMono : 0:0.0025:0.2 (%d 个值)\n', numel(lambdaMonoValues));
    fprintf('  总训练组合 : %d\n', totalRuns);
    fprintf('==========================================================\n');

    %% ---- 2) 数据只读取和划分一次，保证所有权重组合使用同一划分 ----
    setRandomSeed(cfg.randomSeed);
    fprintf('\n[准备] 读取并预处理 M8 数据集 ...\n');
    [data, loadInfo] = loadAllDatasets(cfg);
    if isempty(data.labels)
        error(['未读取到任何有效样本，请检查 cfg.dataRoot 及对应数据集文件夹。' ...
               '当前 dataRoot = %s'], cfg.dataRoot);
    end
    fprintf('  成功样本数: %d（失败/跳过: %d）\n', numel(data.labels), loadInfo.nFail);

    split = splitDataset(data, cfg);
    data = prepareCasFeatures(data, split, cfg);
    fprintf('  固定划分: Train=%d, Val=%d, Test=%d\n', ...
        numel(split.trainIdx), numel(split.valIdx), numel(split.testIdx));

    %% ---- 3) 汇总表初始化 ----
    LossWeights = strings(0, 1);
    MAE = zeros(0, 1);
    RMSE = zeros(0, 1);
    R2 = zeros(0, 1);
    MaxAE = zeros(0, 1);
    MeanRelError_pct = zeros(0, 1);
    runIndex = 0;

    %% ---- 4) 权重二维循环 ----
    for ia = 1:numel(lambdaAlignValues)
        for im = 1:numel(lambdaMonoValues)
            runIndex = runIndex + 1;
            lambdaAlign = lambdaAlignValues(ia);
            lambdaMono = lambdaMonoValues(im);
            alignText = formatLambdaValue(lambdaAlign);
            monoText = formatLambdaValue(lambdaMono);

            metricName = sprintf('λalign%sλmono%smetrics_M8.csv', ...
                alignText, monoText);
            metricFile = fullfile(cfg.metricDir, metricName);

            fprintf('\n[%d/%d] lambdaAlign=%s, lambdaMono=%s\n', ...
                runIndex, totalRuns, alignText, monoText);

            % 已有且可读取的单组指标直接复用，支持中断后续跑。
            [testMetric, metricIsValid] = readTestMetric(metricFile);
            if metricIsValid
                fprintf('  已存在有效指标文件，跳过训练: %s\n', metricName);
            else
                cfg.lambdaAlign = lambdaAlign;
                cfg.lambdaMono = lambdaMono;

                % 每组使用相同随机种子，确保初始化和训练随机过程可比。
                setRandomSeed(cfg.randomSeed);
                model = buildKANModel(cfg);
                [model, ~] = trainKANModel(model, data, split, cfg);

                [metricsTrain, ~] = evaluateRegression( ...
                    model, data, split.trainIdx, cfg, 'Train');
                [metricsVal, ~] = evaluateRegression( ...
                    model, data, split.valIdx, cfg, 'Val');
                [metricsTest, ~] = evaluateRegression( ...
                    model, data, split.testIdx, cfg, 'Test');

                writeMetricsCsv(metricFile, metricsTrain, metricsVal, metricsTest);

                % 按要求从刚生成的 CSV 中查找并读取 Test 行。
                [testMetric, metricIsValid] = readTestMetric(metricFile);
                if ~metricIsValid
                    error('生成的指标文件中未找到有效 Test 行: %s', metricFile);
                end
            end

            %% ---- 5) 追加 Test 指标，并在每次循环后刷新汇总表 ----
            LossWeights(end+1, 1) = sprintf( ...
                'lambdaAlign=%s; lambdaMono=%s', alignText, monoText); %#ok<AGROW>
            MAE(end+1, 1) = testMetric.MAE; %#ok<AGROW>
            RMSE(end+1, 1) = testMetric.RMSE; %#ok<AGROW>
            R2(end+1, 1) = testMetric.R2; %#ok<AGROW>
            MaxAE(end+1, 1) = testMetric.MaxAE; %#ok<AGROW>
            MeanRelError_pct(end+1, 1) = testMetric.MeanRelError_pct; %#ok<AGROW>

            summaryTable = table(LossWeights, MAE, RMSE, R2, MaxAE, ...
                MeanRelError_pct, 'VariableNames', ...
                {'LossWeights','MAE','RMSE','R2','MaxAE','MeanRelError_pct'});
            writetable(summaryTable, summaryFile);
            fprintf('  Test: MAE=%.4f, RMSE=%.4f, R2=%.4f, MaxAE=%.4f, MeanRelError=%.2f%%\n', ...
                testMetric.MAE, testMetric.RMSE, testMetric.R2, ...
                testMetric.MaxAE, testMetric.MeanRelError_pct);
        end
    end

    fprintf('\n==========================================================\n');
    fprintf('  权重循环完成，共汇总 %d 组 Test 指标。\n', height(summaryTable));
    fprintf('  汇总表: %s\n', summaryFile);
    fprintf('==========================================================\n');
end

function writeMetricsCsv(metricFile, metricsTrain, metricsVal, metricsTest)
% 保持原 metrics_M8.csv 的列结构，仅改变每组输出文件名。
    sets = {'Train'; 'Val'; 'Test'};
    metrics = {metricsTrain; metricsVal; metricsTest};
    MAE = zeros(3, 1);
    RMSE = zeros(3, 1);
    R2 = zeros(3, 1);
    MaxAE = zeros(3, 1);
    MeanRelError_pct = zeros(3, 1);

    for i = 1:3
        MAE(i) = metrics{i}.MAE;
        RMSE(i) = metrics{i}.RMSE;
        R2(i) = metrics{i}.R2;
        MaxAE(i) = metrics{i}.MaxAE;
        MeanRelError_pct(i) = metrics{i}.MeanRelError;
    end

    metricTable = table(string(sets), MAE, RMSE, R2, MaxAE, ...
        MeanRelError_pct, 'VariableNames', ...
        {'Set','MAE','RMSE','R2','MaxAE','MeanRelError_pct'});
    writetable(metricTable, metricFile);
    fprintf('  指标已保存: %s\n', metricFile);
end

function [testMetric, isValid] = readTestMetric(metricFile)
% 从单组 CSV 中查找 Test 行，并返回指定的五项指标。
    testMetric = struct('MAE', NaN, 'RMSE', NaN, 'R2', NaN, ...
        'MaxAE', NaN, 'MeanRelError_pct', NaN);
    isValid = false;
    if ~exist(metricFile, 'file')
        return;
    end

    try
        metricTable = readtable(metricFile, 'TextType', 'string');
        requiredVars = {'Set','MAE','RMSE','R2','MaxAE','MeanRelError_pct'};
        if ~all(ismember(requiredVars, metricTable.Properties.VariableNames))
            return;
        end

        testRows = metricTable(strcmpi(strtrim(string(metricTable.Set)), "Test"), :);
        if height(testRows) ~= 1
            return;
        end

        values = [testRows.MAE, testRows.RMSE, testRows.R2, ...
            testRows.MaxAE, testRows.MeanRelError_pct];
        if ~all(isfinite(values))
            return;
        end

        testMetric.MAE = testRows.MAE;
        testMetric.RMSE = testRows.RMSE;
        testMetric.R2 = testRows.R2;
        testMetric.MaxAE = testRows.MaxAE;
        testMetric.MeanRelError_pct = testRows.MeanRelError_pct;
        isValid = true;
    catch
        isValid = false;
    end
end

function textValue = formatLambdaValue(value)
% 最多保留 4 位小数，并去掉不必要的末尾 0。
    textValue = sprintf('%.4f', value);
    textValue = regexprep(textValue, '0+$', '');
    textValue = regexprep(textValue, '\.$', '');
    if isempty(textValue); textValue = '0'; end
end
