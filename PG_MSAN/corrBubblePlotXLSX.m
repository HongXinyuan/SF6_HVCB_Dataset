function [R, P, variableNames] = corrBubblePlotXLSX(inputFile, varargin)
%CORRBUBBLEPLOTXLSX Read an Excel table and draw a correlation matrix.
%
% Direct use (the default Excel path is already configured):
%   corrBubblePlotXLSX
%
% The default bubble style matches the reference correlation heatmap.
% Circle area is proportional to abs(r), and significance stars are centered
% inside the circles.
%
% Use another Excel file:
%   corrBubblePlotXLSX('D:\data\my_data.xlsx')
%
% Name-value options:
%   'Sheet'            Excel sheet name or number (default: first sheet)
%   'Range'            Excel range, for example 'A1:H100' (default: all)
%   'CorrelationType'  'Pearson', 'Spearman', or 'Kendall'
%   'GlyphStyle'       'bubble' (reference style) or 'pie'
%   'ShowSignificance' Show p-value stars in bubbles (default: true)
%   'BubbleMaxRadius'  Radius used when abs(r) = 1 (default: 0.43)
%   'Title'            Figure title
%   'OutputFile'       PNG/PDF/SVG output path. Empty means automatic PNG.
%   'Resolution'       Raster export resolution in dpi (default: 300)
%   'ShowColorbar'     true or false (default: true)
%   'PositiveColor'    RGB color for positive correlation
%   'NegativeColor'    RGB color for negative correlation
%   'FontName'         Figure font (default: Arial)
%   'FontSize'         Base font size (default: 10)
%
% The Excel table should contain samples in rows and variables in columns.
% Non-numeric columns, constant columns, and columns with fewer than three
% finite observations are ignored. Missing values are handled pairwise.
% Correlations and p-values are calculated internally, so Statistics and
% Machine Learning Toolbox is not required. Spearman and Kendall p-values
% use standard large-sample approximations; Kendall includes tie corrections.
%
% Outputs:
%   R              correlation coefficient matrix
%   P              p-value matrix
%   variableNames  names of the numeric variables included in the plot

    defaultInputFile = ...
        "C:\Users\hong\Desktop\PG_MSAN\Correlation_coefficient.xlsx";

    if nargin < 1 || isempty(inputFile)
        inputFile = defaultInputFile;
    end
    inputFile = string(inputFile);

    parser = inputParser;
    parser.FunctionName = mfilename;
    addParameter(parser, 'Sheet', []);
    addParameter(parser, 'Range', "", @(x) ischar(x) || isstring(x));
    addParameter(parser, 'CorrelationType', 'Pearson', ...
        @(x) any(strcmpi(string(x), ["Pearson", "Spearman", "Kendall"])));
    addParameter(parser, 'GlyphStyle', 'bubble', ...
        @(x) any(strcmpi(string(x), ["pie", "bubble"])));
    addParameter(parser, 'ShowSignificance', true, ...
        @(x) islogical(x) && isscalar(x));
    addParameter(parser, 'BubbleMaxRadius', 0.43, ...
        @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x > 0 && x < 0.5);
    addParameter(parser, 'Title', 'Correlation Coefficient', ...
        @(x) ischar(x) || isstring(x));
    addParameter(parser, 'OutputFile', "", ...
        @(x) ischar(x) || isstring(x));
    addParameter(parser, 'Resolution', 300, ...
        @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x > 0);
    addParameter(parser, 'ShowColorbar', true, ...
        @(x) islogical(x) && isscalar(x));
    addParameter(parser, 'PositiveColor', [0.13, 0.40, 0.78], ...
        @isValidRGB);
    addParameter(parser, 'NegativeColor', [0.82, 0.18, 0.18], ...
        @isValidRGB);
    addParameter(parser, 'FontName', 'Arial', ...
        @(x) ischar(x) || isstring(x));
    addParameter(parser, 'FontSize', 10, ...
        @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x > 0);
    parse(parser, varargin{:});
    opt = parser.Results;

    if ~isfile(inputFile)
        error('corrBubblePlotXLSX:FileNotFound', ...
            'Excel file not found:\n%s', inputFile);
    end

    readArgs = {'PreserveVariableNames', true};
    if ~isempty(opt.Sheet)
        readArgs = [readArgs, {'Sheet', opt.Sheet}]; %#ok<AGROW>
    end
    if strlength(string(opt.Range)) > 0
        readArgs = [readArgs, {'Range', char(opt.Range)}]; %#ok<AGROW>
    end

    try
        dataTable = readtable(inputFile, readArgs{:});
    catch firstError
        % Newer MATLAB versions prefer VariableNamingRule over the older
        % PreserveVariableNames option.
        readArgs = {'VariableNamingRule', 'preserve'};
        if ~isempty(opt.Sheet)
            readArgs = [readArgs, {'Sheet', opt.Sheet}]; %#ok<AGROW>
        end
        if strlength(string(opt.Range)) > 0
            readArgs = [readArgs, {'Range', char(opt.Range)}]; %#ok<AGROW>
        end
        try
            dataTable = readtable(inputFile, readArgs{:});
        catch
            rethrow(firstError);
        end
    end

    if height(dataTable) < 3
        error('corrBubblePlotXLSX:TooFewRows', ...
            'The Excel table must contain at least three data rows.');
    end

    numericColumns = varfun(@isnumeric, dataTable, 'OutputFormat', 'uniform');
    if ~any(numericColumns)
        error('corrBubblePlotXLSX:NoNumericColumns', ...
            'No numeric columns were found in the Excel table.');
    end

    numericTable = dataTable(:, numericColumns);
    X = double(numericTable{:,:});
    X(~isfinite(X)) = NaN;
    candidateNames = string(numericTable.Properties.VariableNames);

    keep = false(1, size(X, 2));
    for columnIndex = 1:size(X, 2)
        values = X(:, columnIndex);
        values = values(isfinite(values));
        if numel(values) >= 3
            scale = max(1, max(abs(values)));
            keep(columnIndex) = (max(values) - min(values)) > eps(scale);
        end
    end

    if any(~keep)
        warning('corrBubblePlotXLSX:ColumnsSkipped', ...
            'Skipped unusable columns: %s', ...
            strjoin(cellstr(candidateNames(~keep)), ', '));
    end

    X = X(:, keep);
    variableNames = candidateNames(keep);
    if size(X, 2) < 2
        error('corrBubblePlotXLSX:TooFewVariables', ...
            ['At least two usable numeric variables are required. ', ...
             'A usable variable needs three finite, non-constant values.']);
    end

    correlationType = validatestring(opt.CorrelationType, ...
        {'Pearson', 'Spearman', 'Kendall'});
    [R, P] = correlationMatrixNoToolbox(X, correlationType);

    glyphStyle = validatestring(opt.GlyphStyle, {'pie', 'bubble'});
    numberOfVariables = numel(variableNames);
    figureWidth = min(1800, max(850, 92 * numberOfVariables));
    figureHeight = min(1700, max(760, 86 * numberOfVariables));

    fig = figure('Color', 'w', ...
        'Name', 'Correlation matrix', ...
        'NumberTitle', 'off', ...
        'Position', [80, 60, figureWidth, figureHeight]);
    ax = axes('Parent', fig);
    hold(ax, 'on');
    axis(ax, 'equal');
    ax.YDir = 'reverse';
    ax.XAxisLocation = 'top';
    ax.XLim = [0.5, numberOfVariables + 0.5];
    ax.YLim = [0.5, numberOfVariables + 0.5];
    ax.XTick = 1:numberOfVariables;
    ax.YTick = 1:numberOfVariables;
    ax.XTickLabel = cellstr(variableNames);
    ax.YTickLabel = cellstr(variableNames);
    ax.XTickLabelRotation = 45;
    ax.TickLabelInterpreter = 'none';
    ax.FontName = char(opt.FontName);
    ax.FontSize = opt.FontSize;
    ax.LineWidth = 0.8;
    ax.Layer = 'top';
    box(ax, 'on');

    % Cell grid.
    for edge = 0.5:1:(numberOfVariables + 0.5)
        plot(ax, [0.5, numberOfVariables + 0.5], [edge, edge], ...
            '-', 'Color', [0.86, 0.86, 0.86], 'LineWidth', 0.6);
        plot(ax, [edge, edge], [0.5, numberOfVariables + 0.5], ...
            '-', 'Color', [0.86, 0.86, 0.86], 'LineWidth', 0.6);
    end

    % Lower triangle: coefficients. Upper triangle and diagonal: bubbles.
    for rowIndex = 1:numberOfVariables
        for columnIndex = 1:numberOfVariables
            coefficient = R(rowIndex, columnIndex);
            pValue = P(rowIndex, columnIndex);

            if rowIndex > columnIndex
                if isfinite(coefficient)
                    text(ax, columnIndex, rowIndex, ...
                        sprintf('%.2f', coefficient), ...
                        'HorizontalAlignment', 'center', ...
                        'VerticalAlignment', 'middle', ...
                        'FontName', char(opt.FontName), ...
                        'FontSize', opt.FontSize, ...
                        'FontWeight', 'bold', ...
                        'Color', [0.08, 0.08, 0.08]);
                else
                    text(ax, columnIndex, rowIndex, 'NA', ...
                        'HorizontalAlignment', 'center', ...
                        'Color', [0.55, 0.55, 0.55]);
                end

            else
                if isfinite(coefficient)
                    if strcmpi(glyphStyle, 'pie')
                        drawPieGlyph(ax, columnIndex, rowIndex, coefficient, ...
                            opt.NegativeColor, opt.PositiveColor);
                    else
                        drawBubbleGlyph(ax, columnIndex, rowIndex, coefficient, ...
                            opt.NegativeColor, opt.PositiveColor, ...
                            opt.BubbleMaxRadius);
                    end

                    % A diagonal self-correlation has no meaningful
                    % significance test, so stars are shown off-diagonal only.
                    if opt.ShowSignificance && rowIndex < columnIndex
                        stars = significanceStars(pValue);
                    else
                        stars = '';
                    end
                    if ~isempty(stars)
                        text(ax, columnIndex, rowIndex, stars, ...
                            'HorizontalAlignment', 'center', ...
                            'VerticalAlignment', 'middle', ...
                            'FontName', char(opt.FontName), ...
                            'FontSize', opt.FontSize + 1, ...
                            'FontWeight', 'bold', ...
                            'Color', [0.10, 0.10, 0.10]);
                    end
                else
                    text(ax, columnIndex, rowIndex, 'NA', ...
                        'HorizontalAlignment', 'center', ...
                        'Color', [0.55, 0.55, 0.55]);
                end
            end
        end
    end

    title(ax, string(opt.Title), ...
        'Interpreter', 'none', ...
        'FontName', char(opt.FontName), ...
        'FontSize', opt.FontSize + 4, ...
        'FontWeight', 'bold');
    annotation(fig, 'textbox', [0.20, 0.012, 0.60, 0.035], ...
        'String', '*  p < 0.05     **  p < 0.01     ***  p < 0.001', ...
        'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'middle', ...
        'EdgeColor', 'none', ...
        'FontName', char(opt.FontName), ...
        'FontSize', opt.FontSize);

    if opt.ShowColorbar
        colormap(ax, divergingMap(256, opt.NegativeColor, opt.PositiveColor));
        caxis(ax, [-1, 1]);
        colorScale = colorbar(ax);
        colorScale.Label.String = 'Correlation coefficient (r)';
        colorScale.Label.FontName = char(opt.FontName);
        colorScale.FontName = char(opt.FontName);
    end

    outputFile = string(opt.OutputFile);
    if strlength(outputFile) == 0
        [inputFolder, inputBaseName] = fileparts(char(inputFile));
        if isempty(inputFolder)
            inputFolder = pwd;
        end
        outputFile = string(fullfile(inputFolder, ...
            sprintf('%s_correlation_%s.png', inputBaseName, lower(glyphStyle))));
    end

    outputFolder = fileparts(char(outputFile));
    if ~isempty(outputFolder) && ~isfolder(outputFolder)
        mkdir(outputFolder);
    end

    try
        exportgraphics(fig, outputFile, 'Resolution', opt.Resolution);
    catch exportError
        warning('corrBubblePlotXLSX:ExportFailed', ...
            'The figure was created but could not be exported:\n%s', ...
            exportError.message);
    end

    fprintf('Correlation figure saved to:\n%s\n', outputFile);
