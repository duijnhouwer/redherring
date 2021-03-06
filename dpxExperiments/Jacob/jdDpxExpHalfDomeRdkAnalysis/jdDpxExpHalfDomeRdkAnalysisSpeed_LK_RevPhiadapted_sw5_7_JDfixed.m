function out=jdDpxExpHalfDomeRdkAnalysisSpeed_LK_NoPool_unlim_deltaFF_opt2(files,option,gainOrYaw,phiOrIhp)
    
    % Analyze halfdome mouse on ball data
    % see also:
    %    jdDpxExpHalfDomeRdkAnalysisSpeedSlidWin
    %    jdDpxExpHalfDomeRdkAnalysisSpeedEarlyLate
    %
    
    if ~any(strcmpi(gainOrYaw,{'gain','yaw'}))
        error('gainOrYaw must be ''gain'' or ''yaw''');
    end
    
    
    if ~any(strcmpi(phiOrIhp,{'phi','ihp','unlim'}))
        error('phiOrIhp must be ''phi'' or ''ihp'' or "unlim"');
    end
    
    global intWinSec
    intWinSec=[1 2]; % time window over which mean yaw is taken
    
    if ~exist('files','var') || isempty(files)
        files=dpxUIgetFiles;
        disp([num2str(numel(files)) ' datafiles selected.']);
        if isempty(files)
            return;
        end
    end
    if ~exist('option','var') || isempty(option)
        option=[];
        timeWinSec=[];
    elseif isnumeric(option)
        timeWinSec=option;
        if ~numel(timeWinSec)==2
            error('timeWinSec needs two values: a min and a max time in seconds');
        end
    elseif ischar(option)
        timeWinSec=[];
        strs={'betweenEarly','betweenLate','withinEarly','withinLate'};
        if ~any(strcmpi(option,strs))
            error(['unknown option, should be one of ' sprintf('%s ',strs{:})]);
        end
    end
    E={};
    out.nFilesWithDataWithinWindow=0;
    for i=1:numel(files)
        D=dpxdLoad(files{i});
        if ~isnan(timeWinSec)
            % select the subset of data that's within the time interval
            t=D.startSec-D.startSec(1);
            if max(timeWinSec)>max(t)
                continue; % this file has reached it's maximum time
            else
                out.nFilesWithDataWithinWindow=out.nFilesWithDataWithinWindow+1;
            end
            D=dpxdSubset(D,t>=min(timeWinSec) & t<max(timeWinSec));
        end
        maxFrDropsPerSec=5;
        [D,percentBadTrials] = removeTrialWithTooManyFramedrops(D,maxFrDropsPerSec/D.window_measuredFrameRate(1)*100);
        disp(['File #' num2str(i,'%.3d') ': ' num2str(round(percentBadTrials)) '% of trials had more than ' num2str(maxFrDropsPerSec) ' video-frame drops per second']);
        if percentBadTrials>50
            fprintf(' ---> skipping file : %s\n', files{i} );
            continue
        end
        %
        [D,str,suspect,maxCorr]=clarifyAndCheck(D);
        if ~suspect
            % Only include data files that are completely fine and have no suspicious
            % things happening, like poor correlations between the yaw measurements of
            % both computer mice on the ball (both measure yaw, should be about the
            % same)
            E{end+1}=D; %#ok<AGROW>
        else
            disp(['clarifyAndCheck said ' str ' but correlation (' num2str(maxCorr) ') is below threshold...']);
            fprintf(' ---> skipping file : %s\n', files{i} );
        end
        clear D;
    end
    if isempty(E)
        disp('None of the files passed the tests. Can''t continue.');
        return;
    else
        disp([num2str(numel(E)) ' out of ' num2str(numel(files)) ' data files passed the tests.']);
    end
    %
    % Merge all datafiles that we collected in cell array
    E=dpxdMerge(E); % E is now a DPXD
    %
    if ischar(option)
        dpxDispFancy(['Doing median-split ' option ]);
        switch lower(option)
            case 'betweenearly'
                E=dpxdToolSplitByTime(E,'scope','betweenruns','interval',[0 0.5]);
            case 'betweenlate'
                E=dpxdToolSplitByTime(E,'scope','betweenruns','interval',[0.5 1]);
            case 'withinearly'
                E=dpxdToolSplitByTime(E,'scope','withinruns','interval',[0 0.5]);
            case 'withinlate'
                E=dpxdToolSplitByTime(E,'scope','withinruns','interval',[0.5 1]);
            otherwise
                error('???');
        end
    end
    if E.N==0
        keyboard
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%   %LK 2017-08
    % ReversePhi experiment or not
    %  nFreezeFlips=numel(unique(E.rdk_freezeFlip));
    %  if nFreezeFlips>1
    %      Exptype='ReversePhi';
    %      ctrlVAr='freezeflip';
    %      A=splitByFreezeFlips(E);
    %  end
    %      %  infinite lifetime control
    %      analyze(dpxdSubset(E,E.rdk_nSteps==Inf),'; Unlimited lifetime');
    %      % PHI and IHP
    %      PHI=dpxdSubset(E,E.rdk_nSteps==1 & E.rdk_invertSteps==Inf); % & E.rdk_freezeFlip==5
    %      analyze(PHI,'; Phi (Flip all)');
    %      IHP=dpxdSubset(E,E.rdk_nSteps==1 & E.rdk_invertSteps==1); % & E.rdk_freezeFlip==5
    %      analyze(IHP,'; Reverse-phi (Flip all)');
    %      cpsTileFigs;
    %
    %      keyboard
    %      return;
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    if strcmpi(phiOrIhp,'phi')
        E=dpxdSubset(E,(E.rdk_nSteps==1 & E.rdk_invertSteps==Inf));
    elseif strcmpi(phiOrIhp,'ihp')
        E=dpxdSubset(E,(E.rdk_nSteps==1 & E.rdk_invertSteps==1));
    elseif strcmpi(phiOrIhp, 'unlim')
        E=dpxdSubset(E,(E.rdk_nSteps==Inf));
    else
        error('unknown phiOrIhp: %s',phiOrIhp)
    end
    
    
    nFreezeFlips=numel(unique(E.rdk_freezeFlip));
    nDotsizes=numel(unique(E.rdk_dotDiamPx));
    lums=nan(1,E.N);
    %here transparancy conditions invullen 
    for i=1:E.N
        lums(i)=E.mask_RGBAfrac{i}(1);
    end
    nContrasts=numel(unique(lums));
    if nDotsizes>1 && nContrasts==1 && nFreezeFlips==1
        ctrlVar='dotdiam';
        A=splitByDotDiam(E);
    elseif nDotsizes==1 && nContrasts>1 && nFreezeFlips==1 || nDotsizes==1 && nContrasts==1 && nFreezeFlips==1
        ctrlVar='contrast';
        A=splitByContrast(E);
    elseif nDotsizes==1 && nContrasts==1 && nFreezeFlips>1 %LK 2017-08
        ctrlVar='freezeflip';
        A=splitByFreezeFlips(E);
    %elseif voor de transparancy
    else
        
        error('both dotdiam and contrast vary, select other files');
    end
    
    A = dpxdMerge(A); % combine into one DPXD again
    %
    % Plot the speed curves for each mouse and the mean in separate panels for ctrlVar
    miceNames=unique(A.mus);
    curves={};
    for i=1:numel(miceNames)
        M = dpxdSubset(A,strcmpi(A.mus,miceNames{i}));
        plotTimeYawCurves(M,ctrlVar,option);
        [curves{end+1},figtit]=plotSpeedYawCurves(M,option,ctrlVar,gainOrYaw,phiOrIhp);  %#ok<AGROW>
        plotCtrlVarYawCurves(figtit,curves{end},option,ctrlVar);
        plotCtrlVarYawdifCurves(figtit,curves{end},option,ctrlVar);             %%%%%%%%%%%%%%%%%%%%%%REV PHI LK 2017-09
    end
    % Output for further analysis
    out.curves=dpxdMerge(curves);
