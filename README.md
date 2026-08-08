# SF6 HVCB Dataset and PG-MSAN

This repository releases part of the code and data associated with a non-intrusive method for estimating the remaining arcing-contact length of high-voltage SF6 circuit breakers (HVCBs) from dynamic resistance measurement (DRM) curves.
The main contribution released here is the **Physics-Guided Multi-Source Attention Network (PG-MSAN)**. 

## Repository Structure

```text
SF6_HVCB_Dataset/
├── DRM_Simulation/                 # Selected simulation-related source files
│   ├── ABAQUS/                     # ABAQUS scripts and user subroutines
│   ├── ANSYS_UDF/                   # ANSYS Fluent UDF implementations
│   └── Material_Parameters/         # SF6/Cu material-property files
├── PG_MSAN/                         # Main dataset and learning framework
│   ├── Database/                    # Original, calibrated, and derived DRM data
│   ├── Transformer_Network/         # Real-domain DRM calibration
│   ├── KAN_Ablation_Study/          # Length inversion and M1-M8 ablations
│   ├── corrBubblePlotXLSX.m          # Correlation bubble-plot utility
│   └── Correlation_coefficient.xlsx
└── Raw_Data_Others/                 # Other interruption-related raw data
```

## PG-MSAN

### Research Objective

- **Artificial contact data:** measurements from machined, smooth arcing contacts with explicit and controllable length labels.
- **Simulation contact data:** DRM curves generated from a physics-based workflow involving arc-erosion modeling, thermo-mechanical contact analysis, and Holm contact-resistance theory.

These additional sources improve coverage of the common degradation range, but they do not follow exactly the same distribution as the experimentally eroded contacts. Fabricated contacts do not fully reproduce the rough morphology, oxide-film state, and stochastic contact behavior caused by real arc erosion. Simulation errors may also accumulate through material assumptions, boundary conditions, geometry degradation, contact analysis, and resistance calculation. PG-MSAN is designed to use these complementary data while reducing their domain discrepancies.

### Data Domains

| Symbol | Directory | Samples | Length range | Description |
|---|---|---:|---:|---|
| $D_r$ | `Dr_Real_Erosion_Dataset` | 11 | 281.39-291.04 mm | DRM curves from contacts eroded in actual short-circuit interruption tests; treated as the real domain. |
| $D_a$ | `Da_Artificial_Dataset` | 18 | 278-291.5 mm | DRM curves from fabricated smooth contacts with controlled lengths. |
| $D_s$ | `Ds_Simulation_Dataset` | 136 | 278-291.5 mm | Physics-based simulated DRM curves with continuous length labels. |
| $\widetilde{D}_a$ | `Da~_Artificial-to-Real_Dataset` | 18 | 278-291.5 mm | Fabricated-contact curves calibrated toward the real domain. |
| $\widetilde{D}_s$ | `Ds~_Simulation-to-Real_Dataset` | 136 | 278-291.5 mm | Simulation curves calibrated toward the real domain. |

Each `.dat` file contains two columns:

1. time in milliseconds;
2. dynamic resistance in milliohms.

The contact-length label is encoded in the filename. For example, `281.39mm.dat` corresponds to a remaining contact length of 281.39 mm.

Dynamic-resistance values at or above 10 mOhm are treated as acquisition truncation values and excluded from training, feature extraction, peak detection, and evaluation.

### Part I: Real-Domain Calibration

The code in `PG_MSAN/Transformer_Network/` calibrates $D_a$ and $D_s$ toward $D_r$ using a Transformer-based residual model. For an input curve $R(t)$, the calibration follows

$$
\widetilde{R}(t)=\alpha R(t)+\beta+\Delta R(t),
$$

where $\alpha$ and $\beta$ correct the global scale and offset, while the time-varying residual $\Delta R(t)$ compensates for nonlinear local discrepancies. Residual-magnitude and residual-smoothness regularization limit excessive reconstruction so that the original degradation trend is retained.

The fabricated-to-real branch applies conservative correction because $D_a$ and $D_r$ share the same measurement circuit, mechanical operation, and sampling procedure. The simulation-to-real branch handles the larger shift introduced by the multiphysics simulation chain while preserving the simulated degradation trend.

The calibration workflow includes data cleaning, valid-segment resampling, nearest-length target construction, Transformer training, corrected `.dat` export, feature comparison, curve-level metrics, and result visualization. See `PG_MSAN/Transformer_Network/README.md` for file-level details.

### Part II: Contact-Length Inversion

The code in `PG_MSAN/KAN_Ablation_Study/` performs contact-length inversion from $D_r$, $\widetilde{D}_a$, and $\widetilde{D}_s$. Its main components are:

1. **Temporal encoder:** a three-layer one-dimensional CNN extracts representations from the resampled DRM sequence.
2. **Physics-guided feature branch:** seven features describe resistance intensity, contact evolution, and waveform similarity:
   - $R_{\max}$: resistance at the first peak;
   - $R_{\mathrm{mean}}$: mean resistance;
   - $S_{\max}$: maximum slope;
   - $A_R$: area under the DRM curve;
   - $t_{\mathrm{peak}}$: time of the first peak;
   - $D_{\mathrm{low}}$: local low-resistance duration;
   - $C_{\mathrm{as}}$: cosine similarity to the real-domain reference template.
3. **Multi-source attention fusion:** temporal and physical representations are adaptively weighted to combine the reliability of real data, the label controllability of fabricated data, and the physical prior supplied by simulation.
4. **KAN regression head:** a two-layer Kolmogorov-Arnold Network implemented with smooth RBF/FastKAN basis functions predicts the remaining contact length.

The complete M8 model is optimized using