end


function [R, P] = correlationMatrixNoToolbox(X, correlationType)
% Pairwise correlation matrix using only base MATLAB functions.
    numberOfVariables = size(X, 2);
    R = NaN(numberOfVariables);
    P = NaN(numberOfVariables);

    for variableIndex = 1:numberOfVariables
        R(variableIndex, variableIndex) = 1;
        P(variableIndex, variableIndex) = 0;
    end

    for firstIndex = 1:(numberOfVariables - 1)
        for secondIndex = (firstIndex + 1):numberOfVariables
            x = X(:, firstIndex);
            y = X(:, secondIndex);
            completeRows = isfinite(x) & isfinite(y);
            x = x(completeRows);
            y = y(completeRows);

            if numel(x) < 3
                coefficient = NaN;
                pValue = NaN;
            else
                switch lower(correlationType)
                    case 'pearson'
                        [coefficient, pValue] = pearsonPair(x, y);
                    case 'spearman'
                        xRanks = averageRanks(x);
                        yRanks = averageRanks(y);
                        [coefficient, pValue] = pearsonPair(xRanks, yRanks);
                    case 'kendall'
                        [coefficient, pValue] = kendallPair(x, y);
                    otherwise
                        error('corrBubblePlotXLSX:UnknownCorrelationType', ...
                            'Unknown correlation type: %s', correlationType);
                end
            end

            R(firstIndex, secondIndex) = coefficient;
            R(secondIndex, firstIndex) = coefficient;
            P(firstIndex, secondIndex) = pValue;
            P(secondIndex, firstIndex) = pValue;
        end
    end
