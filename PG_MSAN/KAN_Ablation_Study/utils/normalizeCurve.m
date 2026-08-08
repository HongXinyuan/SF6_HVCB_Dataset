function [curveNorm, normInfo] = normalizeCurve(curve, method, normInfo)
% normalizeCurve  对动态电阻曲线进行归一化
% -------------------------------------------------------------------------
% 输入:
%   curve    : 列向量或行向量，动态电阻序列 (mOhm)
%   method   : 'minmax' (默认) 或 'zscore'
%   normInfo : (可选) 结构体，包含已有的归一化统计量；若提供则使用该统计量
%              进行归一化(用于训练集统计复用到验证/测试/单条预测)
% 输出:
%   curveNorm : 归一化后的曲线 (与输入同形状)
%   normInfo  : 结构体，记录本次归一化使用的统计量
%               .method, .a, .b   (minmax: a=min,b=max; zscore: a=mean,b=std)
% -------------------------------------------------------------------------
% 说明:
%   - 'minmax' 将曲线线性缩放到 [0,1]
%   - 'zscore' 标准化为均值 0、方差 1
%   归一化有助于曲线编码模块训练稳定。
% -------------------------------------------------------------------------
    if nargin < 2 || isempty(method)
        method = 'minmax';
    end
    curve = double(curve(:));               % 统一列向量

    if nargin < 3 || isempty(normInfo)
        % 根据当前曲线计算统计量
        switch lower(method)
            case 'minmax'
                a = min(curve);
                b = max(curve);
            case 'zscore'
                a = mean(curve);
                b = std(curve);
            otherwise
                error('normalizeCurve:method', '未知归一化方法: %s', method);
        end
        normInfo = struct('method', lower(method), 'a', a, 'b', b);
    end

    switch normInfo.method
        case 'minmax'
            rangeVal = normInfo.b - normInfo.a;
            if rangeVal <= eps
                curveNorm = zeros(size(curve));   % 常数曲线 -> 全 0
            else
                curveNorm = (curve - normInfo.a) / rangeVal;
            end
        case 'zscore'
            sd = normInfo.b;
            if sd <= eps
                curveNorm = zeros(size(curve));
            else
                curveNorm = (curve - normInfo.a) / sd;
            end
    end
end
