function net = buildTransformerModel(cfg)
% buildTransformerModel  构建用于动态电阻曲线校准的 Transformer 编码器网络

H = cfg.hiddenSize;
assert(mod(H, cfg.numHeads) == 0, ...
    'cfg.hiddenSize(%d) 必须能被 cfg.numHeads(%d) 整除。', H, cfg.numHeads);

lg = layerGraph();

% ---- (1) 输入与嵌入 ----
% 'Normalization','none'：归一化已在数据准备阶段完成（R/10、时间归一化）。
lg = addLayers(lg, [
    sequenceInputLayer(cfg.numInputChannels, 'Normalization', 'none', ...
                       'Name', 'input')
    fullyConnectedLayer(H, 'Name', 'embed_fc')]);

usePos = cfg.usePositionEmbedding && exist('positionEmbeddingLayer', 'file') > 0;
if usePos
    % 可学习位置嵌入：与嵌入向量逐元素相加
    lg = addLayers(lg, positionEmbeddingLayer(H, cfg.N, 'Name', 'pos_emb'));
    lg = addLayers(lg, additionLayer(2, 'Name', 'embed_add'));
    lg = addLayers(lg, dropoutLayer(cfg.dropout, 'Name', 'embed_drop'));
    lg = connectLayers(lg, 'embed_fc', 'pos_emb');
    lg = connectLayers(lg, 'embed_fc', 'embed_add/in1');
    lg = connectLayers(lg, 'pos_emb',  'embed_add/in2');
    lg = connectLayers(lg, 'embed_add', 'embed_drop');
else
    if cfg.usePositionEmbedding
        fprintf(['  提示：当前 MATLAB 版本无 positionEmbeddingLayer（需 R2023b+），', ...
                 '已退化为无位置嵌入（时间通道仍提供位置信息）。\n']);
    end
    lg = addLayers(lg, dropoutLayer(cfg.dropout, 'Name', 'embed_drop'));
    lg = connectLayers(lg, 'embed_fc', 'embed_drop');
end
prev = 'embed_drop';

% ---- (2) Transformer 编码器块（Pre-LN 残差结构） ----
hasGelu = exist('geluLayer', 'file') > 0;
for i = 1:cfg.numBlocks
    pre = sprintf('blk%d_', i);

    % --- 子层 1：LayerNorm -> 多头自注意力 -> Dropout，再与块输入残差相加 ---
    lg = addLayers(lg, [
        layerNormalizationLayer('Name', [pre 'ln1'])
        selfAttentionLayer(cfg.numHeads, H, 'Name', [pre 'attn'])
        dropoutLayer(cfg.dropout, 'Name', [pre 'drop1'])]);
    lg = addLayers(lg, additionLayer(2, 'Name', [pre 'add1']));
    lg = connectLayers(lg, prev, [pre 'ln1']);
    lg = connectLayers(lg, [pre 'drop1'], [pre 'add1/in1']);
    lg = connectLayers(lg, prev, [pre 'add1/in2']);

    % --- 子层 2：LayerNorm -> FFN(GELU/ReLU) -> Dropout，再残差相加 ---
    if hasGelu
        act = geluLayer('Name', [pre 'act']);
    else
        act = reluLayer('Name', [pre 'act']);   % 旧版本退化方案
    end
    lg = addLayers(lg, [
        layerNormalizationLayer('Name', [pre 'ln2'])
        fullyConnectedLayer(cfg.ffnSize, 'Name', [pre 'ffn1'])
        act
        fullyConnectedLayer(H, 'Name', [pre 'ffn2'])
        dropoutLayer(cfg.dropout, 'Name', [pre 'drop2'])]);
    lg = addLayers(lg, additionLayer(2, 'Name', [pre 'add2']));
    lg = connectLayers(lg, [pre 'add1'], [pre 'ln2']);
    lg = connectLayers(lg, [pre 'drop2'], [pre 'add2/in1']);
    lg = connectLayers(lg, [pre 'add1'],  [pre 'add2/in2']);

    prev = [pre 'add2'];               % 下一块的输入
end

% ---- (3) 输出头：LayerNorm -> 全连接到 3 通道（DeltaR/alpha/beta 原始值） ----
lg = addLayers(lg, [
    layerNormalizationLayer('Name', 'final_ln')
    fullyConnectedLayer(3, 'Name', 'head')]);
lg = connectLayers(lg, prev, 'final_ln');

% ---- (4) 转为 dlnetwork 并初始化权重 ----
net = dlnetwork(lg);
if ~net.Initialized
    net = initialize(net);
end
end
