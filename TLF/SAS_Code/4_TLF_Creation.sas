/* Output 4 */;
options validvarname=upcase
        nodate
        nonumber
        orientation=landscape
        missing=" ";

ods escapechar="^";

%let INPATH  = /home/u64124548/sasuser.v94/TLF - Creation/Input;
%let OUTPATH = /home/u64124548/sasuser.v94/TLF - Creation/Output;


proc printto
    log="&OUTPATH./Output_4.log"
    new;
run;


libname xlb xport "&INPATH./ADLBSI.xpt";

proc copy
    in=xlb
    out=work
    memtype=data;
run;

libname xlb clear;


proc contents data=work.adlbsi varnum;
run;


data lb_source;
    set work.adlbsi;

    where upcase(strip(saffl))="Y"
      and upcase(strip(anl01fl))="Y"
      and not missing(aval);

    length treatment $20;

    if upcase(strip(trt01a))="CMP-135" then do;
        trtn=1;
        treatment="CMP-135";
    end;

    else if upcase(strip(trt01a))="PLACEBO" then do;
        trtn=2;
        treatment="Placebo";
    end;

    else delete;


    if upcase(strip(ontrtfl)) ne "Y" then delete;

    if not missing(adt) and
       not missing(trtsdt) and
       adt<trtsdt then delete;
run;


proc sql;
    select count(*) as LB_SOURCE_RECORDS
    from lb_source;
quit;



proc sql;
    create table parameter_list as

    select distinct
           upcase(strip(paramcd)) as paramcd length=12,
           strip(param) as lab_parameter length=120

    from lb_source

    where not missing(paramcd)

    order by calculated lab_parameter;
quit;


data parameter_list;
    set parameter_list;
    parameter_order=_n_;
run;


data toxicity_direction_raw;
    set work.adlbsi;

    length event $1;

    if upcase(strip(btoxdir)) in ("L","H") then do;
        event=upcase(strip(btoxdir));
        output;
    end;

    if upcase(strip(atoxdir)) in ("L","H") then do;
        event=upcase(strip(atoxdir));
        output;
    end;

    keep paramcd event;
run;


proc sort data=toxicity_direction_raw
          out=toxicity_directions
          nodupkey;

    by paramcd event;
run;


proc sql;
    create table event_control as

    select p.parameter_order,
           p.paramcd,
           p.lab_parameter,
           d.event,

           case
               when d.event="L" then 1
               when d.event="H" then 2
               else 9
           end as event_order

    from parameter_list as p

    inner join toxicity_directions as d

      on upcase(strip(p.paramcd))=
         upcase(strip(d.paramcd))

    where d.event in ("L","H")

    order by p.parameter_order,
             calculated event_order;
quit;


proc print data=event_control noobs;
    title "Diagnostic: Parameters and Toxicity Directions";
run;

title;


proc sql;
    create table lb_directional as

    select a.*,
           c.parameter_order,
           c.lab_parameter,
           c.event,
           c.event_order

    from lb_source as a

    inner join event_control as c

      on upcase(strip(a.paramcd))=
         upcase(strip(c.paramcd))

    order by a.trtn,
             a.usubjid,
             c.parameter_order,
             c.event_order,
             a.adt;
quit;



data lb_grades;
    set lb_directional;

    length baseline_direction
           analysis_direction $1;

    baseline_direction=upcase(strip(btoxdir));
    analysis_direction=upcase(strip(atoxdir));


    baseline_grade_value=input(strip(vvalue(btoxgr)),best.);
    analysis_grade_value=input(strip(vvalue(atoxgr)),best.);


    anrhi_numeric=input(strip(vvalue(anrhi)),best.);


    if baseline_direction=event and
       not missing(baseline_grade_value) then

        baseline_grade=baseline_grade_value;

    else baseline_grade=0;



    if analysis_direction=event and
       not missing(analysis_grade_value) then

        post_grade=analysis_grade_value;



    else if event="H" and
            not missing(anrhi_numeric) and
            aval>anrhi_numeric then

        post_grade=9;


    else post_grade=0;


    if baseline_grade not in (0,1,2,3,4) then
        baseline_grade=0;

    if post_grade not in (0,1,2,3,4,9) then
        post_grade=0;



    if post_grade=9 then severity_rank=0.5;
    else severity_rank=post_grade;
run;


proc sort data=lb_grades
          out=lb_worst_sort;

    by trtn
       usubjid
       parameter_order
       event_order
       descending severity_rank
       descending adt;
run;


