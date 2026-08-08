classdef KANLayer < nnet.layer.Layer
% KANLayer  Kolmogorov-Arnold Network 回归层 (自定义可学习一维非线性映射)
% =========================================================================
% 设计依据(Kolmogorov-Arnold 表示定理思想):
%   传统 MLP 在"节点"上使用固定激活函数、在"边"上使用线性权重;
%   KAN 则相反 —— 把"可学习的一维非线性函数"放在每条边上:
%
%        y_o = sum_i  phi_{o,i}( x_i )
%
%   其中每条边的一维函数 phi 由一组"可学习基函数"线性组合而成。
%
%   本实现采用 RBF (径向基) 形式的可学习样条, 即 FastKAN 思路
%   ("KAN are Radial Basis Function Networks"), 它是 B-spline 基的
%   光滑近似, 对 MATLAB 自动微分(dlarray)友好、数值稳定:
%
%        phi_{o,i}(x) = w_base_{o,i} * SiLU(x)                (残差基)
%                     + sum_k  w_spline_{o,i,k} * RBF_k(x)    (可学习样条)
%
%        RBF_k(x) = exp( -( (x - c_k)^2 ) / (2 h^2) )
%
%   - c_k 为固定网格中心(GridRange 上均匀分布), h 为网格间距;
%   - 输入先经 tanh 压缩到 [-1,1], 使其落入网格有效作用域, 提高稳定性;
%   - 残差 SiLU 项保证即使样条权重为 0 时仍有合理梯度流(KAN 常用技巧)。
%
%   这并非用普通 MLP 冒充 KAN: 每条边都拥有独立、可学习的一维函数,
%   严格体现了 KAN 的"边上可学习一维映射 + 节点求和"结构。
% =========================================================================
% 用法:
%   layer = KANLayer(inDim, outDim, numCenters, 'GridRange',[-1 1], 'Name','kan1');
%   该层可直接放入 dlnetwork 的 layerGraph 中。
% =========================================================================

    properties
        InputDim         % 输入维度 I
        OutputDim        % 输出维度 O
        NumCenters       % 每条边的基函数数量 K
        GridMin          % 网格下界
        GridMax          % 网格上界
        Centers          % 1xK 固定网格中心(非学习)
        H                % 网格间距(标量, 非学习)
    end

    properties (Learnable)
        Wbase            % O x I       残差 SiLU 项权重
        Wspline          % O x I x K   可学习样条(RBF)权重
        Bias             % O x 1       偏置
    end

    methods
        function layer = KANLayer(inDim, outDim, numCenters, varargin)
            % 构造函数
            p = inputParser;
            addParameter(p, 'GridRange', [-1 1]);
            addParameter(p, 'Name', '');
            parse(p, varargin{:});

            layer.InputDim   = inDim;
            layer.OutputDim  = outDim;
            layer.NumCenters = numCenters;
            layer.GridMin    = p.Results.GridRange(1);
            layer.GridMax    = p.Results.GridRange(2);
            layer.Name       = p.Results.Name;
            layer.Description= sprintf('KAN 回归层 (%d -> %d, K=%d)', inDim, outDim, numCenters);
            layer.Type       = 'KANLayer';

            % 固定网格中心与间距
            c = linspace(layer.GridMin, layer.GridMax, numCenters);
            layer.Centers = c;
            if numCenters > 1
                layer.H = (layer.GridMax - layer.GridMin) / (numCenters - 1);
            else
                layer.H = 1;
            end

            % 参数初始化(小幅随机, 利于稳定训练)
            sc = 1 / sqrt(inDim);
            layer.Wbase   = dlarray(sc * randn(outDim, inDim, 'single'));
            layer.Wspline = dlarray(0.1 * sc * randn(outDim, inDim, numCenters, 'single'));
            layer.Bias    = dlarray(zeros(outDim, 1, 'single'));
        end

        function Z = predict(layer, X)
            % 前向传播
            % X : I x B (未格式化或 'CB' 格式 dlarray)
            % Z : O x B
            Z = kanEdgeForward(X, layer.Wbase, layer.Wspline, layer.Bias, ...
                               layer.Centers, layer.H);
        end
    end
end

% ===================== 共享前向计算(供层与函数式模型复用) =====================
function Z = kanEdgeForward(X, Wbase, Wspline, Bias, centers, h)
% X : I x B
    X = stripdims(X);
    I = size(X,1); B = size(X,2); K = numel(centers);

    Xt = tanh(X);                                  % 压缩到 [-1,1]

    % 残差基: SiLU(x) = x .* sigmoid(x)
    silu = Xt .* (1 ./ (1 + exp(-Xt)));            % I x B
    base = Wbase * silu;                           % O x B

    % RBF 样条项
    Xt3 = reshape(Xt, [I, 1, B]);                  % I x 1 x B
    c3  = reshape(centers, [1, K, 1]);             % 1 x K x 1
    rbf = exp( -((Xt3 - c3).^2) / (2*h^2) );       % I x K x B
    rbf2 = reshape(rbf, [I*K, B]);                 % (I*K) x B
    Ws2  = reshape(Wspline, [size(Wspline,1), I*K]);% O x (I*K)
    spline = Ws2 * rbf2;                           % O x B

    Z = base + spline + Bias;                      % O x B
end
