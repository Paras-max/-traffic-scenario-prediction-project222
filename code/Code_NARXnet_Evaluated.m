% Code_NARXnet_Evaluated.m
% ORIGINAL: Code_NARXnet.m by G. Oddo (kept line by line, in the same order).
% EVERY ADDITION is marked  ">>> ADDED (Tn)"  so you can show what is yours.
% Save in the project folder next to NN-IN.xlsx and NN-TARG.csv, then Run.
% It does NOT overwrite NARXnet_TRAINED.mat.

clear; clc; format long;
rng(1);                      % >>> ADDED (T1): fixed seed -> same result every run

% >>> ADDED (T14, optional switches)
useBlockSplit     = false;   % true = time-ordered split (train = first 70%, test = last 15%)
retrainClosedLoop = false;   % true = retrain the closed-loop net (slower, minutes)

IN = readmatrix('NN-IN.xlsx');
TARG = readmatrix('NN-TARG.csv');

X = tonndata(IN,false,false);
T = tonndata(TARG,false,false);

trainFcn = 'trainscg';       % Scaled conjugate gradient backpropagation.

inputDelays = 1:2;
feedbackDelays = 1:2;
hiddenLayerSize = 10;
net = narxnet(inputDelays,feedbackDelays,hiddenLayerSize,'open',trainFcn);

[x,xi,ai,t] = preparets(net,X,{},T);

net.divideParam.trainRatio = 70/100;
net.divideParam.valRatio  = 15/100;
net.divideParam.testRatio = 15/100;
if useBlockSplit, net.divideFcn = 'divideblock'; end   % >>> ADDED (T14)

tic
[net,tr] = train(net,x,t,xi,ai);
toc

y = net(x,xi,ai);
e = gsubtract(t,y);
performance = perform(net,t,y)      % NOTE: this is the error over ALL rows, not only the test rows

view(net)
figure,  plotperform(tr)
figure,  ploterrhist(e)
figure,  plotregression(t,y)        % >>> ADDED (was commented out in the original)

%% >>> ADDED (T1): test-only metrics, accuracy, confusion matrix, per-class scores
names = ["Slow-Down","Speed-Up","Turn","Smooth-Turn","Left-Turn", ...
         "Right-Turn","Traffic-Light","Loop","Other","Jiggling"];
ti = tr.testInd;                              % indices of the held-out TEST rows
Yt = cell2mat(t);   Yp = cell2mat(y);         % 10 x N  (target, prediction)
[~,truth] = max(Yt,[],1);                     % true class 1..10
[~,pred]  = max(Yp,[],1);                     % predicted class 1..10

testMSE  = mean((Yt(:,ti)-Yp(:,ti)).^2,'all');
testRMSE = sqrt(testMSE);
testMAE  = mean(abs(Yt(:,ti)-Yp(:,ti)),'all');
accAll   = mean(pred==truth)*100;
accTest  = mean(pred(ti)==truth(ti))*100;
fprintf('\nAll-data MSE  : %.6f\n', performance);
fprintf('TEST MSE      : %.6f   RMSE: %.6f   MAE: %.6f\n', testMSE, testRMSE, testMAE);
fprintf('Accuracy all  : %.2f %%    Accuracy TEST: %.2f %%\n', accAll, accTest);

