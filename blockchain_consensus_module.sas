data consensus_module;
    length node_id $20 block_id $40 prev_hash $64 hash $64 status $10 decision $10 timestamp datetime64.;
    retain chain_length 0 validation_round 0 consensus_reached 0;
    array nodes[10] $20 _temporary_ ('NodeA' 'NodeB' 'NodeC' 'NodeD' 'NodeE' 'NodeF' 'NodeG' 'NodeH' 'NodeI' 'NodeJ');
    do i = 1 to 10;
        node_id = nodes[i];
        block_id = catx('-', node_id, put(ranuni(0)*1e6, 7.));
        prev_hash = '0000';
        hash = put(cats('ABC', ranuni(0)*1e6), $64.);
        status = 'Pending';
        decision = '';
        timestamp = '01JAN2024:00:00:00'dt + rand('uniform')*86400;
        output;
    end;
    do while (consensus_reached=0);
        validation_round + 1;
        do i=1 to 10;
            node_id = nodes[i];
            block_id = catx('-', node_id, put(ranuni(0)*1e6, 7.));
            prev_hash = hash;
            hash = put(cats('XYZ', ranuni(0)*1e6), $64.);
            status = 'Validating';
            decision = '';
            timestamp = '01JAN2024:00:00:00'dt + rand('uniform')*86400;
            output;
        end;
        proc sort data=consensus_module; by node_id; run;
        declare hash consensus_hash();
        consensus_hash = 0;
        do i=1 to 10;
            set consensus_module point=i;
            if status='Validating' then do;
                if prxmatch('/^[A-Fa-f0-9]{64}$/', hash) then do;
                    hash_valid=1;
                end; else hash_valid=0;
                if hash_valid=1 then decision='Accept'; else decision='Reject';
                put node_id= decision= hash=;
            end;
        end;
        score=0;
        do i=1 to 10;
            set consensus_module point=i;
            if decision='Accept' then score+1;
        end;
        if score>5 then do;
            consensus_reached=1;
            do i=1 to 10;
                set consensus_module point=i;
                status='Confirmed';
            end;
        end; else do;
            do i=1 to 10;
                set consensus_module point=i;
                status='Pending';
            end;
        end;
    end;
    chain_length+1;
    do i=1 to 10;
        set consensus_module point=i;
        if status='Confirmed' then do;
            decision='Committed';
        end; else decision='Rejected';
        timestamp = '01JAN2024:00:00:00'dt + rand('uniform')*86400;
        output;
    end;
    keep node_id block_id prev_hash hash status decision timestamp;
run;

proc sql;
    create table consensus_summary as
    select node_id, count(*) as total_blocks, sum(case when decision='Committed' then 1 else 0 end) as committed_blocks
    from consensus_module
    group by node_id;
quit;

data final_chain;
    set consensus_module;
    if status='Confirmed' then output;
run;

proc means data=final_chain noprint;
    output out=chain_stats mean=avg_blocks;
run;

data analyze;
    set chain_stats;
    chain_progress = 100 * avg_blocks / 10;
    if chain_progress >= 80 then consensus_quality='High';
    else if chain_progress >= 50 then consensus_quality='Medium';
    else consensus_quality='Low';
run;

proc sgplot data=final_chain;
    vbar node_id / response=decision stat=freq datalabel;
    title 'Consensus Decisions per Node';
run;

proc sgplot data=final_chain;
    hbar decision / stat=freq fillattrs=(color=blue);
    title 'Distribution of Block Decisions';
run;

data node_performance;
    set consensus_module;
    by node_id;
    if first.node_id then total_blocks=0;
    total_blocks+1;
    if decision='Committed' then committed_blocks+1;
    if last.node_id then output;
    keep node_id total_blocks committed_blocks;
run;

proc sort data=node_performance; by node_id; run;

data performance_metrics;
    set node_performance;
    commit_ratio=committed_blocks/total_blocks;
    if commit_ratio>=0.8 then performance='Excellent';
    else if commit_ratio>=0.5 then performance='Good';
    else performance='Needs Improvement';
run;

proc print data=performance_metrics noobs;
    var node_id commit_ratio performance;
    title 'Node Performance Metrics';
run;

data consensus_final;
    set final_chain;
    by node_id;
    if last.node_id then do;
        if decision='Committed' then consensus_status='Achieved';
        else consensus_status='Failed';
        output;
    end;
run;

proc sql;
    create table overall_status as
    select count(*) as total_nodes,
           sum(case when consensus_status='Achieved' then 1 else 0 end) as achieved_nodes
    from consensus_final;
quit;

data assessment;
    set overall_status;
    success_rate=achieved_nodes/total_nodes;
    if success_rate>=0.8 then overall='Strong Consensus';
    else if success_rate>=0.5 then overall='Moderate Consensus';
    else overall='Weak Consensus';
run;

proc sgplot data=overall_status;
    vbar overall / response=achieved_nodes stat=sum datalabel;
    title 'Overall Consensus Status';
run;

data reset;
    set consensus_module;
    if _N_=1 then call missing(of _all_);
    if _N_>1 then delete;
run;

proc datasets library=work nolist;
    delete consensus_module consensus_hash consensus_final node_performance chain_stats performance_metrics final_chain assessment overall_status;
run;