SDTM--AE Domain
I. AEGRPID--通常如果Shell中需要计算[nAE]，或者aCRF上注释了AEGRPID，需要添加；

第一种：[nAE]：AE发生的例次，计算为EDC数据库中AE的记录数，但是若同一条AE（AE首选术语相同且时间是连续的）因为严重级别发生改变记录成不同的AE记录，则计算成一个例次。
1.做法如下：
	1. 肿瘤试验通常会将AE按照CTCAE等级记录，故需要判断同一事件
		a. 开始日期为上一等级结束相等或+1天的日期，结束日期为等级变化日期
		b. 开始日期为等级变化日期，结束日期为整个事件结束日期
	2. 对于首尾时间间隔<=1天且前一个AE的转归（AEOUT)不为 '恢复' 和'恢复有后遗症'的相同AETERM, AEGRPID保持不变
	3. 同一个AEGRPID中如果吃药后CTCAE增加，后者将标记为TEAE

2.spec描述：
    每个受试者按照AEDECOD, AETERM, AESTDTC, AEENDTC, AESPID排序，AEGRPID以"001"开始依次递增。若判断为同一个AE，AEGRPID维持不变，判断逻辑如下：
    若同个受试者同个AETERM中，上一条AE的AEENDTC与当前AE的AESTDTC相同或在当前AE的AESTDTC前一天，且上一条AE的AEOUT不为"痊愈（无后遗症）"或"痊愈伴后遗症"，则这两条AE被认为是同一条AE的进展，标记相同的AEGRPID
3.SAS编程：

    proc sort data=ae;
        by USUBJID AEDECOD AETERM AESTDTC AEENDTC AESPID;
    run;

    * 2. 衍生AEGRPID;
    data ae_derived;
        set ae;
        by USUBJID AEDECOD AETERM;
        
        * 保留上一观测的变量;
        retain last_aeendtc last_aeout group_id;
        
        * 初始化;
        if first.USUBJID then do;
            group_id = 1;
            last_aeendtc = "";
            last_aeout = "";
        end;
        
        * 判断是否为同一AE进展;
        if not first.AETERM then do;
            * 计算日期差;
            diff_days = input(AESTDTC, yymmdd10.) - input(last_aeendtc, yymmdd10.);
            
            * 判断是否为连续AE;
            if (diff_days = 0 or diff_days = 1) 
            and last_aeout not in ("痊愈（无后遗症）", "痊愈伴后遗症") then do;
                * 同一AE，维持group_id不变;
            end;
            else do;
                * 新的AE，group_id递增;
                group_id + 1;
            end;
        end;
        else do;
            * 新AETERM的第一条记录，重置group_id递增;
            if not first.USUBJID then group_id + 1;
            * 如果是受试者的第一条记录，group_id已经是1;
        end;
        
        * 生成AEGRPID;
        AEGRPID = put(group_id, z3.);
        
        * 更新保留变量供下一条记录使用;
        last_aeendtc = AEENDTC;
        last_aeout = AEOUT;
        
        * 删除临时变量;
        drop last_aeendtc last_aeout group_id diff_days;
    run;
第二种：[NAE]：AE发生的例次数，计算为数据中合并后AE的记录数；合并规则：在计算例次数时，整个试验周期中AE名称相同且严重程度等级未发生变化，将这些AE进行合并，例次数记为1；若整个试验周期中AE名称相同，在病程中出现严重程度等级变化（如从1级变为2级），则需单独计例次数，即在严重程度改变前后需要各记录1次（如从1级变为2级则对应的例次数为2）。
1.spec描述：每个受试者按照AEDECOD, AETERM, AESTDTC, AEENDTC, AESPID排序，AEGRPID以"001"开始依次递增。若判断为同一个AE，AEGRPID维持不变。同一个AEGRPID的判断逻辑如下：
    对于同一受试者同一AEDECOD同一AETERM，若上一条的AETOXG与当前的AETOXGR相同，则这两条AE被认为是同一条AE，标记相同的AEGRPID。
2.SAS编程：
    proc sort data=ae03 out=ae_lag;
        by usubjid aedecod aeterm aestdtc aeendtc aespid;
    run;

data ae04;
    length lag_sub lag_pt lag_term lag_tox aegrpid $200;
    set ae_lag;
    by usubjid aedecod aeterm aestdtc aeendtc aespid;
    retain grpid 0 ;
    if first.usubjid then grpid=1;
    else if first.aeterm then  grpid+1;
    
    lag_sub=lag(usubjid);
    lag_pt=lag(aedecod);
    lag_term=lag(aeterm);
    lag_tox=lag(aetoxgr); 
    lag_grpid=lag(grpid);

    if first.aeterm then call missing(lag_sub, lag_pt, lag_term, lag_tox, lag_grpid);
    if usubjid=strip(lag_sub) and aedecod=strip(lag_pt) and aeterm=strip(lag_term) then do;
        if aetoxgr ne lag_tox then grpid+1;
    end;
    aegrpid=put(grpid, z3.);
run;