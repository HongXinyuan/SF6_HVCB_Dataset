function saveExperimentResults(res, cfg)
% saveExperimentResults  保存模型 / 指标 / 预测表 / 划分(自动建目录)

    tag = char(cfg.experimentName);
    ensureDir(cfg.modelDir); ensureDir(cfg.metricDir); ensureDir(cfg.predDir);

    %% ---- 1) 保存模型(含标准化统计、cfg、Cas 参考模板, 供单条预测复用) ----
    model = res.model; %#ok<NASGU>
    cfgSaved = cfg;    %#ok<NASGU>
    refTemplates = res.data.refTemplates; %#ok<NASGU>
    split = res.split; %#ok<NASGU>
    history = res.history; %#ok<NASGU>
    modelFile = fullfile(cfg.modelDir, sprintf('model_%s.mat', tag));
    save(modelFile, 'model', 'cfgSaved', 'refTemplates', 'split', 'history', '-v7.3');
    % 同时存一份键名为 cfg 的副本以兼容 predictSingleCurve 读取
    cfg = cfgSaved; %#ok<NASGU>
    save(modelFile, 'cfg', '-append');
    fprintf('[save] 模型已保存: %s\n', modelFile);

    %% ---- 2) 保存评价指标(txt + csv) ----
    metricFileTxt = fullfile(cfg.metricDir, sprintf('metrics_%s.txt', tag));
    fid = fopen(metricFileTxt, 'w');
    fprintf(fid, '实验: %s\n损失类型: %s\n数据集: %s\n', tag, cfg.lossType, strjoin(cfg.useDatasets, ', '));
    fprintf(fid, '物理特征=%d  注意力=%d  修正=%d\n\n', cfg.usePhysicalFeatures, cfg.useAttentionFusion, cfg.useCorrection);
    printMetric(fid, '训练集', res.metricsTrain);
    printMetric(fid, '验证集', res.metricsVal);
    printMetric(fid, '测试集', res.metricsTest);
    fclose(fid);

    % csv 汇总
    sets = {'Train','Val','Test'};
    ms = {res.metricsTrain, res.metricsVal, res.metricsTest};
    MAE=zeros(3,1);RMSE=MAE;R2=MAE;MaxAE=MAE;MeanRel=MAE;
    for i=1:3
        MAE(i)=ms{i}.MAE; RMSE(i)=ms{i}.RMSE; R2(i)=ms{i}.R2;
        MaxAE(i)=ms{i}.MaxAE; MeanRel(i)=ms{i}.MeanRelError;
    end
    Tm = table(string(sets(:)), MAE, RMSE, R2, MaxAE, MeanRel, ...
        'VariableNames', {'Set','MAE','RMSE','R2','MaxAE','MeanRelError_pct'});
    writetable(Tm, fullfile(cfg.metricDir, sprintf('metrics_%s.csv', tag)));
    fprintf('[save] 指标已保存: %s\n', metricFileTxt);

    %% ---- 3) 保存测试预测表 ----
    predFile = fullfile(cfg.predDir, 'test_predictions.csv');
    if ~isempty(res.testTable)
        writetable(res.testTable, predFile);
        fprintf('[save] 测试预测表已保存: %s\n', predFile);
    end

    % 保存全部样本的逐曲线批量预测结果(训练/验证/测试合并)
    parts = {};
    if ~isempty(res.trainTable)
        T = addvars(res.trainTable, repmat("Train", height(res.trainTable), 1), ...
            'Before', 1, 'NewVariableNames', 'Set');
        parts{end+1} = T; %#ok<AGROW>
    end
    if ~isempty(res.valTable)
        T = addvars(res.valTable, repmat("Val", height(res.valTable), 1), ...
            'Before', 1, 'NewVariableNames', 'Set');
        parts{end+1} = T; %#ok<AGROW>
    end
    if ~isempty(res.testTable)
        T = addvars(res.testTable, repmat("Test", height(res.testTable), 1), ...
            'Before', 1, 'NewVariableNames', 'Set');
        parts{end+1} = T; %#ok<AGROW>
    end
    if ~isempty(parts)
        batchPredictionTable = vertcat(parts{:}); %#ok<NASGU>
        batchBase = sprintf('batch_single_curve_predictions_%s', tag);
        batchCsv = fullfile(cfg.predDir, [batchBase '.csv']);
        batchMat = fullfile(cfg.predDir, [batchBase '.mat']);
        writetable(batchPredictionTable, batchCsv);
        save(batchMat, 'batchPredictionTable');
        fprintf('[save] 全部逐曲线批量预测已保存: %s / %s\n', batchCsv, batchMat);
    end

    %% ---- 4) 保存划分索引(复现实验) ----
    splitOut = res.split; %#ok<NASGU>
    save(fullfile(cfg.modelDir, sprintf('split_%s.mat', tag)), 'splitOut');
end

function printMetric(fid, name, m)
    fprintf(fid, '[%s] MAE=%.4f  RMSE=%.4f  R2=%.4f  MaxAE=%.4f  MeanRelError=%.2f%%\n', ...
        name, m.MAE, m.RMSE, m.R2, m.MaxAE, m.MeanRelError);
end

function ensureDir(d)
    if ~exist(d, 'dir'); mkdir(d); end
end
