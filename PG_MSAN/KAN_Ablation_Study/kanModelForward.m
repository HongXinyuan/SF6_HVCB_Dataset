function [pred, aux] = kanModelForward(model, Xc, Xf)
% kanModelForward  KAN 回归模型前向传播(函数式, 供训练与预测共用)
% -------------------------------------------------------------------------

    P = model.learn;
    Fx = model.fixed;

    %% ---- 1) 曲线编码器: 三层 1D 卷积(stride=2 下采样) ----
    h = dlconv(Xc, P.enc.c1w, P.enc.c1b, 'DataFormat','SCB', 'Stride',2, 'Padding','same');
    h = relu(h);
    h = dlconv(h, P.enc.c2w, P.enc.c2b, 'DataFormat','SCB', 'Stride',2, 'Padding','same');
    h = relu(h);
    h = dlconv(h, P.enc.c3w, P.enc.c3b, 'DataFormat','SCB', 'Stride',2, 'Padding','same');
    h = relu(h);                          % [S' x Clast x B]

    % 平均池化保留整体趋势, 最大池化保留局部峰值响应
    pooledMean = mean(h, 1);
    pooledMax  = max(h, [], 1);
    pooled     = cat(2, pooledMean, pooledMax);
    Cpool      = size(pooled, 2);
    B          = size(pooled, 3);
    pooled     = reshape(pooled, [Cpool, B]);

    curveFeat = relu(P.enc.fcw * pooled + P.enc.fcb);   % Dc x B

    attW = [];
    %% ---- 2) 物理特征分支(可选) ----
    if Fx.usePhysicalFeatures
        ph = relu(P.phys.w1 * Xf + P.phys.b1);
        ph = relu(P.phys.w2 * ph + P.phys.b2);          % Dp x B

        %% ---- 3) 融合 ----
        if Fx.useAttentionFusion
            [fused, attW] = attentionFuse(curveFeat, ph, P.att, ...
                Fx.minCurveAttention);
        else
            fused = [curveFeat; ph];                    % 直接拼接
        end
    else
        fused = curveFeat;                              % 仅曲线特征
    end

    %% ---- 4) KAN 回归头 ----
    z = kanForward(fused, P.kan1, Fx.centers, Fx.h);    % H x B
    z = relu(z);                                        % 层间非线性
    z = kanForward(z,     P.kan2, Fx.centers, Fx.h);    % 1 x B

    pred = z;                                           % 1 x B (标准化空间)

    aux = struct('attW', attW, 'fused', fused, 'curveFeat', curveFeat);
end

% ===================== 局部函数: KAN 单层前向(RBF 可学习样条) =====================
function y = kanForward(z, Pk, centers, h)
% z : I x B ; Pk: 含 Wbase[O x I], Wspline[O x I x K], Bias[O x 1]
    z = stripdims(z);
    I = size(z,1); B = size(z,2); K = numel(centers);

    zt = tanh(z);                                  % 压缩到 [-1,1]

    % 残差基: SiLU(x) = x * sigmoid(x)
    silu = zt .* (1 ./ (1 + exp(-zt)));            % I x B
    base = Pk.Wbase * silu;                        % O x B

    % RBF 样条项
    zt3 = reshape(zt, [I, 1, B]);                  % I x 1 x B
    c3  = reshape(centers, [1, K, 1]);             % 1 x K x 1
    rbf = exp( -((zt3 - c3).^2) / (2*h^2) );       % I x K x B
    rbf2 = reshape(rbf, [I*K, B]);                 % (I*K) x B
    Ws2  = reshape(Pk.Wspline, [size(Pk.Wspline,1), I*K]);  % O x (I*K)
    spline = Ws2 * rbf2;                           % O x B

    y = base + spline + Pk.Bias;                   % O x B
end

% ===================== 局部函数: 多源注意力融合 =====================
function [fused, alpha] = attentionFuse(curveFeat, ph, A, minCurveAttention)
    pc = A.pc * curveFeat;                % d x B
    pp = A.pp * ph;                       % d x B

    % 统一两个投影分支的尺度, 避免向量幅值绕过注意力权重
    pc = normalizeBranch(pc);
    pp = normalizeBranch(pp);

    hc = tanh(A.W * pc + A.bw);
    hp = tanh(A.W * pp + A.bw);
    ec = A.v.' * hc;                      % 1 x B
    ep = A.v.' * hp;                      % 1 x B

    E = [ec; ep];                         % 2 x B
    E = E - max(E, [], 1);
    expE = exp(E);
    alphaRaw = expE ./ sum(expE, 1);      % 2 x B

    % 保证曲线权重不低于设定下限, 同时保持两项权重之和为 1
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