end


function [coefficient, pValue] = pearsonPair(x, y)
% Pearson coefficient and exact two-sided t-test p-value.
    xCentered = x - mean(x);
    yCentered = y - mean(y);
    denominator = sqrt(sum(xCentered .^ 2) * sum(yCentered .^ 2));

    if denominator <= 0 || ~isfinite(denominator)
        coefficient = NaN;
        pValue = NaN;
        return;
    end

    coefficient = sum(xCentered .* yCentered) / denominator;
    coefficient = max(-1, min(1, coefficient));
    degreesOfFreedom = numel(x) - 2;

    if abs(coefficient) >= 1
        pValue = 0;
    else
        tSquared = degreesOfFreedom * coefficient ^ 2 / ...
            max(realmin, 1 - coefficient ^ 2);
        betaArgument = degreesOfFreedom / (degreesOfFreedom + tSquared);
        pValue = betainc(betaArgument, degreesOfFreedom / 2, 0.5);
        pValue = max(0, min(1, pValue));
    end
end


function ranks = averageRanks(values)
% Average ranks for tied observations; replacement for tiedrank.
    values = values(:);
    [sortedValues, order] = sort(values);
    ranks = zeros(size(values));
    first = 1;

    while first <= numel(values)
        last = first;
        while last < numel(values) && ...
                sortedValues(last + 1) == sortedValues(first)
            last = last + 1;
        end
        ranks(order(first:last)) = (first + last) / 2;
        first = last + 1;
    end
