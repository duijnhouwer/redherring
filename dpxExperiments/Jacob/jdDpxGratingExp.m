function jdDpxGratingExp
    E=dpxCoreExperiment;
    E.paradigm='jdDpxGratingExp';
    E.window.distMm=290;
    % 2014-4-24: Measured luminance BENQ screen Two-Photon room
    % Brightness 0; contrast 50; black eq 15; color temp [R G B] correction = [0
    % 100 100] blur reduction OFF; dynamic contrast 0 Resolution 1920x1080 60
    % Hz VGA connected
    % With these settings. FullWhite=33.6 cd/m2; FullBlack=0.053; and with
    % gamma 0.69, medium gray (index 127) = 16.96 cd/m2
    %
    E.window.gamma=0.69;
    E.window.backRGBA=[.25 .25 .25 1];
    E.txtStart='asd DAQ-pulse';
    E.txtEnd='asd DAQ-pulse';
    E.txtPauseNrTrials=0;
    %
    % Settings
    %
    dirDegs=[0 180];
    contrastFracs=[.25 .5 1];
    cyclesPerDeg=[.05 .1 .2];
    cyclesPerSecond=[.5 1 2];
    E.nRepeats=2;
    stimSec=4;
    isiSec=4;
    %
    nrTrials=numel(dirDegs) * numel(contrastFracs) * numel(cyclesPerDeg) * numel(cyclesPerSecond) * E.nRepeats;
    dpxDispFancy(['Please set-up a ' num2str(ceil(nrTrials*(isiSec+stimSec)+5)) ' s recording pattern in LasAF (' num2str(nrTrials) ' trials of ' num2str(stimSec+isiSec) ' s.)']);
    %
    for direc=dirDegs(:)'
        for cont=contrastFracs(:)'
            for sf=cyclesPerDeg(:)'
                for tf=cyclesPerSecond(:)'
                    C=dpxCoreCondition;
                    C.durSec=stimSec+isiSec;
                    if direc==0
                        C.overrideBackRGBA=[1 0 0 1];
                    end
                    %
                    S=dpxStimGrating;
                    %
                    S.wDeg=45;
                    S.dirDeg=direc;
                    S.cyclesPerSecond=tf;
                    S.cyclesPerDeg=sf;
                    S.contrastFrac=cont;
                    S.grayFrac=.25;
                    S.squareWave=true;
                    S.maskStr='circle';
                    S.maskPars=2;
                    S.onSec=isiSec/2;
                    S.durSec=stimSec;
                    %
                    C.addStimulus(S);
                    E.addCondition(C);
                end
            end
        end    
    end
    E.run;
end
