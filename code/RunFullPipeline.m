%% Run Full Pipeline — one script, no manual Simulink clicking needed
% Builds inputs, runs untitled.slx via sim(), and extracts predicted
% behavior labels, all in a single execution so nothing gets lost
% between steps.

clear; clc; % start clean every time -- intentional here, unlike other scripts

%% 1. Build Simulink input timeseries
xData = readmatrix('X-Input.xlsx');
yData = readmatrix('Y-FeedBack.csv');
ts = (0:size(xData,1)-1)';
x1_ts = timeseries(xData, ts);
x2_ts = timeseries(yData, ts);
fprintf('Loaded %d timesteps.\n', size(xData,1));

%% 2. Run the Simulink model directly (no GUI clicking required)
out = sim('untitled');
fprintf('Simulink run complete.\n');

%% 3. Extract predicted behavior labels
labels = ["Slow-Down","Speed-Up","Turn","Smooth-Turn","Left-Turn", ...
          "Right-Turn","Traffic-Light","Loop","Other","Jiggling"];

[~, predIdx] = max(out.simOut, [], 2);
predictedBehavior = labels(predIdx)';

fprintf('\n--- Predicted Behavior Sequence ---\n');
disp(table((1:numel(predictedBehavior))', predictedBehavior, ...
    'VariableNames', {'Timestep','PredictedBehavior'}));

fprintf('\npredictedBehavior is now ready in the workspace.\n');
fprintf('You can now run V2V_BehaviourMapping.m directly.\n');
