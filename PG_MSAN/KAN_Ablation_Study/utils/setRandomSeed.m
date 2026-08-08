function setRandomSeed(seed)
% setRandomSeed  统一设置随机种子，保证实验可复现
% -------------------------------------------------------------------------
% 输入:
%   seed  : 整数随机种子
% 输出:
%   无（直接设置全局随机数生成器）
% -------------------------------------------------------------------------
% 说明:
%   同时设置 MATLAB 默认随机流以及（若可用）GPU 随机流，保证 CPU/GPU
%   两种训练模式下数据划分、权重初始化等随机过程一致可复现。
% -------------------------------------------------------------------------
    if nargin < 1 || isempty(seed)
        seed = 2024;
    end
    rng(seed, 'twister');                 % 设置 CPU 随机流
    try
        if gpuDeviceCount > 0             %#ok<*GPUDEV>  若存在 GPU 则同步设置
            gpurng(seed, 'Threefry');
        end
    catch
        % 无 GPU 或并行工具箱时忽略
    end
    fprintf('[setRandomSeed] 随机种子已设置为 %d\n', seed);
end