data lb_worst;
    set lb_worst_sort;

    by trtn
       usubjid
       parameter_order
       event_order
       descending severity_rank
       descending adt;

    if first.event_order;
run;


proc sort data=lb_worst nodupkey;

    by trtn
       usubjid
       parameter_order
       event_order;
run;


data lb_worst_report;
    set lb_worst;

    length baseline_label $10;

    if event="H" and baseline_grade in (1,2,3,4) then do;
        baseline_group=14;
        baseline_label="1-4";
        baseline_order=1;
    end;

    else do;
        baseline_group=baseline_grade;
        baseline_label=strip(put(baseline_grade,1.));

        baseline_order=5-baseline_grade;
    end;
run;


proc sql;
    create table lb_denominator as

    select trtn,
           treatment,
           parameter_order,
           event_order,
           paramcd,
           lab_parameter,
           event,
           baseline_group,
           baseline_label,
           baseline_order,

           count(distinct usubjid) as denominator

    from lb_worst_report

    group by trtn,
             treatment,
             parameter_order,
             event_order,
             paramcd,
             lab_parameter,
             event,
             baseline_group,
             baseline_label,
             baseline_order

    order by trtn,
             parameter_order,
             event_order,
             baseline_order;
quit;


proc sql;
    create table lb_counts as

    select trtn,
           parameter_order,
           event_order,
           baseline_group,
           post_grade,

           count(distinct usubjid) as count

    from lb_worst_report

    group by trtn,
             parameter_order,
             event_order,
             baseline_group,
             post_grade;
quit;



data post_grade_shell;

    post_grade=0;
    output;

    post_grade=1;
    output;

    post_grade=2;
    output;

    post_grade=3;
    output;

    post_grade=4;
    output;

    post_grade=9;
    output;
run;


proc sql;
    create table lb_shell as

    select d.*,
           s.post_grade

    from lb_denominator as d

    cross join post_grade_shell as s

    order by d.trtn,
             d.parameter_order,
             d.event_order,
             d.baseline_order,
             s.post_grade;
quit;


proc sql;
    create table lb_complete as

    select s.*,
           coalesce(c.count,0) as count

    from lb_shell as s

    left join lb_counts as c

      on  s.trtn=c.trtn
      and s.parameter_order=c.parameter_order
      and s.event_order=c.event_order
      and s.baseline_group=c.baseline_group
      and s.post_grade=c.post_grade

    order by s.trtn,
             s.parameter_order,
             s.event_order,
             s.baseline_order,
             s.post_grade;
quit;


data lb_formatted;
    set lb_complete;

    length value $30;

    if denominator>0 then
        value=cats(
            strip(put(count,3.)),
            " (",
            strip(put(100*count/denominator,5.1)),
            "%)"
        );

    else value="0 (0.0%)";
run;


proc sort data=lb_formatted;

    by trtn
       treatment
       parameter_order
       event_order
       paramcd
       lab_parameter
       event
       baseline_order
       baseline_group
       baseline_label
       denominator
       post_grade;
run;


proc transpose
    data=lb_formatted
    out=lb_wide(drop=_name_)
    prefix=g;

    by trtn
       treatment
       parameter_order
       event_order
       paramcd
       lab_parameter
       event
       baseline_order
       baseline_group
       baseline_label
       denominator;

    id post_grade;
    var value;
run;


proc sort data=lb_wide;

    by trtn
       parameter_order
       event_order
       baseline_order;
run;


data final_lab;
    set lb_wide;

    by trtn
       parameter_order
       event_order
       baseline_order;

    length display_parameter $120
           display_event     $20
           display_baseline  $10;


    if first.parameter_order then
        display_parameter=lab_parameter;

    else display_parameter="";


    if first.event_order then do;

        if event="L" then
            display_event="Low";

        else if event="H" then
            display_event="High";

    end;

    else display_event="";


    display_baseline=baseline_label;


    if missing(g0) then g0="0 (0.0%)";
    if missing(g1) then g1="0 (0.0%)";
    if missing(g2) then g2="0 (0.0%)";
    if missing(g3) then g3="0 (0.0%)";
    if missing(g4) then g4="0 (0.0%)";
    if missing(g9) then g9="0 (0.0%)";
run;


data final_cmp
     final_placebo;

    set final_lab;

    if trtn=1 then output final_cmp;
    else if trtn=2 then output final_placebo;
run;


proc sql;

    select count(*) as FINAL_CMP_RECORDS
    from final_cmp;

    select count(*) as FINAL_PLACEBO_RECORDS
    from final_placebo;

