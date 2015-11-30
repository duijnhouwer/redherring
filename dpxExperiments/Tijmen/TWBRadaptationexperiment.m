 function TWBRadaptationexperiment
% 16-03-15 
% Binocular rivalry experiment with gratings 

clear all; clf;  
KbName('UnifyKeyNames');
E=dpxCoreExperiment; 
E.paradigm='TWBRadaptationexperiment'

W =dpxCoreWindow;

Language = input('NL(1)/EN(2):');
if Language ==1
E.txtStart=sprintf('Druk op $STARTKEY en laat deze los \n om het experiment te starten.\n\n Druk eenmalig op de \n linker- en rechter controltoets.\n Interrupties: druk voor elke interruptie. \n  Continu: druk bij elke nieuwe waarneming.');
E.txtEnd= 'Einde van het experiment';
end

if Language ==2
E.txtStart = sprintf('Press and release $STARTKEY \n to start the experiment.\n\n Press left and right\n control key once to respond.\n Interruption: press before each interruption. \n Continuous: press for every new percept.');
E.txtEnd= 'End of the experiment';
end

E.breakFixTimeOutSec=0;
E.outputFolder='C:\dpxData';

set = 0;                                                                    % screen settings for philips screen
if set ==0
E.window.set('rectPx',[],'widHeiMm',[390 295],'distMm',1000, ...
        'interEyeMm',65,'gamma',1,'backRGBA',[.5 .5 .5 1], ...
        'stereoMode','mirror','skipSyncTests',0,'scrNr',0); 
else   
E.window.set('rectPx',[1440 0 1600+1440 1200],'widHeiMm',[390 295], ...     % screen settings for eyelink
        'distMm',1000, 'interEyeMm',65,'gamma',1,'backRGBA',[.5 .5 .5 1], ...
        'stereoMode','mirror','skipSyncTests',0,'scrNr',1);
end

disp('Loading (may take a while). Please wait...'); 