C = confusionmat(truth(ti), pred(ti), 'Order', 1:10);
recall    = diag(C) ./ max(sum(C,2), 1);
precision = diag(C) ./ max(sum(C,1)', 1);
f1        = 2*precision.*recall ./ max(precision+recall, eps);
perClass  = table(names', sum(C,2), recall, precision, f1, ...
            'VariableNames', {'Class','N_test','Recall','Precision','F1'});
disp(perClass)
macroF1 = mean(f1);
fprintf('Macro F1 (test): %.3f\n', macroF1);

figure;
confusionchart(categorical(truth(ti),1:10,cellstr(names)), ...
               categorical(pred(ti), 1:10,cellstr(names)));
title('NARX confusion matrix (test rows)');

% actual vs predicted over the first 300 time steps
nShow = min(300, numel(truth));
figure; plot(truth(1:nShow),'o-'); hold on; plot(pred(1:nShow),'x--'); hold off;
yticks(1:10); yticklabels(names); legend('Actual','Predicted');
xlabel('Time step'); title('Actual vs predicted class (first 300 steps)');

%% >>> ADDED (T2): baseline "copy the previous label" and accuracy on label CHANGES
ti2 = ti(ti > 1);
persAccTest = mean(truth(ti2) == truth(ti2-1))*100;
persMSETest = mean((Yt(:,ti2) - Yt(:,ti2-1)).^2,'all');
persAccAll  = mean(truth(2:end) == truth(1:end-1))*100;
chgIdx  = find(truth(2:end) ~= truth(1:end-1)) + 1;     % rows where the label changes
chgTest = intersect(chgIdx, ti);
accOnChangesAll  = mean(pred(chgIdx)  == truth(chgIdx))*100;
accOnChangesTest = mean(pred(chgTest) == truth(chgTest))*100;   % NaN if no change row is in the test set
fprintf('\nBASELINE copy-previous-label : accuracy test %.2f %%   MSE test %.6f   (all rows %.2f %%)\n', ...
        persAccTest, persMSETest, persAccAll);
fprintf('NARX accuracy on rows where the label CHANGES: all %.2f %% (%d rows), test %.2f %% (%d rows)\n', ...
        accOnChangesAll, numel(chgIdx), accOnChangesTest, numel(chgTest));

%% Closed loop (multi-step prediction) - original code, plus >>> ADDED (T3) numbers
netc = closeloop(net);
netc.name = [net.name ' - Closed Loop'];
[xc,xic,aic,tc] = preparets(netc,X,{},T);
yc = netc(xc,xic,aic);
closedLoopPerformance = perform(netc,tc,yc)      % >>> semicolon removed so it prints
[~,pc]  = max(cell2mat(yc),[],1);
[~,tcl] = max(cell2mat(tc),[],1);
closedLoopAcc = mean(pc==tcl)*100                % >>> ADDED
closedLoopClassesUsed = numel(unique(pc))        % >>> ADDED: 1 means it collapsed to a single class

if retrainClosedLoop                             % >>> ADDED (T14, optional)
    [netc,trc] = train(netc,xc,tc,xic,aic);
    yc = netc(xc,xic,aic);
    closedLoopPerformanceRetrained = perform(netc,tc,yc)
    [~,pc] = max(cell2mat(yc),[],1);
    closedLoopAccRetrained = mean(pc==tcl)*100
end

%% Step-ahead prediction network - original code
nets = removedelay(net);
nets.name = [net.name ' - Predict One Step Ahead'];
[xs,xis,ais,ts] = preparets(nets,X,{},T);
ys = nets(xs,xis,ais);
stepAheadPerformance = perform(nets,ts,ys)       % >>> semicolon removed so it prints

%% >>> ADDED (T7): was the input scaling computed on all rows or only on the training rows?
try
    disp(net.inputs{1}.processFcns)              % which processing steps this net really has
    k   = find(strcmp(net.inputs{1}.processFcns,'mapminmax'));   % position of the mapminmax step
    ps  = net.inputs{1}.processSettings{k};      % mapminmax settings of the 4 inputs
    xin = cell2mat(x(1,tr.trainInd));            % raw input values of the TRAINING rows
    scalingCheck = table(["Speed";"Acceleration";"Heading";"HeadingChange"], ...
        ps.xmin, ps.xmax, min(xin,[],2), max(xin,[],2), ...
        'VariableNames', {'Feature','Net_min','Net_max','TrainRows_min','TrainRows_max'});
    disp(scalingCheck)
    % If Net_min/Net_max are the same as TrainRows_min/TrainRows_max the check cannot tell;
    % if the Net values are wider, the scaling used rows beyond the training rows.
catch ME
    disp(['Scaling check skipped: ' ME.message]);
end

%% >>> ADDED: save evidence for the report
summary = table( ...
  ["All-data MSE";"Test MSE";"Test RMSE";"Test MAE";"Accuracy all %";"Accuracy test %";"Macro F1 (test)"; ...
   "Baseline accuracy test %";"Baseline MSE test";"Accuracy on label changes, test %"; ...
   "Closed-loop MSE";"Closed-loop accuracy %";"Closed-loop classes used";"Step-ahead MSE"], ...
  [performance;testMSE;testRMSE;testMAE;accAll;accTest;macroF1; ...
   persAccTest;persMSETest;accOnChangesTest; ...
   closedLoopPerformance;closedLoopAcc;closedLoopClassesUsed;stepAheadPerformance], ...
  'VariableNames', {'Metric','Value'});
disp(summary)
writetable(summary, 'narx_evaluation_summary.csv');
save('narx_evaluation_results.mat', 'net', 'tr', 'summary', 'perClass', 'C');
