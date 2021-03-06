function tc=calcDirectionTuningCurve(DPXD,cellNr,varargin)
    
    if nargin==1 && strcmp(DPXD,'info')
        tc.per='cell';
        return;
    end
    % This function calculates a direction tuning curve from a
    % lkDpxExpGrating-DPXD struct, its output can be plot with the
    % complementary plotDirectionTuningCurve
    
    keyboard
    
    % Remove trials in which the test was not enabled. Typically, this means that that
    % trial was initial, long adaptation trial which has a dummy test-stimulus.
    DPXD=dpxdSubset(DPXD,DPXD.test_enabled);
    % See how many sessions went into this dataset, could be merged data.
    % If so, plot the individual session curves as well as the merged curve
    % (merged on top and clearer line and markers)
    tc{1}=getCurve(DPXD,cellNr,varargin{:}); % 1 is always all data
    thisIsMergeData=numel(unique(DPXD.exp_startTime))>1;
    if thisIsMergeData
        D=dpxdSplit(DPXD,'exp_startTime');
        for i=1:numel(D)
            tc{end+1}=getCurve(D{i},cellNr,varargin{:}); %#ok<AGROW>
        end
    end
end

function tc=getCurve(DPXD,cellNr,varargin)
    % Parse 'options' input
    p=inputParser;
    p.addParamValue('bayesfit',false,@islogical); % *
    % * If true: use the bayesPhysV1 toolkit to fit tuningcurves to the data, and
    % test which is the best model. This will determine if the cell is
    % tuned at all, and if so, if it is direction or orientation selective.
    p.parse(varargin{:});
    %
    % Split the data by motion type, make a tuning curve per motion type (e.g. 'phi' or
    % 'ihp'). These will get different levels in the tc output struct (e.g. tc.dirDeg{1}
    % is for the first motion type, tc.dirDeg{2} for the second, etc.)
    % 2015-10-09: There might not be a motType, e.g. if this is a grating
    % class stimulus. Add a motType field, assume it's GRATING
    if ~isfield(DPXD,'test_motType')
        DPXD.test_motType=repmat({'grating'},1,DPXD.N); % changed from 'phi' 2016-07-01
    end
    % 
    % Transparent dot motion was defined by giving an offset for the second field in the
    % imaginary part of the 'test_dirDeg' field. Convert that here to specific motion
    % types, so that they get split with the same mechanism I used for separating PHI and
    % IHP motion
    if ~isreal(DPXD.test_dirDeg)
        for i=1:DPXD.N
            DPXD.test_motType{i}=[DPXD.test_motType{i} num2str(round(imag(DPXD.test_dirDeg(i))),'%.3d')];
        end
        % Throw away the imaginary part of the directions
        DPXD.test_dirDeg=real(DPXD.test_dirDeg);
    end
    % 
    % Perform the analysis separately per motion type
    MT=dpxdSplit(DPXD,'test_motType');
    for mti=1:numel(MT)
        % Split the data according to the direction of the grating.
        % Ds is the DPXD called 'dpxd' split up in a DPXD per direction (so
        % numel Ds would typically be 8). Ns is an array corrsponding to Ds
        % that contains the N of each DPXD in Ds
        [Ds,Ns]=dpxdSplit(MT{mti},'test_dirDeg');
        % Preallocate the list of directions ...
        dirDeg=NaN(1,numel(Ds));
        % Preallocate the table of responses
        dfof=NaN(max(Ns),numel(Ds)); % rows=trials, cols=directions
        % Construct the response and time fieldnames of this cellNr
        dfofField=['resp_unit' num2str(cellNr,'%.3d') '_dFoF']; % e.g., if cellNr is 1, 'resp_unit001_dFoF'
        timeField=['resp_unit' num2str(cellNr,'%.3d') '_s']; % e.g., if cellNr is 1, 'resp_unit001_s'
        for i=1:numel(Ds) % loop over all directions
            dirDeg(i)=Ds{i}.test_dirDeg(1); % store this direction in degrees
            for t=1:Ds{i}.N
                % Get the dFoF trace of the entire t'th trial for this direction
                tSeries=Ds{i}.(dfofField){t};
                % Get the corresponding time axis
                tAxis=Ds{i}.(timeField){t};
                % Find the interval stimTime where the motion was on
                if strcmpi(Ds{i}.test_className{1},'dpxStimGrating') 
                    from=Ds{i}.test_onSec(t);
                    to=from+Ds{i}.test_durSec(t);
                else
                    from=Ds{i}.test_motStartSec(t);
                    to=from+Ds{i}.test_motDurSec(t);
                end
                % alternatively, use the following to take until end of
                % trial (GCaMP is slow so might be more signal used)
                % to=Inf;
                stimTime=tAxis>=from & tAxis<to;
                % Get the interval before the stim was on to determine the
                % baseline activity
                if strcmpi(Ds{i}.test_className{1},'dpxStimGrating')
                    from=0;
                    to=Ds{i}.test_onSec(t);
                else
                    from=Ds{i}.test_onSec(t);
                    to=Ds{i}.test_motStartSec(t);
                end
                baseTime=tAxis>=from & tAxis<to;
                % Store the mean of this segment minus the baseline response
                dfof(t,i)=nanmean(tSeries(stimTime))-nanmean(tSeries(baseTime));
            end
        end
        % put the values in the output struct
        tc.motType{mti}=MT{mti}.test_motType{1}; % string indicating the motion type (e.g. 'phi')
        tc.dirDeg{mti}=dirDeg; % vector of say 12 directions
        tc.allDFoF{mti}=dfof; % matrix of 12 columns x nRepeats. padded with NaNs when a direction was repeated less often
        tc.meanDFoF{mti}=nanmean(dfof,1); % calculate the mean of the columns, ingore nan's
        tc.sdDFoF{mti}=nanstd(dfof,1); % calculate the standard deviation of the columns, ingore nan's.
        tc.nDFoF{mti}=sum(~isnan(dfof),1); % calculate the Number of non-nan values (=number of trials per direction)
        tc.N=mti;
        if p.Results.bayesfit
            dirDeg=repmat(dirDeg,size(dfof,1),1); % make a direction for each dfof value
            dirDeg=dirDeg(~isnan(dfof(:))); % remove dirs for NaN-dfof values (remove padding)
            dfof=dfof(~isnan(dfof(:))); % remove dfof for NaN-dfof values (remove padding)
            curvesToTest={'constant','circular_gaussian_180','circular_gaussian_360','direction_selective_circular_gaussian'};
            B=dpxBayesPhysV1('deg',dirDeg,'resp',dfof,'curvenames',curvesToTest,'unit','dfof');
            tc.dpxBayesPhysV1{mti}=B.winnerstr;
            tc.dpxBayesPhysV1x{mti}=B.bestCurveX{1};
            tc.dpxBayesPhysV1y{mti}=B.bestCurveY{1};
        end
    end
    if ~dpxdIs(tc)
        error('tc should be a DPXD-struct');
    end
end
