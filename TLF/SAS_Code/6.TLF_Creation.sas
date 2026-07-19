/* Output 6 */;
options validvarname=upcase
        nodate
        nonumber
        orientation=landscape
        missing=" ";

ods escapechar="^";

%let INPATH  = /home/u64124548/sasuser.v94/TLF - Creation/Input;
%let OUTPATH = /home/u64124548/sasuser.v94/TLF - Creation/Output;


proc printto
    log="&OUTPATH./Output_6.log"
    new;
run;


proc import
    datafile="&INPATH./ADRS.xls"
    out=work.adrs_raw
    dbms=xls
    replace;
    getnames=yes;
run;


proc contents data=work.adrs_raw varnum;
run;



data adrs_itt;
    set work.adrs_raw;

    where upcase(strip(ittfl))="Y"
      and upcase(strip(paramcd))="BOR";

    length age_category $10
           treatment    $20
           response     $8
           reason_clean $100;

    if compress(strip(agegr1)," ")="<65" then do;
        agecatn=1;
        age_category="< 65";
    end;

    else if compress(strip(agegr1)," ")=">=65" then do;
        agecatn=2;
        age_category=">= 65";
    end;

    else delete;


    if upcase(compress(strip(trt01a),"- "))="CMP123" then do;
        trtn=1;
        treatment="Trt A";
    end;

    else if upcase(strip(trt01a))="PLACEBO" then do;
        trtn=2;
        treatment="Trt B";
    end;

    else delete;


    response=upcase(strip(avalc));

    if response="NE" then response="UID";


    reason_clean=upcase(strip(nereasn));

    if response="UID" and missing(reason_clean) then
        reason_clean="REASON NOT AVAILABLE";


    if response in ("CR","PR") then orr=1;
    else orr=0;
run;


proc sort data=adrs_itt nodupkey;
    by usubjid;
run;


proc freq data=adrs_itt;
    tables agecatn*trtn*response / missing;
    tables response*reason_clean / missing;
    title "Diagnostic: ADRS Response Categories";
run;

title;


data adrs_all;
    set adrs_itt;

    output;

    trtn=3;
    treatment="Total";
    output;
run;


proc sql;
    create table denominators as

    select agecatn,
           trtn,
           count(distinct usubjid) as denom

    from adrs_all

    group by agecatn,
             trtn

    order by agecatn,
             trtn;
quit;


proc sql noprint;

    select denom into :n_lt65_a trimmed
    from denominators
    where agecatn=1 and trtn=1;

    select denom into :n_lt65_b trimmed
    from denominators
    where agecatn=1 and trtn=2;

    select denom into :n_lt65_t trimmed
    from denominators
    where agecatn=1 and trtn=3;


    select denom into :n_ge65_a trimmed
    from denominators
    where agecatn=2 and trtn=1;

    select denom into :n_ge65_b trimmed
    from denominators
    where agecatn=2 and trtn=2;

    select denom into :n_ge65_t trimmed
    from denominators
    where agecatn=2 and trtn=3;

quit;


%put NOTE: AGE <65: Trt A=&n_lt65_a Trt B=&n_lt65_b Total=&n_lt65_t;
%put NOTE: AGE >=65: Trt A=&n_ge65_a Trt B=&n_ge65_b Total=&n_ge65_t;


proc sql;
    create table response_counts as

    select agecatn,
           trtn,
           response,
           count(distinct usubjid) as count

    from adrs_all

    group by agecatn,
             trtn,
             response;
quit;



data response_frame;
    set denominators;

    length response $8
           display_label $100;

    row_order=0;
    response="";
    display_label="BEST OVERALL RESPONSE";
    output;

    row_order=1;
    response="CR";
    display_label="COMPLETE RESPONSE (CR)";
    output;

    row_order=2;
    response="PR";
    display_label="PARTIAL RESPONSE (PR)";
    output;

    row_order=3;
    response="SD";
    display_label="STABLE DISEASE (SD)";
    output;

    row_order=4;
    response="PD";
    display_label="PROGRESSIVE DISEASE (PD)";
    output;

    row_order=5;
    response="UID";
    display_label="UNABLE TO DETERMINE (UID)";
    output;
