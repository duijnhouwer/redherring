function jdDpxExpHalfDomeRdkAnalysisSpeed(files)
    if nargin==0
        files=dpxUIgetFiles;
        disp([num2str(numel(files)) ' datafiles selected.']);
        if isempty(files)
            return;
        end
    end
    E={};
    for i=1:numel(files)
        D=dpxdLoad(files{i});
        maxFrDropsPerSec=1;
        [D,percentBadTrials] = removeTrialWithTooManyFramedrops(D,maxFrDropsPerSec/D.window_measuredFrameRate(1)*100);
        disp(['File #' num2str(i,'%.3d') ': ' num2str(round(percentBadTrials)) '% of trials had more than ' num2str(maxFrDropsPerSec) ' video-frame drop per second']);
        if percentBadTrials>90
            fprintf(' ---> skipping file : %s\n', files{i} );
            continue; 
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
    % Add a mean background luminance field to E based on the RGBAfrac values
    % by calculates the mean of the first 3 elements of each 4-element array in
    % cell array E.mask_RGBAfrac
    %
    % HOEPLA,20160630: nu is de luminantie bepaald door rdk_RGBAfrac1, niet mask_RGBAfrac
    %
    E.mask_grayFrac=cellfun(@(x)mean(x(1:3)),E.rdk_RGBAfrac1);
    E.mask_grayFrac=round(E.mask_grayFrac*1000)/1000; % round to remove precission errors
    lumsUsed=unique(E.mask_grayFrac);
    lumsUsed=[lumsUsed -1]; % add -1 to analyze the pooled data also
    %
    % Run the analyze function for the each luminance separately. collect
    % in a cell array call A (for Analysis)
    A = {}; % start empty
    for i=1:numel(lumsUsed)
        if lumsUsed(i)==-1
            tmpA = analyzeAcrossMiceAndSpeeds(E,'; Lum=ALL');
        else
            tmpA = analyzeAcrossMiceAndSpeeds(dpxdSubset(E,E.mask_grayFrac==lumsUsed(i)),['; Lum=' num2str(lumsUsed(i))]);
        end
        % Add a luminance field to all the mouse data
        for mi = 1:numel(tmpA) % mi for mouse index
            tmpA{mi}.contrast = ones(1,tmpA{mi}.N) * lumsUsed(i);
        end
        A = [A tmpA];
    end
    A = dpxdMerge(A); % combine into one DPXD again
    %
    % Plot the speed curves for 1 mouse in separate panels for contrast
    M = dpxdSubset(A,strcmpi(A.mus,'MEAN'));
    plotSpeedCurves(M,'contrast')
end


function C = analyzeAcrossMiceAndSpeeds(E,titleString)
    % This function return a cell for each mouse with the yaw-traces (raw
    % and mean) for each speed used. The last cell will contain a virtual
    % mouse that is the mean of all the other.
    %
    % If you want to analyze the effect of different properties (than mouse
    % and speed), split the data and call this function is a for loop over
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
    for i=1:numel(E)
        C{i}=getSpeedCurves(E{i},true);
    end
    % Make a plot of the raw yaw traces, to visual inspect for clipping
    %plotAllYawToCheckClipping(C,titleString);
    % calculate mean traces per mouse (pooled over sessions)
    C=getMeanYawTracesPerMouse(C);
    % add a virtual mouse that is the mean of all mean-others
    minRepsPerTracePerMouseToBeIncludedInMean=10;
    C=addMeanMouse(C,minRepsPerTracePerMouseToBeIncludedInMean);
    %
    %  C=getOffsetPerSecond(C);
    % plot the curves, panel per mouse
    % plotTraces(C,titleString);
    % plot the drifts relative to stat
    % plotDriftScatter(C,titleString);
end

