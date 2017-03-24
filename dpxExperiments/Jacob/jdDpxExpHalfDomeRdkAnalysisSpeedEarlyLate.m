function jdDpxExpHalfDomeRdkAnalysisSpeedEarlyLate
    
    % see also: jdDpxExpHalfDomeRdkAnalysisSpeed
    % jacob 20170322
    % http://youtu.be/gBXC1Ookse8
    
    files=dpxUIgetFiles;
    disp([num2str(numel(files)) ' datafiles selected.']);
    if isempty(files)
        return;
    end
    
    
    jdDpxExpHalfDomeRdkAnalysisSpeed(files,'withinEarly');
    jdDpxExpHalfDomeRdkAnalysisSpeed(files,'withinLate');
    jdDpxExpHalfDomeRdkAnalysisSpeed(files,'betweenEarly');
    jdDpxExpHalfDomeRdkAnalysisSpeed(files,'betweenLate');

    cpsTileFigs
    
    
end
    