classdef dpxCoreCondition < hgsetget
    
    properties (Access=public)
        durSec;
        overrideBackRGBA;
        breakFixGraceSec;
    end
    properties (SetAccess=protected,GetAccess=public)
        % Cell array of stimulus objects (e.g. dpxStimDot) to be added using
        % addStim
        stims={};
        % Cell array of response objects (e.g. dpxRespKeyBoard) to be added using
        % addStim
        resps={};
        % Cell array of trial-trigger objects (e.g. dpxTriggerKey) to be added
        % using addTrialTrigger
        trigs={};
    end
    properties (Access=protected)
        % The duration of the trial in flips, calculated in init
        nFlips;
        % Structure that will hold copies of the getable values in scr
        scrGets=struct;
        % Counter for breakfixation grace period
        flipsSinceBreakFix;
        breakFixGraceFlips;
    end
    methods (Access=public)
        function C=dpxCoreCondition
            % The duration of this condition (unless prematurely ended by a response,
            % see below)
            C.durSec=2;
            % Leave this 'false' to use the backRGBA defined in the dpxCoreWindow
            % class, or set it to a 4-element RGBA vector. The advantage of this design
            % is that the RGBA for the background doesn't have to be defined for each
            % condition as most of the time the background will be the same for all
            % conditions
            C.overrideBackRGBA=false;
            C.breakFixGraceSec=.2; % how long does a blink last??
        end
        function init(C,scrGets)
            % Initialize the dpxCoreCondition object Store a copy of the values in scr,
            % do not change any of these values (I would make them read only if Matlab
            % allowed for that). Changing scrGets won't change the scr object from
            % which they were derived. Doing so would mess up any calculations that
            % depend on them.
            C.scrGets=scrGets;
            % Calculate the duration of the trial in flips
            C.nFlips=round(C.durSec*C.scrGets.measuredFrameRate);
            % Initialize all stimulus objects that have been added using calls to
            % addStim in the experiment script.
            for s=1:numel(C.stims)
                C.stims{s}.init(scrGets);
            end
            % Initialize all response objects that have been added using calls to
            % addStim in the experiment script.
            for r=1:numel(C.resps)
                C.resps{r}.init(scrGets);
            end
            % Initialize all trialtriggers (set the trigger state to false)
            for t=1:numel(C.trigs)
                C.trigs{r}.init();
            end
            C.flipsSinceBreakFix=[];
            C.breakFixGraceFlips=round(C.breakFixGraceSec*C.scrGets.measuredFrameRate);
        end
        function [completionStatus,timingStruct,respStruct,nrMissedFlips]=show(C)
            % This is the function called from dpxCoreExperiment as it works itself
            % through the list of trials...
            if isempty(C.scrGets)
                error('dpxCoreCondition has not been initialized');
            end
            completionStatus='OK';
            stopTrialEarlyFlip=Inf;
            % Initialize the timing struct
            timingStruct.startSec=-1;
            timingStruct.stopSec=-1;
            % Initialize the responses with the null response
            if numel(C.resps)==0
                respStruct=[];
            else
                for r=1:numel(C.resps)
                    respStruct.(C.resps{r}.name)=C.resps{r}.resp;
                end
            end
            % Figure out which stimulus needs to be fixated, if any
            stimNumberToFixate=[];
            for s=1:numel(C.stims)
                if C.stims{s}.fixWithinDeg>0
                    if ~isempty(stimNumberToFixate)
                        error('Only one stimulus can have fixWithinDeg>0!');
                    end
                    stimNumberToFixate=s;
                end
            end
            % Initialize the video-blank timeer
            vbl=Screen('Flip',C.scrGets.windowPtr,0);
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Loop over all video-flips (frames) of the trial
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            nrMissedFlips=0;
            breakKeys={'Escape','Pause'};
            f=0; % flipCounter, locks in 0 until f=1 is set after ...
            waitingForFixation=true; % the fixation stimulus is fixated (if eyelink is used)
            waitingForTriggers=true; % and the optional dpxTrialTriggers are all satified (typically keypress)
            while f<=C.nFlips
                % Lock in frame-0 until all trial-triggers are go. Stimuli with onSec<=0
                % will show already (e.g. fixation dot waiting for go-condition fixation
                % using eyelink)
                if f>0
                    f=f+1; % increment flip counter since lock release
                else
                    nGo=0;
                    for g=1:numel(C.trigs)
                        nGo=nGo+C.trigs{g}.go;
                    end
                    if nGo==numel(C.trigs)
                        waitingForTriggers=false; % Lift the lock
                    end
                end
                % Check the break keys
                keyIdx=dpxGetKey(breakKeys);
                if keyIdx>0
                    completionStatus=breakKeys{keyIdx};
                    break;
                end
                % Step, draw the stimuli
                for s=numel(C.stims):-1:1
                    C.stims{s}.stepAndDraw(f);
                end
                Screen('DrawingFinished',C.scrGets.windowPtr);
                % Check the gaze-fixation status
                if isempty(stimNumberToFixate)
                    % No fixation is required in this condition, so simply release the fixation
                    % lock immediately
                    if f==0
                        waitingForFixation=false;
                    end
                else
                    % Fixation is required, check if the stimulus that needs fixation is indeed
                    % being looked at
                    [ok,str]=C.stims{stimNumberToFixate}.fixationStatus;
                    if ~ok
                        % Stimulus is not being looked at
                        if f==0
                            % just keep waiting for first-fixation
                        elseif isempty(C.flipsSinceBreakFix)
                            % fixation interrupted, enter grace period
                            C.flipsSinceBreakFix=C.breakFixGraceFlips;
                        else
                            C.flipsSinceBreakFix=C.flipsSinceBreakFix-1;
                            if C.flipsSinceBreakFix<0
                                % fixation not restored in time, stop the trial
                                completionStatus=str;
                                break;
                            end
                        end
                    else
                        % Stimulus is being looked at
                        if f==0 
                            % release the flip-zero lock
                            waitingForFixation=false;
                        else
                            if f==1
                                Eyelink('Message', 'STARTTRIAL'); % set a time-stamp in the EDF file on the Eyelink computer (this function takes ~0.000091 seconds on a 2008 iMac)
                            end
                            % fixation was restored within the graceperiod
                            C.flipsSinceBreakFix=[];
                        end
                    end
                end
                if f==0 && ~waitingForTriggers && ~waitingForFixation
                    f=1; % start the trial, timestamp collected after flip below (will correspond to STARTTRIAL in EDF if eyelink is used
                end
                % Get the response(s)
                for r=1:numel(C.resps)
                    if ~C.resps{r}.given
                        C.resps{r}.getResponse(f);
                        % store when answer is given; or at last flip of trial (useful for
                        % continuous resp recordings)
                        if C.resps{r}.given || f==C.nFlips
                            respStruct.(C.resps{r}.name)=C.resps{r}.resp;
                            % Set the new end time of the trial. This way giving the response can stop
                            % the trial. If the new time exceeds the original stop time, this has no
                            % effect and the trial lasts the set initially amount.
                            if C.resps{r}.endsTrialAfterFlips<Inf % endsTrialAfterFlips is Inf by default
                                stopTrialEarlyFlip=f+C.resps{r}.endsTrialAfterFlips;
                                stimHandle=C.getStimNamed(C.resps{r}.nameOfFeedBackStim);
                                if ~isempty(stimHandle)
                                    % Initialize the feedback stimulus so it will be visible from now until
                                    % now+durSec. Because of this only simple stimuli that do not require a lot
                                    % of time for initialization can be used. If this is a problem a slight
                                    % redesign of the feedback system will be required.
                                    stimHandle.init(C.scrGets);
                                    stimHandle.visible=true;
                                end
                            end
                            % Check if this response has been set up to necessitate a redo of the
                            % condition. For example in experiments in which the subjects (typically
                            % animals) were not allowed to respond before the end of the stimulus and the
                            % trial was prematurely ended because they did. It is up to definition of
                            % the response class to set this depending on the logic of the condition
                            % (see dpxRespArduinoPulse for an example)
                            if ~strcmpi(C.resps{r}.redoTrial,'never')
                                if strcmpi(C.resps{r}.redoTrial,'immediately')
                                    completionStatus='REDOTRIALNOW';
                                elseif strcmpi(C.resps{r}.redoTrial,'sometime')
                                    completionStatus='REDOTRIAL';
                                else
                                    error(['illegal redoTrial string: ' C.resps{r}.redoTrial]);
                                end
                            end
                        end
                    end
                end
                % Wait until it's time, then flip the video buffer
                [vbl,~,~,dDeadlineSecs]=Screen('Flip',C.scrGets.windowPtr,vbl+0.85/C.scrGets.measuredFrameRate);
                % If this flip missed the deadline, increase the nrMissedFlips counter.
                % Note that the 'Screen flip?' documentation of Psychtoolbox states that
                % "... The automatic detection of deadline-miss is not fool-proof ..."
                if dDeadlineSecs>0
                    nrMissedFlips=nrMissedFlips+1;
                end
                % Collect start or stop time of the trial in seconds, right after the flip
                % for accuracy.
                if f==1 % begin of condition
                    timingStruct.startSec=GetSecs;
                elseif f==C.nFlips || f>=stopTrialEarlyFlip % planned or early (because of response) end of trial
                    timingStruct.stopSec=GetSecs;
                    break;
                end
            end
            % The trial is now complete, clear all stim and resp objects
            for s=1:numel(C.stims)
                C.stims{s}.clear;
            end
            for r=1:numel(C.resps)
                C.resps{r}.clear;
            end
        end
        function addStim(C,S)
            % Add a stimulus object to the condition
            if isempty(S.name)
                % If no name is provided (not recommended) use the class name of the object
                % as the stimulus name that will show up in the output DPXD struct
                S.name=class(S);
            end
            % Store all values of the public (interface) variables of the stimulus so
            % the condition can be reset during init before a repeat of the same
            % conditon is shown;
            S.lockInitialPublicState;
            C.stims{end+1}=S;
            % Check that all responses have unique names, this is important for the
            % output format (DPXD)
            nameList=cellfun(@(x)get(x,'name'),C.stims,'UniformOutput',false);
            if numel(nameList)~=numel(unique(nameList))
                disp(nameList);
                error('All stimuli in a condition need a unique name');
            end
        end
        function addResp(C,R)
            % Add a response object to the condition
            if isempty(R.name)
                R.name=class(R); % no name provided default to classname
            end
            C.resps{end+1}=R;
            % Check that the name is not 'none', this is an reserved name
            if strcmpi(R.name,'none')
                error(['Reponse object name cannot be ''' R.name '''.']);
            end
            % Check that all responses have unique names, this is important for the
            % output format (DPXD)
            nameList=cellfun(@(x)get(x,'name'),C.resps,'UniformOutput',false);
            if numel(nameList)~=numel(unique(nameList))
                disp(nameList);
                error('All responses in a condition need a unique name');
            end
        end
        function addTrialTrigger(C,G)
            % Add a trial-trigger object to the condition
            if isempty(G.name)
                G.name=class(G); % no name provided default to classname
            end
            C.trigs{end+1}=G;
            % Check that all trialTriggers have unique names, this is important for the
            % output format (DPXD)
            nameList=cellfun(@(x)get(x,'name'),C.trigs,'UniformOutput',false);
            if numel(nameList)~=numel(unique(nameList))
                disp(nameList);
                error('All TrialTriggers in a condition need a unique name');
            end
        end
    end
    methods (Access=protected)
        function stimHandle=getStimNamed(C,name)
            % Returns a handle to the stimulus whose name field corresponds to the
            % string in name
            stimHandle=[];
            if isempty(name)
                return;
            end
            for s=1:numel(C.stims)
                if strcmpi(C.stims{s}.name,name)
                    stimHandle=C.stims{s};
                    return;
                end
            end
            error(['No stimulus named ''' name ''' exists.']);
        end
    end
    methods
        function set.overrideBackRGBA(C,value)
            ok=(islogical(value) && value==false) || dpxIsRGBAfrac(value);
            if ~ok
                error('overrideBackRGBA needs to be false or a 4-element vector of numerical values between 0 and 1');
            else
                C.overrideBackRGBA=value;
            end
        end
        function set.durSec(C,value)
            if ~isnumeric(value)
                error('Condition duration (durSec) has to be a numeric value');
            elseif value<=0
                error('Condition duration (durSec) has to be longer than zero');
            elseif value>3600*24*7
                % User probably defined the duration to be infinite (Inf) and uses the
                % response to quit the trials. The for-loop in show does not take
                % end-values larger than intmax without complaining with a warning.
                % Therefore, silently truncate the value here to a week in seconds, likely
                % enough for any experiment.
                % 2015-04-14: just occured to me that the show loop of the condition is not
                % a for loop anymore. Inf values should be no problem. I'm leaving this is
                % for now, no time to test at now. MARKED FOR CLEANUP
                value=3600*24*7;
            end
            C.durSec=value;
        end
    end
end