% generate Toff Times with a shuffled order
Toff = [0.25,0.5,1]; 
shuffle = [randperm(3); Toff]; 
Toff = sortrows(shuffle',1); 
Toff = Toff(:,2)

k = 0; 
cont0 = 30;                                                                 % s, this should be 480 for the 'real experiment'
adap0 = 10;                                                                 % s, this should be 60 for the 'real experiment'
trialLength = 30; 

for Ton=[cont0, adap0];   
    k=k+1;
    C=dpxCoreCondition;    
    C.durSec = Ton;
     
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % STIMULUS presentation at the left side of the screen (right side if mirror is active)
                 
        LeftCheck=dpxStimCheckerboard;
        LeftCheck.name='checksLeft';
        LeftCheck.RGBAfrac= [1 1 1 1];
        LeftCheck.contrast=0.25;
        LeftCheck.xDeg=0;
        LeftCheck.wDeg=125/W.deg2px;
        LeftCheck.hDeg=125/W.deg2px;
        LeftCheck.nHoleHori=10;
        LeftCheck.nHoleVert=10;
        LeftCheck.nHori=18;
        LeftCheck.nVert=18;
        LeftCheck.sparseness=2/3;
        LeftCheck.durSec = Ton; 
        C.addStim(LeftCheck);
        
        ML = dpxStimMask;
        ML.grayFrac=.5;
        ML.pars=.5;
        ML.name='MaskLeft';
        ML.typeStr='gaussian';
        ML.xDeg=0;
        ML.hDeg = (50*sqrt(2))/W.deg2px; 
        ML.wDeg = (50*sqrt(2))/W.deg2px;
        ML.durSec=Ton; 
        C.addStim(ML);
    
        GL = dpxStimGrating;
        GL.name = 'gratingLeft'; 
        GL.xDeg=0;
        GL.dirDeg=-45;
        GL.contrastFrac=1;
        GL.squareWave=false;
        GL.cyclesPerSecond=0;
        GL.cyclesPerDeg=2.5;
        GL.wDeg=(50)/W.deg2px;
        GL.hDeg=(50)/W.deg2px;    
        GL.durSec=Ton; 
        C.addStim(GL);
          
        Dot = dpxStimDot;
        Dot.name = 'Dot';
        Dot.xDeg=0; 
        Dot.wDeg=0;
        Dot.hDeg=0;
        C.addStim(Dot);
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % STIMULUS presentation at the right side of the screen (left side if mirror is active)
        
        RightCheck = dpxStimCheckerboard;
        RightCheck.name='checksRight';
        RightCheck.RGBAfrac=[1 1 1 1];
        RightCheck.contrast=0.25;
        RightCheck.xDeg=0;
        RightCheck.wDeg=125/W.deg2px;
        RightCheck.hDeg=125/W.deg2px;
        RightCheck.nHori=18;
        RightCheck.nVert=18;
        RightCheck.nHoleHori=10;
        RightCheck.nHoleVert=10;
        RightCheck.sparseness=2/3;
        RightCheck.rndSeed=LeftCheck.rndSeed;
        C.addStim(RightCheck);
        
        MR = dpxStimMask;
        MR.name='MaskRight';
        MR.grayFrac=.5;
        MR.pars=.5;
        MR.typeStr='gaussian';
        MR.xDeg=0;
        MR.hDeg = (50*sqrt(2))/W.deg2px;
        MR.wDeg = (50*sqrt(2))/W.deg2px;
        MR.durSec=Ton; 
        C.addStim(MR);

        GR = dpxStimGrating;
        GR.name = 'gratingRight';
        GR.xDeg=0;
        GR.dirDeg=45;
        GR.squareWave=false;
        GR.cyclesPerSecond=0;
        GR.cyclesPerDeg=2.5;
        GR.wDeg= (50)/W.deg2px;
        GR.hDeg= (50)/W.deg2px;      
        GR.durSec=Ton;
        C.addStim(GR);

        RL0 = dpxRespContiKeyboard;
        RL0.name='keyboardl';
        RL0.kbName='LeftControl';
        C.addResp(RL0); 
        
        RR0 = dpxRespContiKeyboard;
        RR0.name='keyboardr';
        RR0.kbName='RightControl';
        C.addResp(RR0);
        
        E.addCondition(C);  
end

for i=1:length(Toff)
    if i<3
        cont = 10; 
        adap = 10;  
    else 
        cont = []; 
        adap = [];                                                          % scraps the two (unnecessary) adaptation trials at the end 
    end
    
    rep = trialLength./(1+Toff(i));                                          % length of interleaved percept choice sequences = 60 seconds (1 min)
    
    if mod(rep,1) ~0;
        error('The trial length should be divisible by 30'); 
    end
    
    j = 0; 
    for Ton = [trialLength, cont, adap];
        j = j+1;
        D = dpxCoreCondition; 
        
        if Ton==trialLength
        offTime = Toff(i); 
        else 
        offTime = 0;
        end
        
        D.durSec = Ton;
      
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % STIMULUS presentation at the left side of the screen     
       
        LeftCheck=dpxStimCheckerboard;
        LeftCheck.name='checksLeft';
        LeftCheck.RGBAfrac=[1 1 1 1];
        LeftCheck.xDeg=0;
        LeftCheck.wDeg=125/W.deg2px;
        LeftCheck.hDeg=125/W.deg2px; 
        LeftCheck.contrast=.25;
        LeftCheck.nHoleHori=10;
        LeftCheck.nHoleVert=10;
        LeftCheck.nHori=18;
        LeftCheck.nVert=18;
        LeftCheck.sparseness=2/3;
        LeftCheck.durSec = Inf; 
        LeftCheck.onSec = 0; 
        D.addStim(LeftCheck);
        
        for nRepeats=1:rep
        ML = dpxStimMask;
        ML.name = sprintf('MaskLeft%d', nRepeats);
        ML.grayFrac=.5;
        ML.pars=.5;
        ML.typeStr='gaussian';
        ML.xDeg=0;
        ML.hDeg = (50*sqrt(2))/W.deg2px; 
        ML.wDeg = (50*sqrt(2))/W.deg2px;
        ML.durSec = 1;
        ML.onSec =(offTime + 1)*(nRepeats-1) ;
        D.addStim(ML);
                
        GL = dpxStimGrating;
        GL.name = sprintf('GratingLeft%d', nRepeats);
        GL.xDeg=0;
        GL.dirDeg=-45;
        GL.squareWave=false;
        GL.cyclesPerSecond=0;
        GL.cyclesPerDeg=2.5;
        GL.wDeg= (50)/W.deg2px;
        GL.hDeg= (50)/W.deg2px;
        GL.durSec = 1; 
        GL.onSec = (offTime + 1)*(nRepeats-1) ;
        D.addStim(GL);
        end
        
        Dot = dpxStimDot;
        Dot.name = 'Dot';
        Dot.xDeg=0; 
        Dot.wDeg=0;
        Dot.hDeg=0;
        D.addStim(Dot);
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % STIMULUS presentation at the right side of the screen
        
        RightCheck=dpxStimCheckerboard;
        RightCheck.name='checksRight';
        RightCheck.RGBAfrac=[1 1 1 1];
        RightCheck.xDeg=0;
        RightCheck.wDeg=125/W.deg2px;
        RightCheck.hDeg=125/W.deg2px;
        RightCheck.contrast=.25;
        RightCheck.nHori=18;
        RightCheck.nVert=18;
        RightCheck.nHoleHori=10;
        RightCheck.nHoleVert=10;
        RightCheck.sparseness=2/3;
        RightCheck.rndSeed=LeftCheck.rndSeed;
        RightCheck.durSec = Inf; 
        RightCheck.onSec = 0; 
        D.addStim(RightCheck);
        
        for nRepeats =1:rep
        MR = dpxStimMask;
        MR.name = sprintf('MaskRight%d', nRepeats);
        MR.grayFrac=.5;
        MR.pars=.5;
        MR.typeStr='gaussian';
        MR.xDeg=0;
        MR.hDeg = (50*sqrt(2))/W.deg2px; 
        MR.wDeg = (50*sqrt(2))/W.deg2px;
        MR.durSec = 1;
        MR.onSec =(offTime + 1)*(nRepeats-1) ;
        D.addStim(MR);

        GR = dpxStimGrating;
        GR.name = sprintf('GratingRight%d', nRepeats);
        GR.xDeg=0;
        GR.dirDeg=45;
        GR.squareWave=false;
        GR.cyclesPerSecond=0;
        GR.cyclesPerDeg=2.5;
        GR.wDeg= (50)/W.deg2px;
        GR.hDeg= (50)/W.deg2px;  
        GR.durSec = 1;
        GR.onSec = (offTime + 1)*(nRepeats-1) ;
        D.addStim(GR);
        end

        RL = dpxRespContiKeyboard;
        RL.name = 'keyboardl';
        RL.kbName='LeftControl';
        D.addResp(RL); 
        
        RR = dpxRespContiKeyboard;
        RR.name = 'keyboardr'; 
        RR.kbName ='RightControl';
        D.addResp(RR);
        
      E.addCondition(D); 
    end 
end 

    E.conditions
    E.conditionSequence = 1:numel(E.conditions);
    E.nRepeats=1; 
    E.run;
    sca; 
    
 end