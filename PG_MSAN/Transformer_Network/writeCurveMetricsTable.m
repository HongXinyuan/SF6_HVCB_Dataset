function writeCurveMetricsTable(cmp, metricsTableFile, cfg) %#ok<INUSD>
% writeCurveMetricsTable  生成曲线校准度量总表 CurveMetricsCompare.xlsx

metricNames = {'Cas', 'Corr', 'R2', 'RMSE', 'MAE', 'MaxAE', 'MAPE', 'NRMSE', 'DTW', 'Frechet'};
higherBetter = [true,  true,   true, false,  false, false,   false,  false,   false, false];
metricHdr = {'Cas', 'Corr', 'R2', 'RMSE (mΩ)', 'MAE (mΩ)', 'MaxAE (mΩ)', ...
             'MAPE (%)', 'NRMSE', 'DTW (mΩ)', 'Frechet (mΩ)'};
nM = numel(metricNames);
numR = numel(cmp);

% ---- (1) 从 cmp 中抽取校准前/后的度量矩阵（numR x nM） ----
MB = nan(numR, nM);   % before
MA = nan(numR, nM);   % after
for r = 1:numR
    sb = getSim(cmp(r), 'simBefore');
    sa = getSim(cmp(r), 'simAfter');
    for k = 1:nM
        MB(r, k) = getField(sb, metricNames{k});
        MA(r, k) = getField(sa, metricNames{k});
    end
end

% ---- (2) PerFile sheet：逐文件 before/after/Δ ----
perHdr = {'RealFile', 'RealLength_mm', 'ArtFile', 'numPoints'};
for k = 1:nM
    perHdr = [perHdr, {['Before_' metricHdr{k}], ['After_' metricHdr{k}], ...
                       ['Improve_' metricNames{k}]}]; %#ok<AGROW>
end

perRows = cell(numR, numel(perHdr));
for r = 1:numR
    sb = getSim(cmp(r), 'simBefore');
    np = getField(sb, 'numPoints');
    perRows(r, 1:4) = {getField2(cmp(r), 'realName', ''), ...
                       getField2(cmp(r), 'realLength', NaN), ...
                       getField2(cmp(r), 'artName', ''), np};
    col = 5;
    for k = 1:nM
        bval = MB(r, k);
        aval = MA(r, k);
        improve = signedImprove(bval, aval, higherBetter(k));
        perRows(r, col:col+2) = {bval, aval, improve};
        col = col + 3;
    end
end
Cper = [perHdr; perRows];

% ---- (3) Summary sheet：平均 before/after/Δ/改善率% ----
mB = mean(MB, 1, 'omitnan');
mA = mean(MA, 1, 'omitnan');

sumHdr = {'Metric', 'Direction', 'Mean_Before', 'Mean_After', ...
          'Mean_Improve', 'Improve_Pct'};
sumRows = cell(nM, numel(sumHdr));
for k = 1:nM
    if higherBetter(k)
        direction = '↑越大越好';
        improve = mA(k) - mB(k);                 % 正=变好
        base = abs(mB(k));
    else
        direction = '↓越小越好';
        improve = mB(k) - mA(k);                 % 正=变好
        base = abs(mB(k));
    end
    if isfinite(base) && base > eps
        improvePct = 100 * improve / base;
    else
        improvePct = NaN;
    end
    sumRows(k, :) = {metricHdr{k}, direction, mB(k), mA(k), improve, improvePct};
end
Csum = [sumHdr; sumRows];

% ---- (4) 写出 Excel（两个 sheet） ----
if isfile(metricsTableFile), delete(metricsTableFile); end
writecell(Csum, metricsTableFile, 'Sheet', 'Summary');
writecell(Cper, metricsTableFile, 'Sheet', 'PerFile');

% ---- (5) 命令行摘要 ----
fprintf('  曲线校准度量总表已生成：%s\n', metricsTableFile);
fprintf('  整体曲线匹配度量（改善率 > 0 表示校准后更好）：\n');
for k = 1:nM
    if higherBetter(k)
        improve = mA(k) - mB(k); base = abs(mB(k)); arrow = '↑';
    else
        improve = mB(k) - mA(k); base = abs(mB(k)); arrow = '↓';
    end
    if isfinite(base) && base > eps
        pct = 100 * improve / base;
    else
        pct = NaN;
    end
    fprintf('    %-8s(%s): %.4f -> %.4f，改善率 %+.2f%%\n', ...
        metricNames{k}, arrow, mB(k), mA(k), pct);
end
end

%% ------------------------------------------------------------------------
function s = getSim(rec, fieldName)
% 安全取出 simBefore / simAfter 结构体，缺失时返回空结构体。
if isfield(rec, fieldName) && isstruct(rec.(fieldName))
    s = rec.(fieldName);
else
    s = struct();
end
end

%% ------------------------------------------------------------------------
function v = getField(s, name)
% 安全取标量字段，缺失/非数返回 NaN。
if isstruct(s) && isfield(s, name) && ~isempty(s.(name)) && isnumeric(s.(name))
    v = double(s.(name));
else
    v = NaN;
end
end

%% ------------------------------------------------------------------------
function v = getField2(s, name, defVal)
% 安全取任意字段（字符串/数值），缺失返回默认值。
if isstruct(s) && isfield(s, name) && ~isempty(s.(name))
    v = s.(name);
else
    v = defVal;
end
end

%% ------------------------------------------------------------------------
function d = signedImprove(bval, aval, isHigherBetter)
% 计算\"正值=校准后更好\"的改善量。
if ~isfinite(bval) || ~isfinite(aval)
    d = NaN;
    return;
end
if isHigherBetter
    d = aval - bval;
else
    d = bval - aval;
end
end