$$
\mathcal{L}=\mathcal{L}_{\mathrm{reg}}+\lambda_{\mathrm{align}}\mathcal{L}_{\mathrm{align}}+\lambda_{\mathrm{mono}}\mathcal{L}_{\mathrm{mono}},
$$

where $\mathcal{L}_{\mathrm{reg}}$ is the length-regression loss, $\mathcal{L}_{\mathrm{align}}$ aligns real and calibrated feature distributions, and $\mathcal{L}_{\mathrm{mono}}$ enforces the physical trend that more severely eroded contacts have shorter remaining lengths.

### Ablation Configurations

| Model | Training data | Calibrated data | Physical features | Attention | Loss |
|---|---|---|---|---|---|
| M1 | $D_r$ | No | Yes | Yes | $\mathcal{L}_{\mathrm{reg}}$ |
| M2 | $D_a$ | No | Yes | Yes | $\mathcal{L}_{\mathrm{reg}}$ |
| M3 | $D_s$ | No | Yes | Yes | $\mathcal{L}_{\mathrm{reg}}$ |
| M4 | $D_r+D_a+D_s$ | No | Yes | Yes | $\mathcal{L}_{\mathrm{reg}}$ |
| M5 | $D_r+\widetilde{D}_a+\widetilde{D}_s$ | Yes | No | No | $\mathcal{L}_{\mathrm{reg}}$ |
| M6 | $D_r+\widetilde{D}_a+\widetilde{D}_s$ | Yes | Yes | No | $\mathcal{L}_{\mathrm{reg}}$ |
| M7 | $D_r+\widetilde{D}_a+\widetilde{D}_s$ | Yes | Yes | Yes | $\mathcal{L}_{\mathrm{reg}}$ |
| M8 | $D_r+\widetilde{D}_a+\widetilde{D}_s$ | Yes | Yes | Yes | Full joint loss |

The supplied M8 test results are:

| $R^2$ | RMSE | MAE | MaxAE |
|---:|---:|---:|---:|
| 0.9959 | 0.2567 mm | 0.1765 mm | 0.7839 mm |

These values correspond to the included experiment outputs and may vary slightly when the model is retrained because of software, hardware, and numerical differences.

## Requirements

- **Transformer calibration:** MATLAB R2023a or later and Deep Learning Toolbox (`selfAttentionLayer` is required).
- **KAN inversion and ablation study:** MATLAB R2021a or later and Deep Learning Toolbox.
- ANSYS and ABAQUS are required only for users who wish to adapt the released simulation-related files to their own numerical models.

## Quick Start

### 1. Use the Included Calibrated Data

The repository already includes $\widetilde{D}_a$ and $\widetilde{D}_s$. To train or evaluate the complete inversion model:

1. Open `PG_MSAN/KAN_Ablation_Study/getExperimentConfig.m` and set `cfg.dataRoot` to the local `PG_MSAN/Database` directory.
2. Open `PG_MSAN/KAN_Ablation_Study/main.m` and set:

   ```matlab
   experimentName = "M8";
   ```

3. Run from MATLAB:

   ```matlab
   main
   ```

Results are written to `PG_MSAN/KAN_Ablation_Study/results/`, including figures, metrics, trained models, data splits, and predictions.

### 2. Reproduce the Calibration Stage

To retrain the Transformer calibration model, edit the path definitions at the beginning of `PG_MSAN/Transformer_Network/main.m`:

- set `dbDir` to the local `PG_MSAN/Database` directory;
- select either `Da_Artificial_Dataset` or `Ds_Simulation_Dataset` as the source directory;
- set the matching calibrated output directory and model/output filenames;
- run `main.m` once for each source domain.

The current script is configured for the simulation-to-real branch by default. Change the source and output paths to run the fabricated-to-real branch.

### 3. Run the Ablation Study

Change `experimentName` in `PG_MSAN/KAN_Ablation_Study/main.m` from `"M1"` through `"M8"`, then run `main` for each configuration. After the required experiments are available, generate a comparison with:

```matlab
cfg = getExperimentConfig("M1");
plotAblationComparison(cfg, 'Test');
```

## DRM Simulation Files

The complete ANSYS and ABAQUS numerical models are confidential and are not included in this public release. `DRM_Simulation/` provides only selected files used in the calculations, including ANSYS UDF source code, ABAQUS scripts/user subroutines, and representative SF6/Cu material-property definitions. These files must be adapted to the user's own geometry, mesh, boundary conditions, solver settings, and software environment.

## Other Raw Data

`Raw_Data_Others/` contains additional data related to circuit-breaker interruption, including electrical voltage/current records, travel curves, and multi-channel acoustic/voiceprint signals. `Data_Extract.m` is provided to assist with extracting the dense travel and electrical records. The files are released as recorded and may require filtering, validation, and application-specific preprocessing.

## Data and Reproducibility Notes

- The real erosion dataset was obtained from short-circuit interruption tests on a 252-kV SF6 circuit breaker at 10-40 kA.
- The default training/validation/test split is 70%/15%/15%, with a fixed random seed in the experiment configuration.
- The $C_{\mathrm{as}}$ reference template is constructed only from training-set $D_r$ samples and is then fixed for training, validation, testing, and single-curve inference.
- Paths in the MATLAB entry-point files are examples and must be changed for the local environment.
- Raw measurements may contain noise and experimental fluctuations; users are responsible for validating the data for their intended application.

## Citation

If you use this repository, please cite the associated paper. The complete citation can be added here after publication.

## Disclaimer

This repository is intended for academic research and reproducibility. The released models, code, and data do not replace manufacturer inspection procedures or qualified engineering assessment of operating high-voltage equipment.