end


function C = analyzeAcrossMiceAndSpeeds(E)
    % This function return a cell for each mouse with the yaw-traces (raw
    % and mean) for each speed used. The last cell will contain a virtual
    % mouse that is the mean of all the other.
    %
    % If you want to analyze the effect of different properties (than mouse
    % and speed), split the data and call this function in a for loop over
    % the separate parts, then merge those later. That's cleaner than
    % elaborating this already overly complicated function (in hindsight i
    % would have properly not even split used for loops for the various
    % mice but have them done sequentially in a loop outside this function
    % as well.)
    %
    % split E per mouse, E
    E=dpxdSplit(E,'exp_subjectId'); % E is now a cell-array of DPXDs
    % for each mouse, get the curves, and store in cell array C
    C=cell(size(E));
    nMice=numel(E);
    for i=1:nMice
        C{i}=getSpeedCurves(E{i});
    end
   
    % Make a plot of the raw yaw traces, to visual inspect for clipping
    %plotAllYawToCheckClipping(C,titleString);
    % calculate mean traces per mouse (pooled over sessions)
    C=getMeanYawTracesPerMouse(C);
    if nMice>1
%     %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%     %%%%%%%%%%%%%%%%%%%%%    Switch Mouse 5 speeds     %%%%%%%%%%%%%%%%%%%%%%%%%   LK 7-10-2018
%         C{1,5}.yaw(:, [1 2]) = C{1,5}.yaw(:, [2 1]);
%         C{1,5}.yawRaw(:, [1 2]) = C{1,5}.yawRaw(:, [2 1]);
%         C{1,5}.yawMean(:, [1 2]) = C{1,5}.yawMean(:, [2 1]);
%         C{1,5}.yawSEM(:, [1 2]) = C{1,5}.yawSEM(:, [2 1]);
%     %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 
%     %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 
%         %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%     %%%%%%%%%%%%%%%%%%%%%    Switch Mouse 7 speeds     %%%%%%%%%%%%%%%%%%%%%%%%%   LK 31-12-2018
%         C{1,7}.yaw(:, [1 2]) = C{1,7}.yaw(:, [2 1]);
%         C{1,7}.yawRaw(:, [1 2]) = C{1,7}.yawRaw(:, [2 1]);
%         C{1,7}.yawMean(:, [1 2]) = C{1,7}.yawMean(:, [2 1]);
%         C{1,7}.yawSEM(:, [1 2]) = C{1,7}.yawSEM(:, [2 1]);
%     %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 
%     %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%     
    % add a virtual mouse that is the mean of all mean-others
        minRepsPerTracePerMouseToBeIncludedInMean=30;
        C=addMeanMouse(C,minRepsPerTracePerMouseToBeIncludedInMean);
    end
end

function C=getSpeedCurves(D)
    % Split the data in left, static, and rightward stimulation
    narginchk(1,1);
    % Split the data into subset with unique stimulus speed
    S=dpxdSplit(D,'rdk_aziDps');
    C.speed=[];
    for i=1:numel(S)
        C.speed(i)=S{i}.rdk_aziDps(1);
        C.mus{i}=S{i}.exp_subjectId{1};
        % Get the yaw that happened from half a second before the start of the
        % stimulus until the start of the stimulus. The mean of this will be the
        % baseline speed that we subtract from the whole yaw-trace a first step of
        % normalization, i.e., this removes the baseline
        preStimYaw=getYawTrace(S{i},[-.5:.05:0]); % 50 ms bins
        C.time{i} = [-.5:.05:3];
        C.yawRaw{i}=getYawTrace(S{i},C.time{i});
        % subtract the baseline speed
        for t=1:S{i}.N
            C.yaw{i}{t}=C.yawRaw{i}{t}-nanmean(preStimYaw{t});
        end
    end
    % Add the number of speeds. A field called N that contains the numbers of
    % elemenents per row of DPXD struct is required for any valid DPXD struct.
    C.N=numel(C.speed);
    if ~dpxdIs(C)
        error('not a valid DPXD!');
    end
    % ---- Sub function
    function yaw = getYawTrace(S,interval)
        % calculate the mean yaw for all trials in S over the specified interval
        yaw=cell(1,S.N);
        for tt=1:S.N
            from=interval(1)+S.rdk_motStartSec(tt);
            till=interval(end)+S.rdk_motStartSec(tt);
            % In dpxRespContiMouse, the moment of mouse readout is measured
            % using GetSecs and stored in tSec (shifted to trial start).
            % This seems to not work properly, there can be huge
            idx=S.resp_mouseBack_tSec{tt}>=from & S.resp_mouseBack_tSec{tt}<till;
            idx=idx(:)'; % make sure is row
            % Take the mean yaw from both computer mice reading the ball
            yaw{tt}=mean([S.resp_mouseSideYaw{tt}(idx);S.resp_mouseBackYaw{tt}(idx)],1);
            time=S.resp_mouseBack_tSec{tt}(idx);
            yaw{tt} = interp1(time,yaw{tt},interval+S.rdk_motStartSec(tt),'linear','extrap');
            
        end
        
        
        % I noticed thare is quite a bit of jitter on the samples, do a
        % linear interpolation here to straighten that out. Note that at
        % the beginning of the script any trial with too many framedrops
        % should have been discarded and datafiles with to many discarded
        % trials should be dropped entirely. Added this after discovering
        % teh massive jitter on 2016-07-05. It would be good to figure out
        % what causes the framedrops in the first place.
    end
