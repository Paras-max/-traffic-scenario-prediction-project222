%% Driving Style Clustering — Advanced Objective
% Uses the real DACT Strict dataset (TripID, Speed, Acceleration,
% Heading, HeadingChange, SegmentType) to build per-trip features and
% cluster trips into unsupervised "driving styles".
%
% Place DACTStrictDataset.csv in the same folder as this script.

clear; clc;

%% 1. Load data
% Delimiter is forced explicitly: MATLAB's auto-detection gets fooled
% into guessing space-delimited because the TimeStamp column (e.g.
% "Wed Jul 24 15:58:22 EDT 2013") contains lots of spaces.
T = readtable('DACTStrictDataset.csv', 'Delimiter', ',', ...
    'ReadVariableNames', true, 'TextType', 'string');

% Replace literal "NULL" strings with missing, for numeric sanity
T.SegmentType = standardizeMissing(T.SegmentType, "NULL");

%% 2. Aggregate per trip into one feature row
[G, tripIDs] = findgroups(T.TripID);

featureTable = table();
featureTable.TripID        = tripIDs;
featureTable.MeanSpeed      = splitapply(@mean, T.Speed, G);
featureTable.StdSpeed       = splitapply(@std,  T.Speed, G);
featureTable.MeanAccel      = splitapply(@mean, T.Acceleration, G);
featureTable.StdAccel       = splitapply(@std,  T.Acceleration, G);
featureTable.MaxAbsAccel    = splitapply(@(a) max(abs(a)), T.Acceleration, G);
featureTable.StdHeadingChg  = splitapply(@std,  double(T.HeadingChange), G);
featureTable.MeanAbsHdgChg  = splitapply(@(h) mean(abs(h)), double(T.HeadingChange), G);

disp(featureTable);

%% 3. Standardize features (z-score) before clustering
featureCols = {'MeanSpeed','StdSpeed','MeanAccel','StdAccel', ...
               'MaxAbsAccel','StdHeadingChg','MeanAbsHdgChg'};
[X, mu, sigma] = zscore(featureTable{:, featureCols});   % mu/sigma kept so a NEW trip can be scaled the same way:  Xnew = (newFeatures - mu) ./ sigma

% T6: CSV of the standardized per-trip features (evidence for the report)
zTable = array2table(X, 'VariableNames', featureCols);
writetable([featureTable(:, 'TripID') zTable], 'trip_features_zscored.csv');

%% 4. Determine number of clusters (don't hardcode it)
% With only 50 trips, keep the search range modest.
rng(1); % for reproducibility
eva = evalclusters(X, 'kmeans', 'silhouette', 'KList', 2:5);
figure; plot(eva); title('Optimal Number of Clusters (Silhouette)');
optimalK = eva.OptimalK;
fprintf('Optimal number of clusters: %d\n', optimalK);

%% 5. Run clustering — compare k-means, GMM, hierarchical
rng(1);
idxKM = kmeans(X, optimalK, 'Replicates', 20);

gm = fitgmdist(X, optimalK, 'RegularizationValue', 0.01, 'Replicates', 10);
idxGMM = cluster(gm, X);

Z = linkage(X, 'ward');
idxHC = cluster(Z, 'maxclust', optimalK);

figure; dendrogram(Z);
title('Hierarchical Clustering Dendrogram (Trips)');

% Compare agreement between methods. Cluster NUMBERS are arbitrary, so a plain
% label match is meaningless; the adjusted Rand index ignores the numbering
% (1 = identical grouping, about 0 = random agreement).
Ct = crosstab(idxKM, idxGMM);
pairs = @(v) sum(v .* (v - 1) / 2);
sumCells = pairs(Ct(:));  sumRows = pairs(sum(Ct, 2));  sumCols = pairs(sum(Ct, 1));
nPairs = sum(Ct(:)) * (sum(Ct(:)) - 1) / 2;
expectedIdx = sumRows * sumCols / nPairs;
ARI_KM_GMM = (sumCells - expectedIdx) / (0.5 * (sumRows + sumCols) - expectedIdx);
fprintf('K-means vs GMM adjusted Rand index: %.2f\n', ARI_KM_GMM);

%% 6. Attach cluster labels and interpret
featureTable.ClusterKM = idxKM;

% Mean feature profile per cluster — use this to NAME the clusters
clusterProfiles = groupsummary(featureTable, 'ClusterKM', 'mean', featureCols);
disp(clusterProfiles);

% Visualize
figure;
gscatter(featureTable.MeanSpeed, featureTable.StdHeadingChg, idxKM, [], 'o', 10);
xlabel('Mean Speed'); ylabel('Std of Heading Change');
title('Driving Style Clusters (K-means)');
legend(arrayfun(@(k) sprintf('Cluster %d', k), 1:optimalK, 'UniformOutput', false));

figure;
parallelplot(featureTable, 'CoordinateVariables', featureCols, ...
    'GroupVariable', 'ClusterKM');
title('Cluster Feature Profiles (Parallel Coordinates)');

%% 7. Cross-check clusters against existing SegmentType labels
% Build a per-trip "dominant maneuver" label from SegmentType
% (SegmentType is multi-label text like "Smooth-Turn;Speed-Up";
%  we just take the most frequent non-missing tag per trip as a rough summary)
% Written as a plain loop (not splitapply+local function) to avoid
% function-handle resolution issues in some execution contexts.
nTrips = height(featureTable);
dominantSeg = strings(nTrips, 1);
for i = 1:nTrips
    segs = T.SegmentType(G == i);
    segs = segs(~ismissing(segs));
    if isempty(segs)
        dominantSeg(i) = "Unlabeled";
    else
        [u, ~, ic] = unique(segs);
        counts = accumarray(ic, 1);
        [~, mi] = max(counts);
        dominantSeg(i) = u(mi);
    end
end
featureTable.DominantSegment = dominantSeg;

crosstabResult = crosstab(featureTable.ClusterKM, featureTable.DominantSegment);
disp('Cross-tab: Cluster vs Dominant SegmentType');
disp(crosstabResult);

segCats = categories(categorical(featureTable.DominantSegment));   % same order crosstab uses
figure;
heatmap(segCats, cellstr(string(1:optimalK)), crosstabResult);
title('Cluster vs Dominant Maneuver Type');
xlabel('Dominant SegmentType'); ylabel('Cluster');

%% Save results for the report
save('driving_style_clustering_results.mat', 'featureTable', 'clusterProfiles', 'crosstabResult', 'mu', 'sigma');
writetable(featureTable, 'driving_style_clusters.csv');
