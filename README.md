# Traffic Data Analysis for Modelling and Prediction of Traffic Scenarios

Solution to **MathWorks Challenge Project 222** (MATLAB / Simulink).
Authors: Paras Shah (24108B0019), Yash Khanvilkar (24108B0021), Shravani saravade (24108B0015), Gunjan Tale (24108B0025), Pushkaraj Kadam (24108B0016)  |  Institution: Vidyalankar Institute of Technology, Mumbai  |  Guide: Sheetal Patil

## What it does
Predicts what a vehicle is about to do (Slow-Down, Speed-Up, Turn, Smooth-Turn, Left-Turn, Right-Turn, Traffic-Light, Loop, Other, Jiggling) from its speed, acceleration, heading and heading change, using a NARX time-series neural network trained on the DACT car-trajectory dataset (50 trips; 25,994 rows used for the network).

Beyond the starting solution (see Credits) this repository adds:
1. **Evaluation:** test-only error, accuracy, confusion matrix, per-class scores, a copy-previous-label baseline and a closed-loop check.
2. **Simulink:** the trained network run on real data (27 steps) through From Workspace blocks.
3. **Driving-style clustering (advanced objective):** k-means, Gaussian mixture and hierarchical clustering of trips; 3 clusters found.
4. **V2V rule table:** 18-case behaviour table from the original report, including a rear-end-risk alert for the case the report left undefined.

## Repository layout
| Folder | Contents |
|---|---|
| `code/` | MATLAB scripts, `untitled.slx` and the data files they load (scripts expect the data in the same folder) |
| `results/` | screenshots, figures and output CSV files |
| `original/` | files from the starting solution, with its licence |

## Requirements
MATLAB R2021a or later (tested on R2025b) with Deep Learning Toolbox, Statistics and Machine Learning Toolbox and Simulink.

## How to run
Make `code/` the current folder, then run each script as a whole file, in this order:
1. `Code_NARXnet_Evaluated.m` - trains and evaluates the NARX network (about 30 s, fixed seed).
2. `RunFullPipeline.m` - runs `untitled.slx` on the demo data and prints predicted behaviours.
3. `V2V_BehaviourMapping.m` - run straight after step 2 (it uses its predictions).
4. `DrivingStyleClustering.m` - clustering figures and `trip_features_zscored.csv`.

`FixSimulinkModel.m` tidies the Simulink model (explicit sample times); it is run once.

## Results (seed 1)
| Measure | Value |
|---|---|
| Test MSE / RMSE / MAE | 0.0101 / 0.1005 / 0.0227 |
| Accuracy (test / all rows) | 94.4% / 94.6% |
| Macro F1 (test) | 0.73 |
| Copy-previous-label baseline (test) | 95.2% accuracy |
| Closed-loop accuracy | 25.9% |
| Driving-style clusters | 3 (10, 12, 28 trips) |
| V2V rule table | 18 of 18 cases correct |

## Limitations
- The network is given the true previous label, so it mostly carries it forward; it does not beat the copy-previous-label baseline and predicts no label changes.
- Left-Turn and Right-Turn (21 and 12 test rows) are never recognised.
- The Simulink demo output follows its feedback input one step later; it shows the network running on streaming data, not independent forecasting.
- Clustering uses only 50 trips and is exploratory.
- The V2V demo uses a time-shifted copy as the second vehicle and a constructed distance profile; it is not a validation on real traffic.
- The script that builds `NN-IN.xlsx` and `NN-TARG.csv` from the raw DACT data is not part of the starting solution.

## Data
DACT: Dataset of Annotated Car Trajectories (Moosavi et al.), https://figshare.com/articles/dataset/DACT_Dataset_of_Annotated_Car_Trajectories/5005289

The DACT CSV files are **not included** in this repository. For `DrivingStyleClustering.m`, download `DACTStrictDataset.csv` from the link above and place it in `code/`. The NARX scripts only need the smaller files already in `code/` (`NN-IN.xlsx`, `NN-TARG.csv`, `X-Input.xlsx`, `Y-FeedBack.csv`).

If you use the dataset, please cite: S. Moosavi et al., "Trajectory Annotation by Discovering Driving Patterns", UrbanGIS 2017.

## Credits and licence
Builds on the public repository **Project222** by Girolamo Oddo (MIT licence, 2022), a solution to the same MathWorks project. The files in `original/` are his; the evaluation, Simulink run, clustering and V2V code are ours. Released under the MIT licence; see `LICENSE` (it keeps the original copyright notice).
