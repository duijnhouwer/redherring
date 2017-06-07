function jdDpxExpHalfDomeRdkAnalysisSpeedRm
    
    % wrapper around jdDpxExpHalfDomeRdkAnalysisSpeed for repeated measure
    % anova analysis
    
    files=dpxUIgetFiles;
    disp([num2str(numel(files)) ' datafiles selected.']);
    if isempty(files)
        return;
    end
    
    curves={};
    for i=1:numel(files)
        out=jdDpxExpHalfDomeRdkAnalysisSpeed(files(i)); % note parentheis, takes cell as argument
        if ~isfield(out,'curves')
            disp(['skipping file ' num2str(i) ': ' files{i}]) 
            continue;
        end
        curves{end+1}=out.curves;
        % add the start time of the recording (as datenum)
        D=dpxdLoad(files{i});        
        curves{end}.datenum=repmat(D.exp_startTime(1),1,curves{end}.N);
    end
    
    keyboard
    
         