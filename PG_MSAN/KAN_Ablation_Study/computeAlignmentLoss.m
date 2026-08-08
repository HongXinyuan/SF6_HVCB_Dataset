function Lalign = computeAlignmentLoss(featReal, featOther, method)
% computeAlignmentLoss  分布对齐损失(修正数据 与 真实烧蚀数据 之间)

    if nargin < 3 || isempty(method); method = 'coral'; end

    featReal  = stripdims(featReal);
    featOther = stripdims(featOther);

    Nr = size(featReal, 2);
    No = size(featOther, 2);
    if Nr < 1 || No < 1
        Lalign = dlarray(single(0));
        return;
    end

    mr = mean(featReal, 2);     % D x 1
    mo = mean(featOther, 2);
    meanLoss = sum((mr - mo).^2);

    switch lower(method)
        case 'mean'
            Lalign = meanLoss;

        case 'mmd'
            % 线性核 MMD == 均值差范数平方
            Lalign = meanLoss;

        case 'coral'
            if Nr < 2 || No < 2
                Lalign = meanLoss;   % 样本太少无法估协方差, 退化为均值对齐
                return;
            end
            D = size(featReal, 1);
            Cr = covFeat(featReal, mr);     % D x D
            Co = covFeat(featOther, mo);
            coralLoss = sum(sum((Cr - Co).^2)) / (4 * D * D);
            Lalign = coralLoss + meanLoss;

        otherwise
            error('computeAlignmentLoss:method', '未知对齐方法: %s', method);
    end
end

% 局部函数: 计算特征协方差(D x D)
function C = covFeat(X, mu)
    N = size(X, 2);
    Xc = X - mu;                 % D x N 去均值
    C = (Xc * Xc.') / max(N - 1, 1);
end