end

function [D,percentTrials] = removeTrialWithTooManyFramedrops(D,thresholdPercent)
    % Remove trials with too many framedrops
    framesPerTrial = (D.stopSec-D.startSec).*D.window_measuredFrameRate;
    okTrials = (D.nrMissedFlips./framesPerTrial)*100<thresholdPercent;
    percentTrials = sum(~okTrials)/numel(okTrials)*100;
    D = dpxdSubset(D,okTrials);
end

function [D,str,suspect,maxCorr]=clarifyAndCheck(D)
    % Make some changes to the DPXD that make the analysis easier to read;
    % Step 1, align time of traces to the start of trial
    for t=1:D.N
        D.resp_mouseBack_tSec{t}=D.resp_mouseBack_tSec{t}-D.startSec(t);
        D.resp_mouseSide_tSec{t}=D.resp_mouseSide_tSec{t}-D.startSec(t);
    end
    % Step 2, remove offset from X value traces, because of monitor
    % settings in the Half Dome setup, the left-x is 0, and the control
    % computer starts at -1920. The Logitech mice are sampled on the
    % control monitor.
    for t=1:D.N
        D.resp_mouseBack_dxPx{t}=D.resp_mouseBack_dxPx{t}+1920;
        D.resp_mouseSide_dxPx{t}=D.resp_mouseSide_dxPx{t}+1920;
    end
    % Step 3, rename the mouse fields that code yaw (these should not
    % change from session to session but to be extra cautious we're gonna
    % assume nothing and figure out on a per file basis. Yaw is shared by
    % the back and the side Logitech, determine what combination
    % backdx,backdy,sizedx,sidedy has the most similar trace, these must
    % have been the yaw axes. Do this for all trials in a file, the mouse may
    % have been sitting still during a trial, and this method would fail if
    % only that trial was regarded.
    BdX=[];
    BdY=[];
    SdX=[];
    SdY=[];
    for t=1:D.N
        tSec=D.resp_mouseSide_tSec{t};
        idx=tSec>1 & tSec<max(tSec)-1;
        BdX=[BdX D.resp_mouseBack_dxPx{t}(idx)]; %#ok<AGROW>
        BdY=[BdY D.resp_mouseBack_dyPx{t}(idx)]; %#ok<AGROW>
        SdX=[SdX D.resp_mouseSide_dxPx{t}(idx)]; %#ok<AGROW>
        SdY=[SdY D.resp_mouseSide_dyPx{t}(idx)]; %#ok<AGROW>
    end
    maxCorr=-Inf;
    str='shouldhavebeenoverwritten';
    if std(BdX)==0 || std(BdY)==0 || std(SdX)==0 || std(SdY)==0
        warning('no variation in mouse signal, did the experimenter plug them in???');
        suspect=true;
        D.resp_mouseBackYaw=[];
        D.resp_mouseSideYaw=[];
        return;
    end
     if false && corr(BdX(:),SdX(:))>maxCorr % FALSE
         D.resp_mouseBackYaw=D.resp_mouseBack_dxPx;
         D.resp_mouseSideYaw=D.resp_mouseSide_dxPx;
         str='yaw are BdX and SdX - OPTION 1';
         maxCorr=corr(BdX(:),SdX(:));
     end
     if corr(BdY(:),SdY(:))>maxCorr
       D.resp_mouseBackYaw=D.resp_mouseBack_dyPx;
       D.resp_mouseSideYaw=D.resp_mouseSide_dyPx;
       str='yaw are BdY and SdY - OPTION 22';
       maxCorr=corr(BdY(:),SdY(:));
     end
     if false && corr(BdX(:),SdY(:))>maxCorr % FALSE
         D.resp_mouseBackYaw=D.resp_mouseBack_dxPx;
         D.resp_mouseSideYaw=D.resp_mouseSide_dyPx;
        str='yaw are BdX and SdY - OPTION 333';
         maxCorr=corr(BdY(:),SdY(:));
     end
     if false && corr(BdY(:),SdX(:))>maxCorr % FALSE
         D.resp_mouseBackYaw=D.resp_mouseBack_dyPx;
         D.resp_mouseSideYaw=D.resp_mouseSide_dxPx;
         str='yaw are BdY and SdX - OPTION 4444';
         maxCorr=corr(BdY(:),SdY(:));
     end
     % Step 4, smooth the data N*16.6667 ms running average (3 60-Hz samples is 50 ms) 
     SMOOTHFAC=19;
     if SMOOTHFAC>0
         for t=1:D.N
             %   D.resp_mouseBack_dxPx{t}=smooth(D.resp_mouseBack_dxPx{t},SMOOTHFAC,'sgolay')';
             %   D.resp_mouseBack_dyPx{t}=smooth(D.resp_mouseBack_dyPx{t},SMOOTHFAC,'sgolay')';
             %   D.resp_mouseSide_dxPx{t}=smooth(D.resp_mouseSide_dxPx{t},SMOOTHFAC,'sgolay')';
             %   D.resp_mouseSide_dyPx{t}=smooth(D.resp_mouseSide_dyPx{t},SMOOTHFAC,'sgolay')';
             
             D.resp_mouseBackYaw{t}=smooth(D.resp_mouseBackYaw{t},SMOOTHFAC)';
             D.resp_mouseSideYaw{t}=smooth(D.resp_mouseSideYaw{t},SMOOTHFAC)';
         end
     end
    
    % Step 5: Convert yaw pixels/frame to deg/s (added 20170710)
    scalar = jdDpxExpHalfDomeAuToDps;
    for i=1:numel(D.resp_mouseBackYaw)
        D.resp_mouseBackYaw{i}=D.resp_mouseBackYaw{i}*scalar;
        D.resp_mouseSideYaw{i}=D.resp_mouseSideYaw{i}*scalar;
    end
    
    % See if the file is up to snuff
    suspect = ~contains(str,'OPTION 2') || maxCorr<0.8;
         
end


function C=getMeanYawTracesPerMouse(C)
    % calculate mean traces per mouse (pooled over sessions)
    for i=1:numel(C)
        for v=1:C{i}.N
            % determine median length of trial, discard the trials that have a
            % different length. This should be rare but it is still better to use the
            % unequal length averaging. I don't know why that is currently commented
            % out, i must have had problems with that when i wrote it in Dec-2014. I'll
            % look into it again if the data is promising enough Jacob, 2015-05-18
            len=[];
            for tr=1:numel(C{i}.yaw{v})
                len(end+1)=numel(C{i}.yaw{v}{tr});
            end
            oklen=find(len==mode(len));
            if isempty(oklen)
                error('no trial with correct length');
            end
            fprintf('ok%% = %f\n',numel(oklen)/numel(len));
            if numel(oklen)/numel(len)<0.95
                error('lots of possibly salvageable data is being left out [w20170605]');
            end
            % [mn,n,sd]=dpxMeanUnequalLengthVectors(C{i}.preStimYaw{v},'align','end');
            
            % before 2018-12-10, Y was not instantiated or reset, this
            % meant that if a speed or mouse had more trials than the
            % subsequent steps in the loop, the higher trials would remain
            % in Y and carry over to the next speeds and or mice!
            %
            % Using Y=[] would do the trick too, but might as well preallocate for
            % efficiency because rows and column numbers are known
            Y=nan(numel(oklen),numel(C{i}.yaw{v}{oklen(1)})); 
            for tr=1:numel(oklen)
                Y(tr,:)=dpxMakeRow( C{i}.yaw{v}{oklen(tr)} );
            end
            C{i}.yawMean{v}=mean(Y,1);
            C{i}.yawSEM{v}=std(Y,1)/sqrt(size(Y,1));
            C{i}.yawN{v}=size(Y,1);
        end
    end
end

function C=addMeanMouse(C,minRepeats)
    % Calculate a mean of all mice and add it as an additional mouse called
    % 'MEAN'
    narginchk(2,2);
    nMice=numel(C);
    nSpeeds=C{1}.N;
    C{nMice+1}=C{1};
    for v=1:nSpeeds
        C{end}.mus{v}='MEAN';
        C{end}.yaw{v}={};
        C{end}.yawRaw{v}={};
        C{end}.yawMean{v}={};
        C{end}.yawSEM{v}={};
        C{end}.yawN{v}=0; % total number of lines (mice) that went into average
    end
    for v=1:nSpeeds
        for i=1:nMice
            if C{i}.yawN{v}>=minRepeats
                C{end}.yaw{v}{i}=C{i}.yawMean{v};
                C{end}.yawN{v}(1)=C{end}.yawN{v}(1)+1;
                C{end}.yawN{v}(end+1,1)=C{i}.yawN{v}; % in the end, yawN will be a list with yawN(1) the number of mice that went into it, and yaw(2:end) the number of trials of each of those mice
            else
                C{end}.yawRaw{v}{i}=nan(size(C{i}.yawMean{v}));
            end
        end
        [avg,num,sd]=dpxMeanUnequalLengthVectors(C{end}.yaw{v}); % ignores nan values
        C{end}.yawMean{v}=avg;
        C{end}.yawSEM{v}=sd./sqrt(num);
    end
end


function C=getOffsetPerSecond(C)
    nMice=numel(C);
    for i=1:nMice
        [~,order]=sort(abs(C{i}.speed));
        tel=0;
        for v=order(:)'
            tel=tel+1;
            if C{i}.speed(v)<0
                Nleft=min(numel(C{i}.time{v}),numel(C{i}.yawMean{v}));
                leftX=C{i}.time{v}(1:Nleft);
                leftY=C{i}.yawMean{v}(1:Nleft);
            elseif C{i}.speed(v)==0
                Nstat=min(numel(C{i}.time{v}),numel(C{i}.yawMean{v}));
                statX=C{i}.time{v}(1:Nstat);
                statY=C{i}.yawMean{v}(1:Nstat);
            elseif C{i}.speed(v)>0
                Nright=min(numel(C{i}.time{v}),numel(C{i}.yawMean{v}));
                riteX=C{i}.time{v}(1:Nright);
                riteY=C{i}.yawMean{v}(1:Nright);
            end
        end
        % Cut the arrays to the minimum length
        minN=min([Nleft Nstat Nright]);
        leftX=leftX(1:minN);
        leftY=leftY(1:minN);
        statX=statX(1:minN);
        statY=statY(1:minN);
        riteX=riteX(1:minN);
        riteY=riteY(1:minN);
        C{i}.leftDriftPerSecond=sum(leftY-statY)/(statX(end)-statX(1));
        C{i}.rightDriftPerSecond=sum(riteY-statY)/(statX(end)-statX(1));
    end
end

%     %%%%%%%%%%%%%%%%%    Switch Mouse 5 speeds     %%%%%%%%%%%%%%   LK 7-10-2017
%     curves.yaw(:, [9 10]) = curves.yaw(:, [10 9]);
%     curves.yawSem(:, [1 2]) = curves.yawSem(:, [10 9]);
%     %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function plotAllYawToCheckClipping(C,titleString)
    cpsFindFig(['YawBreaker' titleString]);
    for i=1:numel(C)
        subplot(ceil(numel(C)/5),5,i,'align');
        for s=1:numel(C{i}.yawRaw)
            for t=1:numel(C{i}.yawRaw{s})
                plot(C{i}.yawRaw{s}{t}(1:2:end),'Color',[0 0 1]);
                hold on;
            end
        end
        dpxYaxis(-1080/2,1080/2);
        dpxPlotHori(500,'r-');
        dpxPlotHori(-500,'r-');
    end
end

% function M = poolPositiveAndNegativeSpeed(M) 
%     % To pool the yaw-traces for the left and right stimuli, it doesn't
%     % suffice to simply flip the sign of one of them. That is because the
%     % zero stimulus rotation condition often has a non-zero yaw. That is,
%     % there is a bias. Therefore, first subtract the bias of all the yaw
%     % traces, then merge the + and - speed, and then calculate the mean, the
%     % SEM, and the N again. Do this on the yaw traces, not the yawRaw
%     % traces, because they don't have the pre-stim bias subtracted yet
%     Z=dpxdSubset(M,M.speed==0);
%     if Z.N==0
%         error('no zero stimulus speed');
%     end
%     % 1: subtract the bias curve from all raw yaws
% %     biasCurve=Z.yawMean{1};
% %     for v=1:M.N
% %         for r=1:numel(M.yaw{v})
% %             M.yaw{v}{r}=M.yaw{v}{r}-biasCurve;
% %         end
% %     end
%     Zunbiased=dpxdSubset(M,M.speed==0);
%     % 2: flip the -stim yaw curves and add them to corresponding +stim yaw
%     % curves. Also update yawN, and then calcute the new mean and SEM
%     absSpeeds = M.speed(M.speed>0);
%     for v=1:numel(absSpeeds)
%         P{v}=dpxdSubset(M,M.speed==absSpeeds(v)); % positive speed subset
%         N{v}=dpxdSubset(M,M.speed==-absSpeeds(v)); % corresponding negative speed subset
%         % flip the -stim yaw curves
%         N{v}.yaw{1} = cellfun(@(x)mtimes(-1,x),N{v}.yaw{1},'UniformOutput',false);
%         % concatenate them to the corresponding +stim yaw curves
%         P{v}.yaw{1} = [P{v}.yaw{1} N{v}.yaw{1}];
%         % also update the yawN; Note: this will be wrong and might crash if
%         % a mouse does have not have a positive and negative curve. no time
%         % to check for this now, let's hope it never happens or that this
%         % comment will make a solution simple.
%         P{v}.yawN{1}(1) = mean([P{v}.yawN{1}(1) N{v}.yawN{1}(1)]); % number of mice whose data went into the line
%         P{v}.yawN{1}(2:end) = P{v}.yawN{1}(2:end)+N{v}.yawN{1}(2:end); % number of traces per mouse
%         % calculate the new Mean and SEM for the pooled curves
%         [avg,num,sd]=dpxMeanUnequalLengthVectors(P{v}.yaw{1}); % ignores nan values
%         P{v}.yawMean{1}=avg;
%         P{v}.yawSEM{1}=sd./sqrt(num);
%     end
%     % 3. COmbine all positive speeds into one DPXD
%     P=dpxdMerge(P);
%     % 4. Calculate the new mean and SEM of the zero-speed condition, this
%     % should result in a flat mean-line by definition. Instead of just
%     % filling in zeros really do the calculation as an internal consisteny
%     % check
%     % 2017-07-04: the values are not zero... they are close, but not zero
%     [avg,num,sd]=dpxMeanUnequalLengthVectors(Zunbiased.yaw{1}); % ignores nan values
%     Zunbiased.yawMean{1}=avg;
%     Zunbiased.yawSEM{1}=sd./sqrt(num);
%     % 5. Combine the pooled-positive and the unbiased zero speed data into 1 DPXD
%     M=dpxdMerge({Zunbiased P});
%     
% end

function plotTimeYawCurves(A,fieldName,option)
    % Plot the Yaw as a function of time. Different colors indicate
    % different speeds. Data is split out in panels according to fieldName,
    % which could be, for example, 'contrast'
    narginchk(3,3);
    global intWinSec;
    if ~dpxdIs(A)
        error('First argument should be a DPXD');
    end
    if numel(unique(A.mus))>1
        error('plotTimeYawCurves is designed to plot the data of one mouse (typically the ''mean'' mouse)');
    end
    % open the figure
    figtit=[cell2mat(unique(A.mus)) ' time-yaw curves per ' fieldName];
    if ~isempty(option)
        if isnumeric(option) % timeWinSec
            figtit=[figtit ' (min. ' num2str(min(option/60)) ' to ' num2str(max(option/60)) ')'];
        elseif ischar(option)
            figtit=[figtit ' (' option ')'];
        end
    end
    cpsFindFig(figtit);
    clf; % clear the figure
    % Get a list of the unique values of fieldName
    values = unique(A.ctrlVar);
    % How many subplot will we need?
    nSubPlots = numel(values);
    % Decide on the number of colums and rows for the subplot
    if nSubPlots==3
        nCols=3;
        nRows=1;
    elseif nSubPlots==8
        nCols=4;
        nRows=2;
    else
        nCols = ceil(sqrt(nSubPlots));
        nRows = floor(sqrt(nSubPlots));
    end
    % Iterate over the different values of controlled variable
    for i = 1:numel(values)
        D = dpxdSubset(A,A.ctrlVar==values(i));
      %  D = poolPositiveAndNegativeSpeed(D); %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%NO POOL FOR REV PHI EXP %% LK 2017-09
        subplot(nRows,nCols,i,'align');
        [lineHandles,boundHandles] = deal(nan(size(D.speed)));
        lineLabels = cell(size(D.speed));
        for vi = 1:numel(D.speed)
            thisSpeed = D.speed(vi);
            V = dpxdSubset(D,D.speed==thisSpeed);
           % fade = abs(thisSpeed)/max(D.speed);
            fade = (thisSpeed)/max(D.speed);
            jacobVoorHetZeggen=false; %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%voor rev phi false LK 2017-09
            reversephi2speeds=true;
            if jacobVoorHetZeggen
                colmap = colormap('winter'); % goes from blue to green
                % make it go from blue to red, (cold --> hot)
                tmp = colmap(:,1);
                colmap(:,1)=colmap(:,2);
                colmap(:,2)=tmp; clear tmp;
            elseif reversephi2speeds
                negspeed = thisSpeed==-36;
                posspeed = thisSpeed==36;
                static = thisSpeed ==0;
            else
                colmap = flipud(colormap('hsv'));
                colmap(1,:)=[0 0 0];
            end
%             % select the color for this line from the colmap
%             colidx = round(size(colmap,1)*fade);
%             colidx = max(colidx,1); % prevent 0-index
%             col = colmap(colidx,:); % the line color
                if posspeed
                    col = [1 0 0];
                elseif negspeed
                    col = [0 0 1];
                elseif static
                    col = [0 0 0];
                end
            % Choose a linewidth (faster->bolder)
            wid = 2;% abs(0.5 + fade*3);
            %
            t = V.time{1};
            y = V.yawMean{1};
            sem = V.yawSEM{1};
            if numel(t)>numel(y)
                % the time axis is not always of the same length as the
                % mean yaw. this should be fixed at an earlier stage,
                % before the is problem occurs. but for now i'll just cut
                % off the end of the time axis
                t=t(1:numel(y));
            elseif numel(t)<numel(y)
                %  (or the end of y and sem
                y=y(1:numel(t));
                sem=sem(1:numel(t));
            end
            [hl,hb]=dpxPlotBounded('x',t(1:numel(y)),'y',y,'eu',sem,'ed',sem ...
                ,'LineColor',col,'FaceColor',col,'LineWidth',wid,'FaceAlpha',1/10);
            hold on;
            % ugly-print the number of mice that this line is the mean from
            % and the number of repeats that went into each mouse's line
            infoStr=[num2str(V.yawN{1}(1)) ' (' num2str(V.yawN{1}(2:end)') ')'];
            text(t(numel(y)),y(end),infoStr,'Color',col);
            lineHandles(vi) = hl;
            boundHandles(vi) = hb;
%             if thisSpeed>0
%                 lineLabels{vi} = ['\pm' num2str(thisSpeed) ' deg/s']; % \pm generates plus-minus sign
%             else
                lineLabels{vi} = [num2str(thisSpeed) ' deg/s'];
%             end
        end
        
        % make the time axis run from -.75 to 3 seconds
        axlims = axis;
        axlims(1:2) = [-.5 3];
        axis(axlims);
        % Draw a patch to indicate the area over which the mean is taken
        intwinHandle=fill([min(intWinSec) max(intWinSec) max(intWinSec) min(intWinSec)],...
            [axlims(3) axlims(3) axlims(4) axlims(4)],[.9 .9 .9],'EdgeColor','none');
        % Rearrange so the error boundaries are in front of the patch and
        % the lines are in the very front
        cpsArrange(boundHandles,'front')
        cpsArrange(lineHandles,'front')
        % set the label strings
        if i==1
            xlabel('Time since motion onset (s)');
            ylabel('Yaw (deg/s)');
        end
        % add a title to each panels, and legend to the first
        if values(i)==-1
            title(['Pooled over ' fieldName 's']);
            legend(gca,lineHandles,lineLabels,'Location','NorthWest');
        else
            title([fieldName ' = ' num2str(values(i),'%.2f')]);
        end
    end
    %  Give all panels the same range on the X and Y axes
    cpsUnifyAxes('XY');
%     cpsLabelPanels;                                               %%%%%%%%LK 2017-09 REV PHI%%%%%%%%%                                                        
end



function [out,figtit]=plotSpeedYawCurves(A,option,ctrlVar,gainOrYaw,phiOrIhp)
    % Plot the Yaw as a function of stimulus speed. Data is split in lines
    % with different colors according to stimulus contrast
    out.speeds=[];
    out.yaw=[];
    out.yawSem=[];
    out.ctrlVar=[];
    out.mouse={};
    out.N=0;
    global intWinSec
    if ~dpxdIs(A)
        error('First argument should be a DPXD');
    end
    if numel(unique(A.mus))>1
        error('plotSpeedYawCurves is designed to plot the data of one mouse (typically the ''mean'' mouse)');
    end
    % open the figure
    figtit=[cell2mat(unique(A.mus)) ' speed-yaw curves per ' ctrlVar];
    if ~isempty(option)
        if isnumeric(option)
            figtit=[figtit '(minute ' num2str(min(option/60)) ' to ' num2str(max(option/60)) ')'];
        elseif ischar(option)
            figtit=[figtit ' - ' option];
        end
    end
    figtit=[figtit ' - ' gainOrYaw ',' phiOrIhp];
    figHandle=cpsFindFig(figtit);
    clf; % clear the figures
%     subplot(1,2,1,'align'); %%%%%%%%%%%%%%% REV PHI LK 2017-09
    subplot(1,3,1,'align');
    
    % Remove the -1 ctrlVar data that contains the yaw pooled over all
    % ctrlVars (not split out according to ctrlVar)
    A=dpxdSubset(A,A.ctrlVar~=-1);
    % Get a list of the (remaining) unique ctrlVar values
    ctrlVars = unique(A.ctrlVar);
    if numel(ctrlVars)>1
        ctrlVarsNorm = ctrlVars-min(ctrlVars);
        ctrlVarsNorm = ctrlVarsNorm/max(ctrlVarsNorm);
    else
        ctrlVarsNorm=0.5;
    end
    % Get a list of unique absolute speeds. They are assumed to be present
    % and equal among all mice
%     speeds = unique(abs(A.speed));
    speeds = unique(A.speed);
    speeds(speeds==0)=[];
    % Iterate over the different ctrlVars
    lineHandles = nan(size(ctrlVars));
    lineLabels = cell(size(ctrlVars));
    for i = 1:numel(ctrlVars)
        D = dpxdSubset(A,A.ctrlVar==ctrlVars(i));
        %D = poolPositiveAndNegativeSpeed(D);%NO POOL FOR REV PHI EXP %% LK 2017-09
        
        yaw = nan(size(speeds)); % the y-axis values of this curve
        yawSem = yaw;
        for vi = 1:numel(speeds)
            thisSpeed = speeds(vi);
            V = dpxdSubset(D,D.speed==thisSpeed);
            idx = V.time{1}>=min(intWinSec) & V.time{1}<max(intWinSec);
            yaw(vi) = mean(V.yawMean{1}(idx));
            yawSem(vi) = mean(V.yawSEM{1}(idx));
            if strcmpi(gainOrYaw,'gain')
                yaw(vi)=yaw(vi)/speeds(vi);
                yawSem(vi)=yawSem(vi)/speeds(vi);
            end
        end
        
        
        colmap = flipud(colormap('parula')); % flip so that highest ctrlVar has highest ctrlVar color (black)
        % select the color for this line from the colmap
        colidx = round(size(colmap,1)*(0.2+0.8*ctrlVarsNorm(i))); % use only 80% of colmap (white/yellow is too bright)
        colidx = max(colidx,1); % prevent 0-index
        col = colmap(colidx,:); % the line color
        wid = 0.5 + ctrlVarsNorm(i)*2; %
        markers = 'osdv^<>ph';
        mark = markers(i);
        %lineHandles(i) = dpxPlotBounded('x',speeds,'y',yaw,'eu',yawSem,'ed',yawSem,'LineColor',col,'FaceColor',col,'LineWidth',wid,'FaceAlpha',.1);
        lineHandles(i) = errorbar(speeds,yaw,yawSem,'-','Color',col,'LineWidth',wid,'Marker',mark,'MarkerSize',15,'MarkerEdgeColor','none','MarkerFaceColor',col);
        hold on;
        lineLabels{i} = num2str(ctrlVars(i));
        %
        
        % Store xy and ctrlVar for output for later analysis
        out.speeds=[out.speeds speeds];
        out.yaw=[out.yaw yaw];
        out.yawSem=[out.yawSem yawSem];
        out.ctrlVar=[out.ctrlVar repmat(ctrlVars(i),size(yaw))];
        out.mouse=[out.mouse repmat(A.mus(1),size(yaw))];
        out.N=out.N+numel(yaw);
    end
    if ~dpxdIs(out), error('not a dpxd!!'); end
    % Send all lines to the front, so they are not occluded by the
    % shaded boundaries
    cpsArrange(lineHandles,'front')
    set(gca,'XTick',speeds);
    xlabel('Stimulus speed (deg/s)');
    if strcmpi(gainOrYaw,'gain')
        ylabel('OMR gain');
    else
        ylabel('Yaw (deg/s)');
    end
    legend(gca,lineHandles,lineLabels,'Location','NorthWest');
end

function plotCtrlVarYawCurves(figtit,curves,option,ctrlVar)
figHandle=cpsFindFig(figtit);
%     subplot(1,2,2,'align'); %%%%%%%%%%%%%%% REV PHI LK 2017-09
subplot(1,3,2,'align');
uCtrlVars=unique(curves.ctrlVar);
uSpeeds=unique(curves.speeds);
uSpeedsNorm=uSpeeds-min(uSpeeds);
uSpeedsNorm=uSpeedsNorm./max(uSpeedsNorm);
curves=dpxdSplit(curves,'speeds');
for i=1:numel(curves)
    % The line colors
    if (curves{i}.speeds(1))>0
        col = [1 0 0];
    elseif (curves{i}.speeds(1))<0
        col = [0 0 1];
    end
    wid = 0.5 + uSpeedsNorm(i)*2;
    markers = 'osdv^<>ph';
    mark = markers(i);
    %lineHandles(i) = dpxPlotBounded('x',speeds,'y',yaw,'eu',yawSem,'ed',yawSem,'LineColor',col,'FaceColor',col,'LineWidth',wid,'FaceAlpha',.1);
    lineHandles(i) = errorbar(curves{i}.ctrlVar,curves{i}.yaw,curves{i}.yawSem,'-','Color',col,'LineWidth',2,'Marker',mark,'MarkerSize',15,'MarkerEdgeColor','none','MarkerFaceColor',col); %Linewidth was wid, changed it to 2 %LK2017-08
    hold on;
    lineLabels{i} = num2str(curves{i}.speeds(1));
end
% cpsLimimts(
% set(gca,'XTick',uCtrlVars);
xlabel([ctrlVar ' (UNIT)']);
ylabel('Yaw (deg/s)');
legend(gca,lineHandles,lineLabels,'Location','NorthWest');
cpsLabelPanels;
end

function plotCtrlVarYawdifCurves(figtit,curves,option,ctrlVar)
figHandle=cpsFindFig(figtit);
subplot(1,3,3,'align');
curves=dpxdSplit(curves,'speeds');
difcurvesyaw=((curves{1,2}.yaw)-(curves{1,1}.yaw));
difcurvesyawSem=sqrt((curves{1,2}.yawSem).^2 + (curves{1,1}.yawSem).^2); % ((curves{1,2}.yawSem)-(curves{1,1}.yawSem));     %abs       % zeros(size(difcurvesyaw));  
for i=1:numel(curves)
    % select the color for this line from the colmap
    col = [0 0 0]; % the line color
    markers = 'osdv^<>ph';
    mark = markers(i);
    lineHandles(i) = errorbar(curves{i}.ctrlVar,difcurvesyaw,difcurvesyawSem,'-','Color',col,'LineWidth',2,'Marker',mark,'MarkerSize',15,'MarkerEdgeColor','none','MarkerFaceColor',col); %Linewidth was wid, changed it to 2 %LK2017-08
    hold on;
    lineLabels = 'Difference right-vs-left';
end
% cpsLimimts(
% set(gca,'XTick',uCtrlVars);
xlabel([ctrlVar ' (UNIT)']);
ylabel('Yaw (deg/s)');
legend(gca,lineHandles,lineLabels,'Location','NorthWest');
cpsLabelPanels;
end %%%%%%%%%%%%%%%%%%%% REV PHI 2017-09


function A=splitByContrast(E)
    
    % Add a mean background luminance field to E based on the RGBAfrac values
    % by calculates the mean of the first 3 elements of each 4-element array in
    % cell array E.mask_RGBAfrac
    %
    % HOEPLA,20160630: nu is de luminantie bepaald door rdk_RGBAfrac1, niet mask_RGBAfrac
    %
%     E.mask_grayFrac=cellfun(@(x)mean(x(1:3)),E.rdk_RGBAfrac1);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%LK REV PHI 2017-09%%%% 
%%%%%For reverse phi experiments, the mask_RGBAfrac was determining the luminance contrast, in other experiments it was fixed to 0.5 
if E.mask_RGBAfrac{1,1}(1) == 0.5 %not reverse-phi experiments with fixed mask value
    E.mask_grayFrac=cellfun(@(x)mean(x(1:3)),E.rdk_RGBAfrac1);
else
    E.mask_grayFrac=cellfun(@(x)mean(x(1:3)),E.mask_RGBAfrac); %%%%%%%%%LK REV PHI 2017-09 
end
    E.mask_grayFrac=round(E.mask_grayFrac*1000)/1000; % round to remove precission errors
    lumsUsed=unique(E.mask_grayFrac);
    lumsUsed=[lumsUsed -1]; % add -1 to analyze the pooled data also
    %
    % Run the analyze function for the each luminance separately. collect
    % in a cell array called A (for Analysis)
    A = {}; % start empty
    for i=1:numel(lumsUsed)
        if lumsUsed(i)==-1
            tmpA = analyzeAcrossMiceAndSpeeds(E); % all lums
        else
            tmpA = analyzeAcrossMiceAndSpeeds(dpxdSubset(E,E.mask_grayFrac==lumsUsed(i)));
        end
        % Add a luminance field to all the mouse data
        for mi = 1:numel(tmpA) % mi for mouse index
            tmpA{mi}.ctrlVar = ones(1,tmpA{mi}.N) * lumsUsed(i);
        end
        A = [A tmpA];
    end
end


function A=splitByDotDiam(E)
    % "dots" on the screen in this experiment were clusters, or groups of
    % dots so that the shape of the dot could remain maximally circular at
    % all eccentrities in the projection dome.
    % Calculate the diameter of the "clusters", it's a sum of the cluster
    % diameter and the diamter of the dots that comprise the cluster
    
    degPerPx = 270/E.window_rectPx{1}(3); % the projection dome covered 270 deg
    E.dotRadiusCorrected = E.rdk_clusterRadiusDeg + E.rdk_dotDiamPx/2*degPerPx;
    
    radiiUsed=unique(E.dotRadiusCorrected);
    radiiUsed=[radiiUsed -1]; % add -1 to analyze the pooled data also
    %
    % Run the analyze function for the each dotdiam separately. collect
    % in a cell array called A (for Analysis)
    A = {}; % start empty
    for i=1:numel(radiiUsed)
        if radiiUsed(i)==-1
            tmpA = analyzeAcrossMiceAndSpeeds(E); % all lums
        else
            tmpA = analyzeAcrossMiceAndSpeeds(dpxdSubset(E,E.dotRadiusCorrected==radiiUsed(i)));
        end
        % Add a luminance field to all the mouse data
        for mi = 1:numel(tmpA) % mi for mouse index
            tmpA{mi}.ctrlVar = ones(1,tmpA{mi}.N) * radiiUsed(i);
        end
        A = [A tmpA];
    end
end

function A=splitByFreezeFlips(E)                    %LK 2017-08
    %freezeflips are delays of frames before going to the next
    
    freezeflipUsed=unique(E.rdk_freezeFlip);
%     freezeflipUsed=[freezeflipUsed -1];     % add -1 to analyze the pooled data also
    freezeflipUsed=[1 2 3 4 5 6 7 -1];        %  5 6 7 -1  %ONLY LOOK AT freezeflip 2
   
%     % There was a problem. The speed zero stimuli were only programmed for
%     % unlimited lifetime motion. This was a mistake as we are interested
%     % in the responses were to zero-speed motion that was flickering too.
%     % We will have to use the zero-speed unlimited motion conditions as a
%     % proxy for all zero-speed responses. WE can check the validity of
%     % thisassupmption by comparin gthe responses to the 1 to 2 seconds
%     % zero-speed motion that preceeds each trail, ie., see if the responses
%     % are different in those (for example, on may predict more variance in
%     % the response to the zero-speed stim with limited lifetime (more
%     % flicker))
%     %
%     % Assuming for now that this is valid, I will know copy the trials with
%     % zero-speed and unlimited lifetime into the data table, and "pretend"
%     % they were recorded with limited life so that they can serve as
%     % baseline for the limited lifetime conditions.
%     
%     warning('check required, flicker vs no-flicker zero-speed response');
%     STATIONARY=dpxdSubset(E,E.rdk_aziDps==0);
%     if numel(unique(STATIONARY.rdk_freezeFlip))>1
%         error('we assumed only one freezeflip was used for the zero-speed stim');
%     end
%     for i=1:numel(freezeflipUsed)
%         if freezeflipUsed(i)==1 || freezeflipUsed(i)<0
%             continue;
%         end
%         STATIONARY.rdk_freezeFlip=ones(size(STATIONARY.rdk_freezeFlip))*freezeflipUsed(i);
%         E=dpxdMerge([E STATIONARY]);
%     end  
    %
    % Run the analyze function for each freezeflip separately. collect
    % in a cell array called A (for Analysis)
    A = {}; % start empty
    for i=1:numel(freezeflipUsed)
        if freezeflipUsed(i)==-1
            tmpA = analyzeAcrossMiceAndSpeeds(E); % all flips
        else
            tmpA = analyzeAcrossMiceAndSpeeds(dpxdSubset(E,E.rdk_freezeFlip==freezeflipUsed(i)));
        end
        for mi = 1:numel(tmpA) % mi for mouse index
            tmpA{mi}.ctrlVar = ones(1,tmpA{mi}.N) * freezeflipUsed(i);
        end
        A = [A tmpA];
    end
end

%function A=splitByFreezeFlips(E)   voor transparancy

