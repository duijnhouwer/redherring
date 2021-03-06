function rdDpxExpBistableCyl
% a bistable full cylinder, to see how much switching occurs.

if IsWin
    DisableKeysForKbCheck([233]);
end

E=dpxCoreExperiment;
E.nRepeats=1;
E.txtStart='Straks ziet u een volle cylinder.\nWelke kant draait het voorvlak van de cylinder?\n\nOmhoog = Pijltje omhoog\n Omlaag = Pijltje omlaag\n\n\nDruk op spatie om te beginnen';
E.paradigm='rdDpxBistableCyl';

if strcmpi(dpxGetUserName,'Reinder')
    E.outputFolder='C:\tempdata_PleaseDeleteMeSenpai';
elseif strcmpi(dpxGetUserName,'Eyelink-admin')
    E.outputFolder='C:\Users\Eyelink-admin\DropBox\DPX\Data\ExpBistableCylinder\';
end

E.window.set('rectPx',[1440 0 1600+1440 1200],'widHeiMm',[394 295],'distMm',1000,'scrNr',1);
E.window.set('interEyeMm',65,'gamma',0.49','backRGBA',[0.5 0.5 0.5 1]);
E.window.set('stereoMode','mirror','skipSyncTests',1);

C=dpxCoreCondition;
set(C,'durSec',120')

S=dpxStimCross;
set(S,'wDeg',.25,'hDeg',.25,'lineWidDeg',.05,'name','fix');
C.addStimulus(S);

S=dpxStimRotCylinder;
set(S,'dotsPerSqrDeg',12,'xDeg',0,'wDeg',3,'hDeg',3,'dotDiamDeg',0.11 ...
    ,'rotSpeedDeg',120,'disparityFrac',0,'sideToDraw','both' ...
    ,'onSec',0,'durSec',120','name','FullBistableCyl');
C.addStimulus(S);

R=dpxRespContiKeyboard;
set(R,'kbName','UpArrow');
set(R,'name','UpArrow');
C.addResponse(R);

R=dpxRespContiKeyboard;
set(R,'kbName','DownArrow');
set(R,'name','DownArrow');
C.addResponse(R);

E.addCondition(C);

E.run;
end