function C=getSpeedCurves(D,poolLeftRight)
    % Split the data in left, static, and rightward stimulation
    narginchk(2,2);
    if poolLeftRight
        [L,R] = dpxdSubset(D,D.rdk_aziDps<0);
        % Convert the Leftward motion trials AS IF they were righward
        % motion trials by flipping the sign of the stimulus speed and of
        % the yaw-repsonse;
        L.rdk_aziDps = -L.rdk_aziDps;
        for i = 1:L.N
            L.resp_mouseSideYaw{i} = -L.resp_mouseSideYaw{i};
            L.resp_mouseBackYaw{i} = -L.resp_mouseBackYaw{i};
        end
        D = dpxdMerge({L,R});
    end
    % Split the data into subset with unique stimulus speed
    S=dpxdSplit(D,'rdk_aziDps');
    C.speed=[];
    for i=1:numel(S)
        C.speed(i)=S{i}.rdk_aziDps(1);
        C.mus{i}=S{i}.exp_subjectId{1};
        % Get the yaw that happened from half a second before the start of the
        % stimulus until the start of the stimulus. This mean of this will be the
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
            % Take the mean yaw from both computer mouse reading the ball
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
    suspect=false;
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
    % Step 3, smooth the data N*16.6667 ms running average (3 60-Hz samples is 50 ms)
    SMOOTHFAC=3;
    for t=1:D.N
        D.resp_mouseBack_dxPx{t}=smooth(D.resp_mouseBack_dxPx{t},SMOOTHFAC)';
        D.resp_mouseBack_dyPx{t}=smooth(D.resp_mouseBack_dyPx{t},SMOOTHFAC)';
        D.resp_mouseSide_dxPx{t}=smooth(D.resp_mouseSide_dxPx{t},SMOOTHFAC)';
        D.resp_mouseSide_dyPx{t}=smooth(D.resp_mouseSide_dyPx{t},SMOOTHFAC)';
    end
    % Step 4, rename the mouse fields that code yaw (these should not
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
    if corr(BdX(:),SdX(:))>maxCorr;
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
    if corr(BdX(:),SdY(:))>maxCorr
        D.resp_mouseBackYaw=D.resp_mouseBack_dxPx;
        D.resp_mouseSideYaw=D.resp_mouseSide_dyPx;
        str='yaw are BdX and SdY - OPTION 333';
        maxCorr=corr(BdY(:),SdY(:));
    end
    if corr(BdY(:),SdX(:))>maxCorr
        D.resp_mouseBackYaw=D.resp_mouseBack_dyPx;
        D.resp_mouseSideYaw=D.resp_mouseSide_dxPx;
        str='yaw are BdY and SdX - OPTION 4444';
        maxCorr=corr(BdY(:),SdY(:));
    end
    if maxCorr<0.8
        suspect=true;
        %   keyboard
    end
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
            ok=find(len==median(len));
            if isempty(ok)
                error('no trial with correct length');
            end
            % [mn,n,sd]=dpxMeanUnequalLengthVectors(C{i}.preStimYaw{v},'align','end');
            for tr=1:numel(ok)
                Y(tr,:)=dpxMakeRow( C{i}.yaw{v}{ok(tr)} );
            end
            C{i}.yawMean{v}=mean(Y,1);
            C{i}.yawSEM{v}=std(Y,1)/sqrt(size(Y,1));
            C{i}.yawN{v}=size(Y,1);
            %   C{i}.preStimYawN{v}=n;
            %   C{i}.preStimYawSd{v}=sd;
            %  [mn,n,sd]=dpxMeanUnequalLengthVectors(C{i}.conStimYaw{v},'align','begin');
            %            C{i}.conStimYawMean{v}=mn;
            %   C{i}.conStimYawN{v}=n;
            %   C{i}.conStimYawSd{v}=sd;
        end
    end
end

function C=addMeanMouse(C,minRepeats)
    % Calculate a mean of all mice and add it as an additional mouse called
    % 'MEAN'
    narginchk(2,2);
    nMice=numel(C);
    C{nMice+1}=C{1};
    for v=1:C{end}.N % v for speed
        C{end}.mus{v}='MEAN';
        C{end}.yaw{v}={};
        C{end}.yawRaw{v}={};
        C{end}.yawMean{v}={};
        C{end}.yawSEM{v}={};
        C{end}.yawN{v}=0;
    end
    for v=1:C{end}.N % v for speed
        for i=1:numel(C)-1
            if C{i}.yawN{v}>=minRepeats
                C{end}.yawRaw{v}{i}=C{i}.yawMean{v};
                C{end}.yawN{v}=C{end}.yawN{v}+1;
            else
                C{end}.yawRaw{v}{i}=nan(size(C{i}.yawMean{v}));
            end
        end
        [avg,num,sd]=dpxMeanUnequalLengthVectors(C{end}.yawRaw{v}); % ignorse nan values
        C{end}.yawMean{v}=avg;
        C{end}.yawSEM{v}=sd./sqrt(num);
        C{end}.yawN{v}=num;
    end
end

function plotTraces(C,str)
    % Plot the traces per speed, with colored areas to highlight the difference
    % between left, static, and rightward stimulation
    dpxFindFig(['TheWayOfTheMouse ' str]);
    nMice=numel(C);
    for i=1:nMice
        [~,order]=sort(abs(C{i}.speed));
        subplot(ceil(nMice/3),3,i)
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
        minN=min([Nleft Nstat Nright]);
        leftX=leftX(1:minN);
        leftY=leftY(1:minN);
        statX=statX(1:minN);
        statY=statY(1:minN);
        riteX=riteX(1:minN);
        riteY=riteY(1:minN);
        % PLot the areas
        patch([leftX leftX(end:-1:1)],[statY leftY(end:-1:1)],'r','FaceAlpha',.1,'LineStyle','none');  hold on
        patch([riteX riteX(end:-1:1)],[statY riteY(end:-1:1)],'b','FaceAlpha',.1,'LineStyle','none');
        % Plot the lines
        plot(leftX,leftY,'LineStyle','-','LineWidth',2,'Color','r');
        plot(statX,statY,'LineStyle','-','LineWidth',2,'Color','k');
        plot(riteX,riteY,'LineStyle','-','LineWidth',2,'Color','b');
        %
        axis tight
        dpxText(C{i}.mus{1});
        dpxPlotHori(0,'k--');
        dpxPlotVert(0,'k--');
        xlabel('Time since motion onset (s)');
        ylabel('Yaw (a.u.)');
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


function plotDriftScatter(C,titleString)
    dpxFindFig(['DriftScatter' titleString]);
    x=[];
    y=[];
    for i=1:numel(C)-1 % don't include the pooled mouse
        x(i)=C{i}.leftDriftPerSecond;
        y(i)=C{i}.rightDriftPerSecond;
    end
    dpxScatStat(x,y,'test','ttest');
    xlabel('Speed during left - speed during static (a.u/second)');
    ylabel('Speed during right - speed during static (a.u/second)');
end


function plotAllYawToCheckClipping(C,titleString)
    dpxFindFig(['YawBreaker' titleString]);
    for i=1:numel(C)
        subplot(ceil(numel(C)/5),5,i);
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


function plotSpeedCurves(A,fieldName)
    narginchk(2,2);
    if ~dpxdIs(A)
        error('First argument should be a DPXD');
    end
    if ~ischar(fieldName) || ~isfield(A,fieldName)
        error('Second argument should be fieldname of the DPXD (first input)');
    end
    if numel(unique(A.mus))>1
        error('plotSpeedCurves is designed to plot the data of one mouse (typically the ''mean'' mouse)');
    end
    % open the figure
    dpxFindFig(['per' fieldName]);
    clf; % clear the figure
    % Get a list of the unique values of fieldName
    values = unique(A.(fieldName));
    % How many subplot will we need?
    nSubPlots = numel(values);
    % Decide on the number of colums and rows for the subplot
    nCols = ceil(sqrt(nSubPlots));
    nRows = floor(sqrt(nSubPlots));   
    % Iterate over the different values of fieldname
    for i = 1:numel(values)
        D = dpxdSubset(A,A.(fieldName)==values(i));
        subplot(nRows,nCols,i);
        lineHandles = nan(size(D.speed));
        lineLabels = cell(size(D.speed));
        for vi = 1:numel(D.speed)
            thisSpeed = D.speed(vi);
            V = dpxdSubset(D,D.speed==thisSpeed);
            fade = abs(thisSpeed)/max(D.speed);
            colmap = colormap('winter'); % goes from blue to green
            % make it go from blue to red, (cold --> hot)
            tmp = colmap(:,1);
            colmap(:,1)=colmap(:,2);
            colmap(:,2)=tmp; clear tmp;
            % select the color for this line from the colmap
            colidx = round(size(colmap,1)*fade);
            colidx = max(colidx,1); % prevent 0-index
            col = colmap(colidx,:); % the line color
            % Choose a linewidth (faster->bolder)
            wid = abs(0.5 + fade*3);
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
            hl=dpxPlotBounded('x',t(1:numel(y)),'y',y,'eu',sem,'ed',sem,'LineColor',col,'FaceColor',col,'LineWidth',wid);
            hold on;
            lineHandles(vi) = hl;
            if thisSpeed>0
                lineLabels{vi} = ['\pm' num2str(thisSpeed) ' deg/s']; % \pm generates plus-minus sign
            else
                lineLabels{vi} = [num2str(thisSpeed) ' deg/s'];
            end
        end
        % Send all lines to the front, so they are not occluded by the
        % shaded boundaries
        cpsArrange(lineHandles,'front')
        % make the time axis run from -.75 to 3 seconds
        axlims = axis;
        axlims(1:2) = [-.75 3];
        axis(axlims);
        % set the label strings
        if i==1
            xlabel('Time since motion onset (s)');
            ylabel('Yaw (A.U.)');
        end
        % add a title to each panels, and legend to the first
        if values(i)==-1
            title('Pooled over contrasts');
            legend(gca,lineHandles,lineLabels,'Location','NorthWest');
        else
            title(['Contrast = ' num2str(values(i),'%.2f')]);
        end
    end
    %  Give all panels the same range on the X and Y axes
    cpsUnifyAxes('XY');
end









