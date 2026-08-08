function result = predictSingleCurve(modelPath, datOrTable, cfg)
% predictSingleCurve  单条曲线触头长度预测接口(模型应用)
% -------------------------------------------------------------------------

    result = struct('ok', false, 'msg', '', 'predLength', NaN, ...
        'Rmax',NaN,'tpeak',NaN,'Rmean',NaN,'Smax',NaN,'AR',NaN,'Dlow',NaN,'Cas',NaN);

    % ---- 载入模型 ----
    if ~isfile(modelPath)
        result.msg = sprintf('模型文件不存在: %s', modelPath); return;
    end
    S = load(modelPath);
    if ~isfield(S, 'model')
        result.msg = '模型文件中缺少 model 字段'; return;
    end
    model = S.model;
    if nargin < 3 || isempty(cfg)
        if isfield(S, 'cfg'); cfg = S.cfg; else
            result.msg = '缺少 cfg, 请显式传入'; return; end
    end
    if isfield(S, 'refTemplates'); refTemplates = S.refTemplates; else
        refTemplates = struct('isReal', false); end

    % ---- 解析输入: .dat 文件 或 两列表格 ----
    lengthLabel = NaN;
    if (ischar(datOrTable) || isstring(datOrTable))
        fpath = char(datOrTable);
        [t, r, ok, msg] = loadSingleDatFile(fpath);
        if ~ok; result.msg = msg; return; end
        lengthLabel = parseLengthFromFilename(fpath);   % 若文件名含真值则可对比
    else
        M = datOrTable;
        if istable(M); M = table2array(M); end
        if size(M,2) < 2
            result.msg = '表格数据需至少两列 [时间, 电阻]'; return;
        end
        t = M(:,1); r = M(:,2);
    end

    % ---- 复用训练阶段清洗/重采样/归一化 ----
    pc = preprocessCurve(t, r, cfg);
    if ~pc.ok
        result.msg = ['清洗失败: ' pc.msg]; return;
    end

    % ---- 复用物理特征提取 ----
    phf = extractPhysicalFeatures(pc.t, pc.r, cfg);
    Cas = computeCosineSimilarityFeature(pc.curveVec, refTemplates, cfg);
    featVec = [phf.vector, Cas];     % 1 x 7

    % ---- 构造模型输入 ----
    L = numel(pc.curveVec);
    Xc = dlarray(single(reshape(pc.curveVec(:), [L, 1, 1])));
    if model.fixed.usePhysicalFeatures
        Fm = (featVec - model.fixed.featMu) ./ model.fixed.featSigma;
        Xf = dlarray(single(Fm.'));
    else
        Xf = [];
    end

    % ---- 前向预测 ----
    predStd = kanModelForward(model, Xc, Xf);
    predStd = double(gather(extractdata(predStd)));
    predLength = predStd * model.fixed.yStd + model.fixed.yMean;

    % ---- 输出 ----
    result.ok = true; result.msg = '预测成功';
    result.predLength = predLength;
    result.Rmax  = phf.Rmax;
    result.tpeak = phf.tpeak;
    result.Rmean = phf.Rmean;
    result.Smax  = phf.Smax;
    result.AR    = phf.AR;
    result.Dlow  = phf.Dlow;
    result.Cas   = Cas;

    fprintf('[predictSingleCurve] 预测触头长度 = %.4f mm\n', predLength);
    fprintf('   Rmax=%.4f mOhm  tpeak=%.4f ms  Rmean=%.4f  Smax=%.4f  AR=%.4f  Dlow=%.4f  Cas=%.4f\n', ...
        result.Rmax, result.tpeak, result.Rmean, result.Smax, result.AR, result.Dlow, result.Cas);
    if isfinite(lengthLabel)
        fprintf('   (文件名真值 = %.4f mm, 绝对误差 = %.4f mm)\n', ...
            lengthLabel, abs(lengthLabel - predLength));
    end
end