run;


proc sql;
    create table response_complete as

    select f.agecatn,
           f.trtn,
           f.denom,
           f.row_order,
           f.response,
           f.display_label,
           coalesce(c.count,0) as count

    from response_frame as f

    left join response_counts as c

      on  f.agecatn=c.agecatn
      and f.trtn=c.trtn
      and f.response=c.response

    order by f.agecatn,
             f.row_order,
             f.trtn;
quit;


data response_rows;
    set response_complete;

    length value $50;

    if row_order=0 then
        value="";

    else
        value=cats(
            strip(put(count,3.)),
            " (",
            strip(put(100*count/denom,5.1)),
            "%)"
        );

    keep agecatn
         trtn
         row_order
         display_label
         value;
run;


data reason_shell;
    length reason_clean $100
           display_label $100;

    reason_number=1;
    reason_clean="DEATH BEFORE MEASUREMENT";
    display_label="      DEATH BEFORE MEASUREMENT";
    output;

    reason_number=2;
    reason_clean="WITHDROWN CONSENT";
    display_label="      WITHDROWN CONSENT";
    output;

    reason_number=3;
    reason_clean="DROPED STUDY";
    display_label="      DROPED STUDY";
    output;
run;


proc sql;
    create table reason_counts as

    select agecatn,
           trtn,
           reason_clean,
           count(distinct usubjid) as count

    from adrs_all

    where response="UID"

    group by agecatn,
             trtn,
             reason_clean;
quit;


proc sql;
    create table reason_frame as

    select d.agecatn,
           d.trtn,
           d.denom,
           r.reason_number,
           r.reason_clean,
           r.display_label

    from denominators as d
         cross join reason_shell as r

    order by d.agecatn,
             r.reason_number,
             d.trtn;
quit;


proc sql;
    create table reason_complete as

    select f.agecatn,
           f.trtn,
           f.denom,
           f.reason_number,
           f.reason_clean,
           f.display_label,
           coalesce(c.count,0) as count

    from reason_frame as f

    left join reason_counts as c

      on  f.agecatn=c.agecatn
      and f.trtn=c.trtn
      and f.reason_clean=c.reason_clean

    order by f.agecatn,
             f.reason_number,
             f.trtn;
quit;


data reason_rows;
    set reason_complete;

    length value $50;

    row_order=5+(reason_number/100);

    value=cats(
        strip(put(count,3.)),
        " (",
        strip(put(100*count/denom,5.1)),
        "%)"
    );

    keep agecatn
         trtn
         row_order
         display_label
         value;
run;


proc sql;
    create table orr_summary as

    select agecatn,
           trtn,
           count(distinct usubjid) as denom,

           count(
               distinct case
                   when response in ("CR","PR")
                   then usubjid
               end
           ) as numerator

    from adrs_all

    group by agecatn,
             trtn

    order by agecatn,
             trtn;
quit;


data orr_input;
    set adrs_all;

    if response in ("CR","PR") then orr_flag=1;
    else orr_flag=0;
run;

proc sort data=orr_input;
    by agecatn trtn;
run;


ods exclude all;

proc freq data=orr_input;
    by agecatn trtn;

    tables orr_flag /
        binomial(
            p=0.5
            level="1"
        );

    exact binomial;
run;

ods exclude none;



data orr_final;
    set orr_summary;

    alpha=0.05;

    if numerator=0 then
        lower_prop=0;
    else
        lower_prop=quantile(
            "BETA",
            alpha/2,
            numerator,
            denom-numerator+1
        );


    if numerator=denom then
        upper_prop=1;
    else
        upper_prop=quantile(
            "BETA",
            1-alpha/2,
            numerator+1,
            denom-numerator
        );


    lower_pct=100*lower_prop;
    upper_pct=100*upper_prop;
run;


data orr_rows;
    set orr_final;

    length display_label $100
           value $50;


    row_order=7;
    display_label="OBJECTIVE RESPONSE RATE (1)";

    value=cats(
        strip(put(numerator,3.)),
        "/",
        strip(put(denom,3.)),
        " (",
        strip(put(100*numerator/denom,5.1)),
        "%)"
    );

    output;


    row_order=8;
    display_label="   (95% CI)";

    value=cats(
        "(",
        strip(put(lower_pct,5.1)),
        ", ",
        strip(put(upper_pct,5.1)),
        ")"
    );

    output;

    keep agecatn
         trtn
         row_order
         display_label
         value;
