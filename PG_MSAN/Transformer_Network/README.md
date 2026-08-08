# SF6 断路器触头动态电阻曲线 Transformer 校准程序

将人工制造触头（未烧蚀、表面光滑）的动态电阻曲线，通过 Transformer 网络进行
domain adaptation / bias correction，使其更接近真实电弧烧蚀触头的动态电阻特征。

校准结构显式遵循公式：

    R_a_tilde(t) = alpha * R_a(t) + beta + DeltaR_a(t)

其中 alpha 为幅值缩放因子、beta 为偏置因子（均为每条曲线一个标量，由网络输出
经有效掩码平均与 tanh 限幅得到），DeltaR_a(t) 为 Transformer 学习的逐点残差项。

## 一、文件结构

| 文件 | 功能 |
| --- | --- |
| main.m | 主程序：路径与参数集中定义，串联全部流程 |
| loadDRDataset.m | 读取文件夹内所有 .dat 数据并清洗 |
| parseLengthFromFilename.m | 从文件名（如 278.5mm.dat）解析触头长度 |
| cleanDRData.m | 数据清洗：剔除 NaN/Inf、时间单调化、生成 R<10 有效掩码、可选平滑 |
| findValidRuns.m | 查找有效连续段（辅助函数） |
| interpValidSegments.m | 仅在有效段内插值，绝不跨越 R≥10 截断区（辅助函数） |
| resampleDRCurve.m | 统一时间网格重采样（N = 512，可改 1024） |
| buildNearestPairs.m | 最近邻长度配对，加权合成"虚拟真实目标曲线" |
| buildTransformerModel.m | 构建 Transformer 编码器（dlnetwork） |
| applyCalibrationHead.m | 网络输出 → alpha/beta/DeltaR → 校准曲线（辅助函数） |
| trainTransformerCorrectionModel.m | 自定义训练循环（masked MSE + 正则 + 增强 + 早停） |
| predictCorrectedCurve.m | 校准推理，恢复到人工数据原始有效时间点 |
| extractDRFeatures.m | 提取 Rmax/Rmean/Smax/AR/tpeak/Dlow（仅有效区间） |
| computeCurveSimilarity.m | 计算 Cas（余弦相似度）及 RMSE/MAE/相关系数/R²/MAPE/MaxAE/NRMSE/DTW/Fréchet |
| writeCorrectedDatFiles.m | 输出校准后 .dat（文件名与人工数据一一对应） |
| writeAllModifyExcel.m | 输出 AllModify.xlsx 总表 |
| writeFeatureCompareTables.m | 输出每个真实数据对应的特征对比表 |
| writeMeanFeatureTable.m | 输出平均特征总表（含误差改善率） |
| writeCurveMetricsTable.m | 输出曲线校准度量总表 CurveMetricsCompare.xlsx（校准前/后 Cas/Corr/R²/RMSE/MAE/MaxAE/MAPE/NRMSE/DTW/Fréchet 对比） |
| plotResults.m | 绘制 loss、曲线对比、特征误差、Cas 对比图 |

## 二、运行步骤

1. 将本目录下全部 .m 文件放入同一个 MATLAB 工作目录；
2. 打开 main.m，确认/修改文件开头的路径定义（默认按任务给定路径）：
   - realDir、artificialDir、outDir、AllModify.xlsx、FeatureCompare_AllMean.xlsx、
     TransformerCorrectionModel.mat 等均集中在 main.m 第 1 节；
3. 运行 main.m，命令行将逐步打印各阶段信息。

## 三、依赖环境

- MATLAB R2023a 及以上（需要 selfAttentionLayer）；
- 仅依赖 Deep Learning Toolbox（不需要 Signal Processing Toolbox）；

## 四、输出文件

| 输出 | 路径（默认） |
| --- | --- |
| 校准后 .dat 文件 | Database\Da~_Artificial-to-Real_Dataset\ |
| 校准总表 | Database\AllModify.xlsx |
| 逐真实文件特征对比表 | Database\FeatureCompareTables\FeatureCompare_xxx.xlsx |
| 平均特征总表 | Database\FeatureCompare_AllMean.xlsx |
| 曲线校准度量总表 | Database\CurveMetricsCompare.xlsx |
| 训练模型 | Database\TransformerCorrectionModel.mat |
| 结果图（4 张 PNG） | Database\Figures\ |

## 五、关键约定

- R >= 10 mΩ 的点为采样截断点（电阻趋近无穷大），全程视为无效：
  不参与训练、损失、特征提取、积分、检峰、Cas 计算；
  重采样/插值绝不跨越无效区间；输出文件中截断点统一写 10。
- Rmax 指第一波峰（按时间顺序最早出现的显著局部极大值），不是全局最大值。