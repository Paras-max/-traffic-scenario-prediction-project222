% FixSimulinkModel.m  (T5 + T13)
% Run ONCE, from the folder that contains untitled.slx, after your From Workspace
% model works. It (1) backs up the file, (2) sets the sample times explicitly
% (removes the "-1 back-inherited" warning), (3) sets Stop Time = 26 (27 data rows),
% (4) deletes the unused scope y1 if nothing is connected to it, (5) saves the model.
% Block names are the ones named in your own Simulink warnings.

mdl = 'untitled';

if ~isfile('untitled_backup_before_fix.slx')
    copyfile('untitled.slx', 'untitled_backup_before_fix.slx');
end

try
    load_system(mdl);
    set_param([mdl '/From Workspace'],  'SampleTime', '1');
    set_param([mdl '/From Workspace1'], 'SampleTime', '1');
    set_param(mdl, 'StopTime', '26');

    ph = get_param([mdl '/y1'], 'PortHandles');
    if get_param(ph.Inport(1), 'Line') == -1          % -1 = nothing connected
        delete_block([mdl '/y1']);
        disp('Unused scope y1 deleted.');
    else
        disp('Scope y1 is connected - left in place.');
    end

    save_system(mdl);
    close_system(mdl);
    disp('untitled.slx saved with explicit sample times and Stop Time 26.');
    disp('Now run RunFullPipeline.m to confirm it still produces the 27 x 10 output.');
catch ME
    disp(['Could not finish: ' ME.message]);
    disp('Open untitled.slx by hand and make the same changes (From Workspace blocks: Sample time = 1).');
end