quit;


proc print data=final_lab(obs=100) noobs;

    var treatment
        display_parameter
        display_event
        display_baseline
        denominator
        g0
        g1
        g2
        g3
        g4
        g9;

    title "Diagnostic: Final Laboratory Shift Dataset";
run;

title;


ods listing close;

ods rtf
    file="&OUTPATH./Output_4.rtf"
    style=journal
    bodytitle;


title1 j=c height=9pt
    "Table 14.3/10";

title2 j=c height=9pt
    "Change in Laboratory Events: Shift in NCI-CTC Grade from Baseline";

title3 j=c height=9pt
    "to Worst Post-Baseline Level";

title4 j=c height=9pt
    "Safety Evaluable Patients";



%macro lab_report(data=, treatment=);


ods rtf text=
"^S={
    font_face='Arial'
    font_size=8pt
    font_weight=bold
    just=left
}
Treatment: &treatment";


proc report
    data=&data
    nowd
    missing
    split="|"

    style(report)=[
        frame=hsides
        rules=groups
        cellpadding=1
        cellspacing=0
        font_face="Arial"
        font_size=7pt
    ]

    style(header)=[
        font_face="Arial"
        font_size=7pt
        font_weight=normal
    ]

    style(column)=[
        font_face="Arial"
        font_size=7pt
    ];


    columns parameter_order
            event_order
            baseline_order
            display_parameter
            display_event
            display_baseline
            denominator

            (
                "Post-Baseline NCI CTCAE Grade"

                g0
                g1
                g2
                g3
                g4
                g9
            );


    define parameter_order /
        order
        noprint;


    define event_order /
        order
        noprint;


    define baseline_order /
        order
        noprint;


    define display_parameter /
        display
        "Lab Parameter"
        style(column)=[
            cellwidth=1.70in
            just=l
            asis=on
        ];


    define display_event /
        display
        "Lab Event"
        style(column)=[
            cellwidth=.65in
            just=c
        ];


    define display_baseline /
        display
        "Baseline Grade"
        style(column)=[
            cellwidth=.65in
            just=c
        ];


    define denominator /
        display
        "N"
        style(column)=[
            cellwidth=.40in
            just=c
        ];


    define g0 /
        display
        "0"
        style(column)=[
            cellwidth=.85in
            just=c
        ];


    define g1 /
        display
        "1"
        style(column)=[
            cellwidth=.85in
            just=c
        ];


    define g2 /
        display
        "2"
        style(column)=[
            cellwidth=.85in
            just=c
        ];


    define g3 /
        display
        "3"
        style(column)=[
            cellwidth=.85in
            just=c
        ];


    define g4 /
        display
        "4"
        style(column)=[
            cellwidth=.85in
            just=c
        ];


    define g9 /
        display
        "Other|(value > ULN)"
        style(column)=[
            cellwidth=1.15in
            just=c
        ];

run;


ods rtf text="^S={font_size=5pt} ";


%mend lab_report;


%lab_report(
    data=final_cmp,
    treatment=CMP-135
);


%lab_report(
    data=final_placebo,
    treatment=Placebo
);


/* ods rtf text= */
/* "^S={ */
/*     font_face='Arial' */
/*     font_size=7pt */
/*     just=left */
/* } */
/* N = Number of subjects with a baseline and at least one post-baseline value."; */
/*  */
/*  */
/* ods rtf text= */
/* "^S={ */
/*     font_face='Arial' */
/*     font_size=7pt */
/*     just=left */
/* } */
/* Baseline is the last observation prior to the initiation of study medication."; */
/*  */
/*  */
/* ods rtf text= */
/* "^S={ */
/*     font_face='Arial' */
/*     font_size=7pt */
/*     just=left */
/* } */
/* All post-baseline laboratory values were used when determining the highest NCI CTCAE grade laboratory event, including repeats and unscheduled visits."; */
/*  */
/*  */
/* ods rtf text= */
/* "^S={ */
/*     font_face='Arial' */
/*     font_size=7pt */
/*     just=left */
/* } */
/* Post-baseline population: Count only once for each patient at the highest NCI CTCAE Grade."; */
/*  */
/*  */
/* ods rtf text= */
/* "^S={ */
/*     font_face='Arial' */
/*     font_size=7pt */
/*     just=left */
/* } */
/* Percentages are based on the number of subjects in the N column."; */



ods rtf close;
ods listing;

title;
footnote;

proc printto;
run;