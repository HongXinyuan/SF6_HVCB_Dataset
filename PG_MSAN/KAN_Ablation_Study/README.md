# PG_MSAN_KAN — SF6 断路器分闸动态电阻曲线触头长度反演 (KAN 回归)

基于 **KAN (Kolmogorov–Arnold Network)** 的深度学习回归工程，用于从 SF6 断路器
**分闸阶段动态电阻曲线**反演**触头长度 (mm)**。
完整复现深度学习论文实验流程

---

## 1. 环境要求
- MATLAB R2021a 及以上（需 **Deep Learning Toolbox**，使用 `dlarray` / `dlfeval` /
  `dlgradient` / `dlconv` / `adamupdate`）。


## 2. 数据准备
将 5 类数据集文件夹放在同一根目录下（默认）：

```
C:\Users\Admin\Desktop\PG_MSAN\Database\
├── Dr_Real_Erosion_Dataset\        % 真实烧蚀（标签真值，最接近真实工况）
├── Da_Artificial_Dataset\          % 人工定制
├── Ds_Simulation_Dataset\          % 仿真
├── Da~_Artificial-to-Real_Dataset\ % 人工→真实 修正
└── Ds~_Simulation-to-Real_Dataset\ % 仿真→真实 修正
```
> **关键清洗规则**：动态电阻 `R >= 10 mΩ` 为采样截断值（电阻趋于无穷，无物理意义），


## 3. 运行
在 MATLAB 中打开工程根目录，直接运行：

```matlab
main
```

`main.m` 会自动：加入子目录路径 → 读取配置 → 设随机种子 → 读取并清洗数据 →
划分数据集 → 构建并训练 KAN 模型 → 在训练/验证/测试集评估 → 出图 → 保存结果。

## 4. 切换消融实验 M1~M8
只需修改 `main.m` 顶部的一行：

```matlab
experimentName = "M1";   % 改成 "M2" ... "M8" 即可
```

| 实验 | 训练数据 | 修正 | 物理特征 | 注意力 | 损失 | 目的 |
|----|----------|----|--------|------|------|------|
| M1 | Dr | 否 | 是 | 是 | Lreg | 真实数据基准（默认） |
| M2 | Da | 否 | 是 | 是 | Lreg | 人工数据基准 |
| M3 | Ds | 否 | 是 | 是 | Lreg | 仿真数据基准 |
| M4 | Dr+Da+Ds | 否 | 是 | 是 | Lreg | 直接融合对比 |
| M5 | Dr+Da~+Ds~ | 是 | 否 | 否 | Lreg | 只验证修正融合 |
| M6 | Dr+Da~+Ds~ | 是 | 是 | 否 | Lreg | 验证物理特征 |
| M7 | Dr+Da~+Ds~ | 是 | 是 | 是 | Lreg | 验证注意力模块 |
| M8 | Dr+Da~+Ds~ | 是 | 是 | 是 | Full | 完整模型 |

所有实验配置集中在 `getExperimentConfig.m`。


## 5. 单条曲线预测

```matlab
cfg = getExperimentConfig("M1");
modelPath = fullfile(cfg.modelDir, 'model_M1.mat');

% (a) 输入 .dat 文件
out = predictSingleCurve(modelPath, 'C:\path\to\281.39mm.dat', cfg);

% (b) 输入两列表格 [时间(ms), 电阻(mΩ)]
out = predictSingleCurve(modelPath, [t(:), r(:)], cfg);

disp(out.predLength);   % 预测触头长度 (mm)
% out 还含 Rmax / tpeak / Rmean / Smax / AR / Dlow / Cas 等中间量
```

## 6. 输出位置
```
results/
├── figures/      % 损失曲线、真实-预测散点、误差直方图、逐样本误差、
│                 % 多源曲线对比、Rmax 标注图、特征相关性热力图、注意力权重图、消融对比图
├── metrics/      % metrics_<Mx>.txt / .csv，ablation_summary_*.csv
├── models/       % model_<Mx>.mat（含标准化统计、cfg、Cas 模板），split_<Mx>.mat
└── predictions/  % test_predictions.csv；batch_single_curve_predictions_<Mx>.csv/.mat
                  % （逐样本：数据子集/真值/预测/绝对误差/相对误差）
```

## 7. 模型结构
```
动态电阻曲线 → 1D-CNN 编码器(3 层, stride-2, 全局平均池化, FC)
            → 物理特征 MLP 分支(可选)
            → 多源注意力融合(可选, 否则拼接, 否则仅曲线)
            → KAN 回归头(两层) → 触头长度
```

**KAN 回归头**采用 RBF / FastKAN 形式（"KAN are RBF Networks"）实现可学习样条：
每条边
`φ(x) = w_base·SiLU(x) + Σ_k w_spline_k · RBF_k(x)`，
`RBF_k(x) = exp(-(x-c_k)² / (2h²))`，输入经 `tanh` 压缩到网格区间 `[-1, 1]`，
节点输出为各输入边之和。这是对 B-spline KAN 的光滑、可微、数值稳定的等价近似，


## 8. 损失
- `Lreg`：标准化长度上的 MSE（默认）或 MAE。M1~M7 使用。
- `Full = Lreg + λ1·Lalign + λ2·Lmono`（M8）：
  - `Lalign`：真实域与修正域特征分布对齐（CORAL/MMD/均值对齐），见 `computeAlignmentLoss.m`。
  - `Lmono`：物理单调约束（触头越短烧蚀越强）的 pairwise hinge 排序损失，见 `computeMonotonicLoss.m`。
  - 默认 `λ1 = 0.1`，`λ2 = 0.01`。

## 9. 工程结构
见任务说明第十三节；核心入口 `main.m`，配置中枢 `getExperimentConfig.m`，
共享前向 `kanModelForward.m`（训练与预测复用）。