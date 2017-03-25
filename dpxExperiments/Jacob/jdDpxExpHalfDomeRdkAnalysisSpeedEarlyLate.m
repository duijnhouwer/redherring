function jdDpxExpHalfDomeRdkAnalysisSpeedEarlyLate
    
    % see also: jdDpxExpHalfDomeRdkAnalysisSpeed
    % jacob 20170322
    % http://youtu.be/gBXC1Ookse8
    
    files=dpxUIgetFiles;
    disp([num2str(numel(files)) ' datafiles selected.']);
    if isempty(files)
        return;
    end
    
    
    out.withinEarly=jdDpxExpHalfDomeRdkAnalysisSpeed(files,'withinEarly');
    out.withinLate=jdDpxExpHalfDomeRdkAnalysisSpeed(files,'withinLate');
    out.betweenEarly=jdDpxExpHalfDomeRdkAnalysisSpeed(files,'betweenEarly');
    out.betweenLate=jdDpxExpHalfDomeRdkAnalysisSpeed(files,'betweenLate');

    cpsTileFigs
    
    flds=fieldnames(out);
    for i=1:numel(flds)
        P{i}=prepForAnova(out.(flds{i}).A);
        P{i}.medSplit=repmat({flds{i}},1,P{i}.N); % add the type of median split for use as a factor
    end
    P=dpxdMerge(P);
    
    
    % Perform the ANOVAs
    factorNames={'medSplit','Speed','Mouse','Contrast'};
    dpxDispFancy('*ANOVA across all median split types*');
    [pVals,atab]=anovan(P.yawIntegral,{P.medSplit P.speed P.mus P.contrast }...
        ,'model',1,'varnames',factorNames...
        ,'Display','off');
    disp(atab)
    if pVals(1)<0.05
        disp(['---> there is a main effect of median-split (p=' num2str(pVals(1)) ')']);
    else
        disp(['---> there is NO main effect of median-split (p=' num2str(pVals(1)) ')']);
    end
    %
    % now do the anova separately for betweenEarly vs betweenLate and for
    % withinEarly vs withinLate
    [B,W]=dpxdSubset(P,strcmpi(P.medSplit,'betweenEarly') | strcmpi(P.medSplit,'betweenLate'));
    dpxDispFancy('*ANOVA across median split types betweenEarly-vs-betweenLate*');
    [pVals,atab]=anovan(B.yawIntegral,{B.medSplit B.speed B.mus B.contrast }...
        ,'model',1,'varnames',factorNames...
        ,'Display','off');
    disp(atab)
    if pVals(1)<0.05
        disp(['---> there is a main effect of median-split betweenEarly-vs-betweenLate (p=' num2str(pVals(1)) ')']);
    else
        disp(['---> there is NO main effect of median-split betweenEarly-vs-betweenLate (p=' num2str(pVals(1)) ')']);
    end
    %
    dpxDispFancy('*ANOVA across median split types withinEarly-vs-withinLate*');
    [pVals,atab]=anovan(W.yawIntegral,{W.medSplit W.speed W.mus W.contrast }...
        ,'model',1,'varnames',factorNames...
        ,'Display','off');
    disp(atab)
    if pVals(1)<0.05
         disp(['---> there is a main effect of median-split withinEarly-vs-withinLate (p=' num2str(pVals(1)) ')']);
    else
        disp(['---> there is NO main effect of median-split withinEarly-vs-withinLate (p=' num2str(pVals(1)) ')']);
    end
    cpsTileFigs
    keyboard
end
    

function A=prepForAnova(A)
    % remove unnecessary fields
    A=rmfield(A,{'yawRaw','yawSEM','yawN','yawMean'});
	% remove the mean mouse
    A=dpxdSubset(A,~strcmpi(A.mus,'MEAN'));
    % remove the pooled contrasts
    A=dpxdSubset(A,A.contrast~=-1);
    % get raw-yaw integrals over 1 and 2 seconds since stim-on
    for i=1:A.N
        A.yawIntegral{i}=nan(size(A.yaw{i}));
        for tr=1:numel(A.yaw{i})
            idx=A.time{i}>=1.0 & A.time{i}<2.0;
            A.yawIntegral{i}(tr)=mean(A.yaw{i}{tr}(idx));
        end
    end
    A=rmfield(A,{'yaw','time'});
    A=dpxdUnfold(A,'yawIntegral');
end