end


function [coefficient, pValue] = kendallPair(x, y)
% Kendall tau-b and a two-sided normal-approximation p-value with tie terms.
    x = x(:);
    y = y(:);
    sampleCount = numel(x);
    score = 0;

    for first = 1:(sampleCount - 1)
        xDifference = x((first + 1):sampleCount) - x(first);
        yDifference = y((first + 1):sampleCount) - y(first);
        score = score + sum(sign(xDifference) .* sign(yDifference));
    end

    xTieSizes = tieGroupSizes(x);
    yTieSizes = tieGroupSizes(y);
    totalPairs = sampleCount * (sampleCount - 1) / 2;
    xTiePairs = sum(xTieSizes .* (xTieSizes - 1) / 2);
    yTiePairs = sum(yTieSizes .* (yTieSizes - 1) / 2);
    denominator = sqrt((totalPairs - xTiePairs) * ...
        (totalPairs - yTiePairs));

    if denominator <= 0 || ~isfinite(denominator)
        coefficient = NaN;
        pValue = NaN;
        return;
    end
    coefficient = score / denominator;
    coefficient = max(-1, min(1, coefficient));

    xTerm1 = sum(xTieSizes .* (xTieSizes - 1) .* ...
        (2 * xTieSizes + 5));
    yTerm1 = sum(yTieSizes .* (yTieSizes - 1) .* ...
        (2 * yTieSizes + 5));
    varianceScore = (sampleCount * (sampleCount - 1) * ...
        (2 * sampleCount + 5) - xTerm1 - yTerm1) / 18;

    xTerm2 = sum(xTieSizes .* (xTieSizes - 1));
    yTerm2 = sum(yTieSizes .* (yTieSizes - 1));
    varianceScore = varianceScore + ...
        (xTerm2 * yTerm2) / (2 * sampleCount * (sampleCount - 1));

    if sampleCount > 2
        xTerm3 = sum(xTieSizes .* (xTieSizes - 1) .* (xTieSizes - 2));
        yTerm3 = sum(yTieSizes .* (yTieSizes - 1) .* (yTieSizes - 2));
        varianceScore = varianceScore + ...
            (xTerm3 * yTerm3) / ...
            (9 * sampleCount * (sampleCount - 1) * (sampleCount - 2));
    end

    if varianceScore <= 0 || ~isfinite(varianceScore)
        pValue = NaN;
    else
        zValue = score / sqrt(varianceScore);
        pValue = erfc(abs(zValue) / sqrt(2));
        pValue = max(0, min(1, pValue));
    end
