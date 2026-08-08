classdef AttentionFusionLayer < nnet.layer.Layer
% AttentionFusionLayer  多源注意力融合层 (曲线特征 + 物理特征)
% =========================================================================
% 作用:
%   在"曲线深层特征"与"物理特征"两个来源之间, 计算自适应注意力权重,
%   并按权重加权融合, 得到统一表征。相比简单拼接, 注意力融合可让模型
%   根据样本动态地强调更可靠的信息来源。
%
% 计算流程(两个来源 s ∈ {curve, phys}):
%   1) 线性投影到公共维度 d:   p_s = Wproj_s * f_s
%   2) 打分:  e_s = v^T * tanh( Wa * p_s + ba )
%   3) 归一化: alpha = softmax([e_curve, e_phys])
%   4) 融合:   fused = alpha_curve * p_curve + alpha_phys * p_phys
%
%   注意力权重 alpha 可输出用于可视化。
% =========================================================================
% 说明:
%   本类作为"可放入 dlnetwork 的等价实现"提供; 主训练流程中的等价数学
%   在 kanModelForward.m 内以函数式实现, 二者数学一致。
% =========================================================================

    properties
        CurveDim     % 曲线特征维度 Dc
        PhysDim      % 物理特征维度 Dp
        FuseDim      % 融合公共维度 d
        MinCurveAttention % 曲线注意力权重硬下限
    end

    properties (Learnable)
        WprojCurve   % d x Dc
        WprojPhys    % d x Dp
        Wa           % d x d
        ba           % d x 1
        v            % d x 1
    end

    methods
        function layer = AttentionFusionLayer(curveDim, physDim, fuseDim, name, minCurveAttention)
            if nargin < 4; name = ''; end
            if nargin < 5; minCurveAttention = 0.65; end
            layer.CurveDim = curveDim;
            layer.PhysDim  = physDim;
            layer.FuseDim  = fuseDim;
            layer.MinCurveAttention = minCurveAttention;
            layer.Name     = name;
            layer.Description = sprintf('多源注意力融合 (Dc=%d,Dp=%d->d=%d)', curveDim, physDim, fuseDim);
            layer.Type     = 'AttentionFusionLayer';
            layer.NumInputs = 2;   % 接收 [curveFeat, physFeat]

            sc = @(n) 1/sqrt(n);
            layer.WprojCurve = dlarray(sc(curveDim)*randn(fuseDim, curveDim,'single'));
            layer.WprojPhys  = dlarray(sc(physDim) *randn(fuseDim, physDim, 'single'));
            layer.Wa = dlarray(sc(fuseDim)*randn(fuseDim, fuseDim,'single'));
            layer.ba = dlarray(zeros(fuseDim,1,'single'));
            layer.v  = dlarray(sc(fuseDim)*randn(fuseDim,1,'single'));
        end

        function Z = predict(layer, curveFeat, physFeat)
            [Z, ~] = attentionFuseCore(curveFeat, physFeat, ...
                layer.WprojCurve, layer.WprojPhys, layer.Wa, layer.ba, layer.v, ...
                layer.MinCurveAttention);
        end
    end
end

% ===================== 共享融合核心(供层与函数式模型复用) =====================
function [fused, alpha] = attentionFuseCore(curveFeat, physFeat, WpC, WpP, Wa, ba, v, minCurveAttention)
    curveFeat = stripdims(curveFeat);
    physFeat  = stripdims(physFeat);

    pc = WpC * curveFeat;                 % d x B
    pp = WpP * physFeat;                  % d x B
    pc = normalizeBranch(pc);
    pp = normalizeBranch(pp);

    hc = tanh(Wa * pc + ba);             % d x B
    hp = tanh(Wa * pp + ba);
    ec = v.' * hc;                        % 1 x B
    ep = v.' * hp;                        % 1 x B

    E = [ec; ep];                         % 2 x B
    E = E - max(E, [], 1);                % 数值稳定
    expE = exp(E);
    alphaRaw = expE ./ sum(expE, 1);      % 2 x B (各源权重)
    rho = min(max(minCurveAttention, 0), 1);
    alpha = [rho + (1-rho).*alphaRaw(1,:); ...
             (1-rho).*alphaRaw(2,:)];

    fused = alpha(1,:) .* pc + alpha(2,:) .* pp;   % d x B
end

function x = normalizeBranch(x)
    mu = mean(x, 1);
    x = x - mu;
    x = x ./ sqrt(mean(x.^2, 1) + single(1e-5));
end
