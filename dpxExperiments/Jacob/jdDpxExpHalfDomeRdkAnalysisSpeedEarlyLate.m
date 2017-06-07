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
        P{i}=out.(flds{i}).curves;
        P{i}.medSplit=repmat(flds(i),1,P{i}.N); % add the type of median split for use as a factor
    end
    P=dpxdMerge(P);
    
    
    % Plot
    cpsFindFig('Yaw vs Speed plot per Median Split');
    clf;
    hold on;
    for fi=1:numel(flds)
        if strcmpi(flds{fi},'withinEarly')
            col='r'; lstl='-'; mrk='<';
        elseif strcmpi(flds{fi},'withinLate')
            col='r'; lstl='--'; mrk='>';
        elseif strcmpi(flds{fi},'betweenEarly')
            col='b'; lstl='-'; mrk='^';
        elseif strcmpi(flds{fi},'betweenLate')
            col='b'; lstl='--'; mrk='v';
        end
        K=dpxdSubset(P,strcmpi(P.medSplit,flds{fi}));
        uSpeed=unique(K.speeds);
        for i=1:numel(uSpeed)
            v(i)=uSpeed(i);
            y(i)=mean(K.yaw(K.speeds==uSpeed(i)));
            ySem(i)=std(K.yaw(K.speeds==uSpeed(i)))./sqrt(sum(K.speeds==uSpeed(i)));
        end
        lineHandles(fi) = errorbar(v,y,ySem,lstl,'Color',col,'LineWidth',2,'Marker',mrk,'MarkerSize',10,'MarkerEdgeColor','none','MarkerFaceColor',col);
    end
    xlabel('Speed (deg/s)','FontSize',14);
    ylabel('Yaw','FontSize',14);
    legend(lineHandles,flds,'Location','NorthWest');
    cpsRefLine('-','k--');
    
    % Perform the ANOVAs
      % remove the MEAN mouse first
    P=dpxdSubset(P,~strcmpi(P.mouse,'MEAN')); % 20170605
    regularOldStyleAnova(P)
    repeatedMeasuresAnova(P)
    cpsTileFigs
end


function  regularOldStyleAnova(P)
     factorNames={'medSplit','Speed','Mouse','Contrast'};
    dpxDispFancy('*ANOVA across all median split types*');
    [pVals,atab]=anovan(P.yaw,{P.medSplit P.speeds P.mouse P.contrast }...
        ,'random',3 ... % makes mouse a random variable which should make this behave like a repeated measures anova, http://compneurosci.com/wiki/images/a/a1/Repeated_ANOVA_MATLAB.pdf
        ,'model','full' ...
        ,'varnames',factorNames...
        ,'Display','off');
    disp(atab)
    if pVals(1)<0.05
        disp(['---> There is a main effect of median-split (p = ' num2str(pVals(1)) ')']);
    else
        disp(['---> There is NO main effect of median-split (p = ' num2str(pVals(1)) ')']);
    end
    %
    % now do the anova separately for betweenEarly vs betweenLate and for
    % withinEarly vs withinLate
    [B,W]=dpxdSubset(P,strcmpi(P.medSplit,'betweenEarly') | strcmpi(P.medSplit,'betweenLate'));
    dpxDispFancy('*ANOVA across median split types betweenEarly-vs-betweenLate*');
    [pVals,atab]=anovan(B.yaw,{B.medSplit B.speeds B.mouse B.contrast }...
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
    [pVals,atab]=anovan(W.yaw,{W.medSplit W.speeds W.mouse W.contrast }...
        ,'model',1,'varnames',factorNames...
        ,'Display','off');
    disp(atab)
    if pVals(1)<0.05
        disp(['---> There is a main effect of median-split withinEarly-vs-withinLate (p=' num2str(pVals(1)) ')']);
    else
        disp(['---> There is NO main effect of median-split withinEarly-vs-withinLate (p=' num2str(pVals(1)) ')']);
    end
end

function  repeatedMeasuresAnova(P)
    
    % convert P into a table
    % 1 remove the DPXD-N field
    P=rmfield(P,'N');
    % get variables and data
    vars=fieldnames(P);
    data=struct2cell(P);
    % 2 flip the orientation of all vector
    data=cellfun(@transpose,data,'UniformOutput',false);
    T=struct2table(cell2struct(data,vars));
    
    factorNames={'medSplit','Speed','Mouse','Contrast'};
    dpxDispFancy('*ANOVA across all median split types*');
    [pVals,atab]=anovan(P.yaw,{P.medSplit P.speeds P.mouse P.contrast }...
        ,'random',3 ... % makes mouse a random variable which should make this behave like a repeated measures anova, http://compneurosci.com/wiki/images/a/a1/Repeated_ANOVA_MATLAB.pdf
        ,'model','full' ...
        ,'varnames',factorNames...
        ,'Display','off');
    disp(atab)
    if pVals(1)<0.05
        disp(['---> There is a main effect of median-split (p = ' num2str(pVals(1)) ')']);
    else
        disp(['---> There is NO main effect of median-split (p = ' num2str(pVals(1)) ')']);
    end
    %
    % now do the anova separately for betweenEarly vs betweenLate and for
    % withinEarly vs withinLate
    [B,W]=dpxdSubset(P,strcmpi(P.medSplit,'betweenEarly') | strcmpi(P.medSplit,'betweenLate'));
    dpxDispFancy('*ANOVA across median split types betweenEarly-vs-betweenLate*');
    [pVals,atab]=anovan(B.yaw,{B.medSplit B.speeds B.mouse B.contrast }...
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
    [pVals,atab]=anovan(W.yaw,{W.medSplit W.speeds W.mouse W.contrast }...
        ,'model',1,'varnames',factorNames...
        ,'Display','off');
    disp(atab)
    if pVals(1)<0.05
        disp(['---> There is a main effect of median-split withinEarly-vs-withinLate (p=' num2str(pVals(1)) ')']);
    else
        disp(['---> There is NO main effect of median-split withinEarly-vs-withinLate (p=' num2str(pVals(1)) ')']);
    end
end