end


function sizes = tieGroupSizes(values)
% Return only group sizes greater than one.
    sortedValues = sort(values(:));
    sizes = zeros(0, 1);
    first = 1;

    while first <= numel(sortedValues)
        last = first;
        while last < numel(sortedValues) && ...
                sortedValues(last + 1) == sortedValues(first)
            last = last + 1;
        end
        groupSize = last - first + 1;
        if groupSize > 1
            sizes(end + 1, 1) = groupSize; %#ok<AGROW>
        end
        first = last + 1;
    end
end


function drawBubbleGlyph(ax, centerX, centerY, coefficient, ...
    negativeColor, positiveColor, maximumRadius)
% Circle area is proportional to the absolute correlation coefficient.
    radius = maximumRadius * sqrt(abs(coefficient));
    if radius < 0.008
        radius = 0.008;
    end
    faceColor = correlationColor(coefficient, negativeColor, positiveColor);
    rectangle(ax, ...
        'Position', [centerX - radius, centerY - radius, 2 * radius, 2 * radius], ...
        'Curvature', [1, 1], ...
        'FaceColor', faceColor, ...
        'EdgeColor', 'none');
end


function drawPieGlyph(ax, centerX, centerY, coefficient, ...
    negativeColor, positiveColor)
% Wedge fraction is proportional to the absolute correlation coefficient.
    radius = 0.39;
    fraction = min(1, max(0, abs(coefficient)));
    circleAngles = linspace(0, 2 * pi, 160);

    patch(ax, ...
        centerX + radius * cos(circleAngles), ...
        centerY + radius * sin(circleAngles), ...
        [0.94, 0.94, 0.94], ...
        'EdgeColor', 'none');

    if fraction > 0
        numberOfPoints = max(3, ceil(140 * fraction));
        wedgeAngles = linspace(-pi / 2, -pi / 2 + 2 * pi * fraction, ...
            numberOfPoints);
        if coefficient < 0
            wedgeColor = negativeColor;
        else
            wedgeColor = positiveColor;
        end
        patch(ax, ...
            [centerX, centerX + radius * cos(wedgeAngles), centerX], ...
            [centerY, centerY + radius * sin(wedgeAngles), centerY], ...
            wedgeColor, ...
            'EdgeColor', 'none');
    end

    plot(ax, ...
        centerX + radius * cos(circleAngles), ...
        centerY + radius * sin(circleAngles), ...
        '-', 'Color', [0.42, 0.42, 0.42], 'LineWidth', 0.65);
end


function color = correlationColor(coefficient, negativeColor, positiveColor)
% Continuous white-to-red/blue correlation color.
    white = [1, 1, 1];
    strength = min(1, abs(coefficient));
    if coefficient < 0
        target = negativeColor;
    else
        target = positiveColor;
    end
    color = white + strength .* (target - white);
end


function stars = significanceStars(pValue)
    if ~isfinite(pValue)
        stars = '';
    elseif pValue < 0.001
        stars = '***';
    elseif pValue < 0.01
        stars = '**';
    elseif pValue < 0.05
        stars = '*';
    else
        stars = '';
    end
end


function map = divergingMap(numberOfColors, negativeColor, positiveColor)
    halfCount = floor(numberOfColors / 2);
    lowerHalf = [linspace(negativeColor(1), 1, halfCount)', ...
                 linspace(negativeColor(2), 1, halfCount)', ...
                 linspace(negativeColor(3), 1, halfCount)'];
    upperCount = numberOfColors - halfCount;
    upperHalf = [linspace(1, positiveColor(1), upperCount)', ...
                 linspace(1, positiveColor(2), upperCount)', ...
                 linspace(1, positiveColor(3), upperCount)'];
    map = [lowerHalf; upperHalf];
end


function valid = isValidRGB(value)
    valid = isnumeric(value) && isequal(size(value), [1, 3]) && ...
        all(isfinite(value)) && all(value >= 0) && all(value <= 1);
end