run;


data table_long;
    set response_rows
        reason_rows
        orr_rows;
run;

proc sort data=table_long;
    by agecatn
       row_order
       display_label
       trtn;
run;


proc print data=table_long noobs;
    var agecatn
        trtn
        row_order
        display_label
        value;

    title "Diagnostic: All Table 13 Rows Before Transpose";
run;

title;


proc transpose
    data=table_long
    out=table_wide(drop=_name_)
    prefix=col;

    by agecatn
       row_order
       display_label;

    id trtn;
    var value;
run;



data final_table;
    set table_wide;

    length col1-col3 $50;
    if row_order ne 0 then do;

        if missing(col1) then col1="0 (0.0%)";
        if missing(col2) then col2="0 (0.0%)";
        if missing(col3) then col3="0 (0.0%)";

    end;
run;


data table_lt65
     table_ge65;

    set final_table;

    if agecatn=1 then
        output table_lt65;

    else if agecatn=2 then
        output table_ge65;
run;


proc print data=final_table noobs;
    var agecatn
        row_order
        display_label
        col1-col3;

    title "Diagnostic: Final Table 13 Dataset";
run;

title;


ods listing close;

ods rtf
    file="&OUTPATH./Output_6.rtf"
    style=journal
    bodytitle;


title1 j=c height=10pt
    "Table 13:";

title2 j=c height=10pt
    "Best Overall Response per Investigator by Age Category";

title3 j=c height=10pt
    "ITT Subjects";



%macro age_section(
    data=,
    subgroup=,
    na=,
    nb=,
    nt=
);


ods rtf text=
"^S={
    font_face='Courier New'
    font_size=8pt
    font_weight=bold
    just=left
}
Subgroup: Age Category - &subgroup";


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
        width=9.2in
        font_face="Courier New"
        font_size=8pt
    ]

    style(header)=[
        font_face="Courier New"
        font_size=8pt
        font_weight=normal
        just=center
        borderbottomwidth=1
    ]

    style(column)=[
        font_face="Courier New"
        font_size=8pt
    ];


    columns row_order
            display_label

            (
                "Number of Subjects (%)"
                col1
                col2
                col3
            );


    define row_order /
        order
        noprint;


    define display_label /
        display
        " "
        style(column)=[
            cellwidth=4.0in
            just=left
            asis=on
        ];


    define col1 /
        display
        "Trt A|(N=&na)"
        style(column)=[
            cellwidth=1.55in
            just=center
        ];


    define col2 /
        display
        "Trt B|(N=&nb)"
        style(column)=[
            cellwidth=1.55in
            just=center
        ];


    define col3 /
        display
        "Total|(N=&nt)"
        style(column)=[
            cellwidth=1.55in
            just=center
        ];


    compute display_label;

        if row_order=0 then
            call define(
                _row_,
                "style",
                "style=[font_weight=bold]"
            );

    endcomp;


    compute before row_order;

        if row_order=7 then
            line " ";

    endcomp;

run;


ods rtf text=
"^S={font_size=6pt} ";


%mend age_section;


%age_section(
    data=table_lt65,
    subgroup=< 65,
    na=&n_lt65_a,
    nb=&n_lt65_b,
    nt=&n_lt65_t
);



%age_section(
    data=table_ge65,
    subgroup=>= 65,
    na=&n_ge65_a,
    nb=&n_ge65_b,
    nt=&n_ge65_t
);


ods rtf text=
"^S={
    font_face='Arial'
    font_size=8pt
    just=left
}
Programming Notes: Calculate 95% CI of ORR by PROC FREQ using Binomial exact options.";


ods rtf text=
"^S={
    font_face='Arial'
    font_size=8pt
    just=left
}
(1) Objective Response Rate = Complete Response + Partial Response.";


ods rtf close;
ods listing;

title;
footnote;


proc printto;
run;