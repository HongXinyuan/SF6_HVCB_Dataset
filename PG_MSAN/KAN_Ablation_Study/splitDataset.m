function split = splitDataset(data, cfg)
% splitDataset  按 7:1.5:1.5 划分训练/验证/测试集(分层 + 可复现)
% -------------------------------------------------------------------------

    setRandomSeed(cfg.randomSeed);

    N = numel(data.labels);
    labels = data.labels(:);
    source = data.source(:);

    % --- 长度分箱(用于分层) ---
    nBins = 5;
    lo = min(labels); hi = max(labels);
    if hi <= lo
        lenBin = ones(N,1);
    else
        edges = linspace(lo, hi, nBins+1);
        lenBin = discretize(labels, edges);
        lenBin(isnan(lenBin)) = nBins;
    end

    % --- 组合分层键: 数据源 + 长度箱 ---
    groupKey = strings(N,1);
    for i = 1:N
        groupKey(i) = string(source{i}) + "_" + string(lenBin(i));
    end
    uKeys = unique(groupKey);

    trainIdx = []; valIdx = []; testIdx = [];

    for g = 1:numel(uKeys)
        idx = find(groupKey == uKeys(g));
        idx = idx(randperm(numel(idx)));   % 组内随机
        n = numel(idx);

        nTrain = floor(cfg.trainRatio * n);
        nVal   = floor(cfg.valRatio   * n);

        % 容错: 小样本组优先保证训练集
        if n == 1
            nTrain = 1; nVal = 0;
        elseif n == 2
            nTrain = 1; nVal = 1;   % 余 0 个测试
        elseif nTrain < 1
            nTrain = 1;
        end
        nTest = n - nTrain - nVal;
        if nTest < 0
            nVal = max(0, nVal + nTest);
            nTest = 0;
        end

        trainIdx = [trainIdx; idx(1:nTrain)];                       %#ok<AGROW>
        valIdx   = [valIdx;   idx(nTrain+1 : nTrain+nVal)];         %#ok<AGROW>
        testIdx  = [testIdx;  idx(nTrain+nVal+1 : end)];            %#ok<AGROW>
    end

    % 若验证/测试集为空(极小数据集), 从训练集借用样本兜底
    if isempty(valIdx) && numel(trainIdx) > 2
        valIdx = trainIdx(end); trainIdx(end) = [];
    end
    if isempty(testIdx) && numel(trainIdx) > 2
        testIdx = trainIdx(end); trainIdx(end) = [];
    end

    split = struct();
    split.trainIdx = sort(trainIdx(:));
    split.valIdx   = sort(valIdx(:));
    split.testIdx  = sort(testIdx(:));
    split.ratios   = [cfg.trainRatio, cfg.valRatio, cfg.testRatio];

    fprintf('[splitDataset] 训练 %d / 验证 %d / 测试 %d (总 %d)\n', ...
        numel(split.trainIdx), numel(split.valIdx), numel(split.testIdx), N);
end
