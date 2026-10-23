%% V2V Behaviour-Mapping Logic — implements §3.2 of the paper
% Takes the predicted behaviour of the previous and following vehicle,
% plus whether distance is above/below the security threshold, and
% returns Car A's own behaviour.
%
% NOTE: deliberately does NOT clear the workspace -- this script depends
% on 'predictedBehavior' already existing from RunFullPipeline.m.
clc;

%% 1. Validate the rule table against the paper's own 18 cases
testCases = {
    % prevBeh, follBeh, distFlag, expected
    "Speed-Up","Speed-Up","far","Speed-Up"
    "Speed-Up","Slow-Down","far","Hold"
    "Speed-Up","Turn","far","Hold"
    "Slow-Down","Speed-Up","far","Slow-Down"
    "Slow-Down","Slow-Down","far","Slow-Down"
    "Slow-Down","Turn","far","Slow-Down"
    "Turn","Speed-Up","far","Hold"
    "Turn","Slow-Down","far","Hold"
    "Turn","Turn","far","Hold"
    "Speed-Up","Speed-Up","near","Speed-Up"
    "Speed-Up","Slow-Down","near","Hold"
    "Speed-Up","Turn","near","Hold"
    "Slow-Down","Speed-Up","near","ALERT: Possible rear-end risk"
    "Slow-Down","Slow-Down","near","Slow-Down"
    "Slow-Down","Turn","near","Slow-Down"
    "Turn","Speed-Up","near","Hold"
    "Turn","Slow-Down","near","Hold"
    "Turn","Turn","near","Hold"
};

fprintf('--- Validating rule table against paper Section 3.2 ---\n');
allPass = true;
for i = 1:size(testCases,1)
    result = behaviourMap(testCases{i,1}, testCases{i,2}, testCases{i,3});
    expected = testCases{i,4};
    pass = strcmp(result, expected);
    allPass = allPass && pass;
    fprintf('%-10s + %-10s (%-4s) -> %-28s [expected: %-28s] %s\n', ...
        testCases{i,1}, testCases{i,2}, testCases{i,3}, result, expected, ...
        string(pass));
end
fprintf('All 18 cases match: %s\n\n', string(allPass));

%% 2. Collapse 10-class NARX predictions down to the paper's 3-class scheme
labels10 = ["Slow-Down","Speed-Up","Turn","Smooth-Turn","Left-Turn", ...
            "Right-Turn","Traffic-Light","Loop","Other","Jiggling"];

function b3 = collapseTo3Class(label10)
    if label10 == "Slow-Down"
        b3 = "Slow-Down";
    elseif label10 == "Speed-Up"
        b3 = "Speed-Up";
    elseif ismember(label10, ["Turn","Smooth-Turn","Left-Turn","Right-Turn"])
        b3 = "Turn";
    else
        b3 = "Hold"; % Traffic-Light/Loop/Other/Jiggling: undefined by the paper
    end
end

%% 3. Demo: feed real NARX prediction sequences as two neighbouring vehicles
% Reusing your Slow-Down -> Speed-Up sequence as the "previous vehicle",
% and a shifted/offset copy as a stand-in "following vehicle" for demo
% purposes (swap in a second real NARX run on different data if you have one).

prevVehicle10 = predictedBehavior;           % from your Simulink/NARX run, 27x1 string
follVehicle10 = circshift(predictedBehavior, -5); % stand-in second vehicle

prevVehicle3 = arrayfun(@collapseTo3Class, prevVehicle10);
follVehicle3 = arrayfun(@collapseTo3Class, follVehicle10);

% Synthetic distance profile: simulate vehicles closing in over time
% (just for demonstration -- replace with real GPS-derived distance if available)
n = numel(prevVehicle3);
distanceFlag = repmat("far", n, 1);
distanceFlag(round(n/2):end) = "near"; % closes within security distance halfway through

carA_behaviour = strings(n,1);
for t = 1:n
    carA_behaviour(t) = behaviourMap(prevVehicle3(t), follVehicle3(t), distanceFlag(t));
end

%% 4. Report results
resultTable = table((1:n)', prevVehicle3, follVehicle3, distanceFlag, carA_behaviour, ...
    'VariableNames', {'Timestep','PrevVehicle','FollVehicle','Distance','CarA_Behaviour'});
disp(resultTable);

figure;
subplot(2,1,1);
plot(categorical(carA_behaviour), 'o-');
title('Car A Resulting Behaviour Over Time (V2V Pipeline)');
ylabel('Behaviour'); xlabel('Timestep'); grid on;

subplot(2,1,2);
plot(distanceFlag == "near", 'r-', 'LineWidth', 1.5);
title('Distance Flag (1 = Within Security Distance)');
ylim([-0.2 1.2]); xlabel('Timestep'); grid on;

writetable(resultTable, 'v2v_behaviour_mapping_results.csv');

%% ===== Rule table function =====
function result = behaviourMap(prevBeh, follBeh, distFlag)
    % distFlag: "far" (> security distance) or "near" (< security distance)
    if distFlag == "far"
        if prevBeh == "Speed-Up" && follBeh == "Speed-Up"
            result = "Speed-Up";
        elseif prevBeh == "Speed-Up"
            result = "Hold"; % Speed-Up + (Slow-Down or Turn)
        elseif prevBeh == "Slow-Down"
            result = "Slow-Down"; % Slow-Down + anything
        elseif prevBeh == "Turn"
            result = "Hold"; % Turn + anything
        else
            result = "Hold";
        end
    else % "near"
        if prevBeh == "Speed-Up" && follBeh == "Speed-Up"
            result = "Speed-Up";
        elseif prevBeh == "Speed-Up"
            result = "Hold";
        elseif prevBeh == "Slow-Down" && follBeh == "Speed-Up"
            result = "ALERT: Possible rear-end risk"; % the paper's "?" case
        elseif prevBeh == "Slow-Down"
            result = "Slow-Down";
        elseif prevBeh == "Turn"
            result = "Hold";
        else
            result = "Hold";
        end
    end
end
