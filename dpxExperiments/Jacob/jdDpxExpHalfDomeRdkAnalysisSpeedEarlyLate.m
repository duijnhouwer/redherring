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
        P{i}=out.(flds{i}).A;
        P{i}.medSplit=repmat(flds(i),1,P{i}.N); % add the type of median split for use as a factor
    end
    P=dpxdMerge(P);
    
    
    cpsFindFig('Yaw vs Speed plot per Median Split');
    clf;
    hold on;
    for fi=1:numel(flds)
        if ~isempty(strfind(lower(flds{fi}),'between')), col='r'; else col='b'; end
        if ~isempty(strfind(lower(flds{fi}),'early')), lstl='-'; else lstl='--'; end
        K=dpxdSubset(P,strcmpi(P.medSplit,flds{fi}));
        uSpeed=unique(K.speed);
        for i=1:numel(uSpeed)
            v(i)=uSpeed(i);
            y(i)=mean(K.yawIntegral(K.speed==uSpeed(i)));
            ySem(i)=std(K.yawIntegral(K.speed==uSpeed(i)))./sqrt(sum(K.speed==uSpeed(i)));
        end
        lineHandles(fi) = errorbar(v,y,ySem,lstl,'Color',col,'LineWidth',2,'Marker','o','MarkerSize',10,'MarkerEdgeColor','none','MarkerFaceColor',col);
    end
    xlabel('speed');
    ylabel('yawIntegral');
    legend(lineHandles,flds,'Location','NorthWest');
    cpsRefLine('-','k--');
    
    % Perform the ANOVAs
    factorNames={'medSplit','Speed','Mouse','Contrast'};
    dpxDispFancy('*ANOVA across all median split types*');
    [pVals,atab]=anovan(P.yawIntegral,{P.medSplit P.speed P.mus P.contrast }...
        ,'model',1,'varnames',factorNames...
        ,'Display','off');
    disp(atab)
    if pVals(1)<0.05
        disp(['---> There is a main effect of median-split (p=' num2str(pVals(1)) ')']);
    else
        disp(['---> There is NO main effect of median-split (p=' num2str(pVals(1)) ')']);
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
        disp(['---> There is a main effect of median-split betweenEarly-vs-betweenLate (p=' num2str(pVals(1)) ')']);
    else
        disp(['---> There is NO main effect of median-split betweenEarly-vs-betweenLate (p=' num2str(pVals(1)) ')']);
    end
    %
    dpxDispFancy('*ANOVA across median split types withinEarly-vs-withinLate*');
    [pVals,atab]=anovan(W.yawIntegral,{W.medSplit W.speed W.mus W.contrast }...
        ,'model',1,'varnames',factorNames...
        ,'Display','off');
    disp(atab)
    if pVals(1)<0.05
         disp(['---> There is a main effect of median-split withinEarly-vs-withinLate (p=' num2str(pVals(1)) ')']);
    else
        disp(['---> There is NO main effect of median-split withinEarly-vs-withinLate (p=' num2str(pVals(1)) ')']);
    end
    cpsTileFigs
end
    

