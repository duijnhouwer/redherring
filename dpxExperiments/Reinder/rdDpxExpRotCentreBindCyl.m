function rdDpxExpRotCentreBindCyl(BB)
%%baseline and binding experiment
%
%%input needed is: (pos) --> position of the !HALVE! cylinder (inducer), 'left' or 'right'
%%experiment type (BB) --> baseline or binding (depends on whihc stim the subject has to
%%report: 'base' or 'bind'
%%i.e. rdDpxExpRotCyl('left','bind')

E=dpxCoreExperiment;
E.txtPauseNrTrials=111;
E.nRepeats=10;

fb='';

% handle the position option
E.txtStart='Kijk naar het rode kruis.\n\nHoe beweegt het voorvlak van de middelste volle cylinder?\nOmhoog = Pijltje omhoog\nOmlaag = Pijltje omlaag';
E.paradigm='rdDpxExpBindingCylLeft';






E.txtStart=[ E.txtStart '\nFeedback Flits:\nGrijs: Antwoord ontvangen.'];
fbCorrectStr='fbCorrect';
fbWrongStr='fbCorrect';

% Then the experiment option, make expname (used in output filename)
if strcmpi(BB,'base')
    E.outputFolder='/Users/laurens/Dropbox/DPX/Data/Exp2Baseline';
elseif strcmpi(BB,'bind')
    E.outputFolder='/Users/laurens/Dropbox/DPX/Data/Exp2Binding';
end

% Set the stimulus window option
E.physScr.set('rectPx',[],'widHeiMm',[394 295],'distMm',1000);
E.physScr.set('interEyeMm',65,'gamma',0.49,'backRGBA',[0.5 0.5 0.5 1]);
E.physScr.set('stereoMode','mirror','SkipSyncTests',1);
E.windowed(false); % true, false, e.g. [10 10 410 310], for debugging

% Add stimuli and responses to the conditions, add the conditions to
% the experiement, and run
modes={'mono','stereo','anti-stereo'};
for m=1:numel(modes)
    for dsp=[-1:.2:1]
        for rotSpeed=[-120 120]
            C=dpxCoreCondition;
            set(C,'durSec',2.5);
            % The fixation cross
            S=dpxStimCross;
            set(S,'wDeg',.25,'hDeg',.25,'lineWidDeg',.05,'name','fix');
            C.addStimulus(S);
            % The feedback stimulus for correct responses
            S=dpxStimDot;
            set(S,'wDeg',.3,'enabled',false,'durSec',0.20,'RGBAfrac',[.75 .75 .75 .75],'name','fbCorrect');
            C.addStimulus(S);
            
            % The response object
            R=dpxCoreResponse;
            set(R,'kbNames','UpArrow,DownArrow');
            set(R,'correctStimName',fbCorrectStr,'correctEndsTrialAfterSec',10000);
            set(R,'wrongStimName',fbWrongStr,'wrongEndsTrialAfterSec',10000);
            set(R,'name','rightHand');
            C.addResponse(R);
            if dsp<0
                R.correctKbNames='UpArrow';
            elseif dsp>0
                R.correctKbNames='DownArrow';
            else
                R.correctKbNames='1';
            end
            
            % The full cylinder stimulus
            S=dpxStimRotCylinder;
            set(S,'dotsPerSqrDeg',12,'xDeg',flippos*1.75,'wDeg',3,'hDeg',3,'dotDiamDeg',0.11 ...
                ,'rotSpeedDeg',rotSpeed,'disparityFrac',0,'sideToDraw','both' ...
                ,'onSec',0,'durSec',1,'stereoLumCorr',1,'fogFrac',0,'dotDiamScaleFrac',0 ...
                ,'name','fullTargetCyl');
                        set(S,'dotRGBA1frac',[1 1 1 1],'dotRGBA2frac',[1 1 1 1]);
            C.addStimulus(S);
            % The half cylinder stimulus
            if strcmpi(modes{m},'mono')
                lumcorr=1;
                dFog=dsp;
                dScale=dsp;
                dispa=0;
            elseif strcmpi(modes{m},'stereo')
                lumcorr=1;
                dFog=0;
                dScale=0;
                dispa=dsp;
            elseif strcmpi(modes{m},'anti-stereo')
                lumcorr=-1;
                dFog=0;
                dScale=0;
                dispa=dsp;
            end
            S=dpxStimRotCylinder;
            set(S,'dotsPerSqrDeg',12,'xDeg',flippos*-1.75,'wDeg',3,'hDeg',3,'dotDiamDeg',0.11 ...
                ,'rotSpeedDeg',rotSpeed,'disparityFrac',dispa,'sideToDraw','front' ...
                ,'onSec',0,'durSec',1,'stereoLumCorr',lumcorr,'fogFrac',dFog,'dotDiamScaleFrac',dScale ...
                ,'name','halfInducerCyl');
                        set(S,'dotRGBA1frac',[1 1 1 1],'dotRGBA2frac',[1 1 1 1]);
            C.addStimulus(S);
            %
            E.addCondition(C);
        end
    end
end
E.run;
end