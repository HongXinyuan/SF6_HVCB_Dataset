function [Rpred, alpha, beta, dR] = applyCalibrationHead(Y, Ra, Min, cfg)
% applyCalibrationHead  把网络原始输出映射为 (alpha, beta, DeltaR) 并计算
%                       校准曲线，显式实现校准公式：

dRraw = Y(1, :, :);
araw  = Y(2, :, :);
braw  = Y(3, :, :);

% ---- 有效掩码加权时间平均（每条曲线得到一个标量原始值） ----
denom = max(sum(Min, 3), 1);                      % 防止除零
aMean = sum(araw .* Min, 3) ./ denom;             % 1 x B
bMean = sum(braw .* Min, 3) ./ denom;             % 1 x B

% ---- tanh 限幅映射到物理可解释范围（归一化量纲） ----
alpha = 1 + cfg.alphaRange * tanh(aMean);         % 1 x B，约 1±alphaRange
beta  =     cfg.betaRange  * tanh(bMean);         % 1 x B
dR    =     cfg.deltaScale * tanh(dRraw);         % 1 x B x T

% ---- 显式按校准公式合成预测曲线（alpha/beta 沿时间维隐式广播） ----
Rpred = alpha .* Ra + beta + dR;
end
