/* Output 1 */;
options validvarname=upcase
        nodate
        nonumber
        orientation=portrait;

ods escapechar='^';

%let INPATH  = /home/u64124548/sasuser.v94/TLF - Creation/Input;
%let OUTPATH = /home/u64124548/sasuser.v94/TLF - Creation/Output;

proc printto
    log="&OUTPATH./Output_1.log"
    new;
run;


libname xptin xport "&INPATH./ADSL.xpt";

proc copy in=xptin out=work memtype=data;
run;

libname xptin clear;


data adsl_itt;
    set work.adsl;

    where upcase(strip(ittfl)) = "Y";

    length treatment $20;

    if upcase(strip(trt01p)) = "PLACEBO" then do;
        trtn      = 1;
        treatment = "Placebo";
    end;
    else if upcase(strip(trt01p)) = "CMP-135" then do;
        trtn      = 2;
        treatment = "CMP-135";
    end;
    else delete;
run;


data adsl_all;
    set adsl_itt;
    output;

    trtn      = 3;
    treatment = "All Patients";
    output;
run;


proc sql;
    create table denominators as
    select trtn,
           count(distinct usubjid) as denominator
    from adsl_all
    group by trtn
    order by trtn;
quit;

proc sql noprint;
    select denominator
    into :n_placebo trimmed
    from denominators
    where trtn=1;

    select denominator
    into :n_cmp trimmed
    from denominators
    where trtn=2;

    select denominator
    into :n_total trimmed
    from denominators
    where trtn=3;
quit;

%put NOTE: Placebo N = &n_placebo;
%put NOTE: CMP-135 N = &n_cmp;
%put NOTE: Total N = &n_total;


proc means data=adsl_all noprint;
    class trtn;
    var age;

    output out=age_summary_raw
        n      = n
        mean   = mean
        std    = sd
        median = median
        min    = min
        max    = max;
run;

data age_rows;
    set age_summary_raw;

    where _type_=1;

    length row_label $100 value $40;

    section_order=1;

    row_order=1;
    row_label="n";
    value=strip(put(n,8.));
    output;

    row_order=2;
    row_label="Mean (SD)";
    value=cats(
        strip(put(mean,5.1)),
        " (",
        strip(put(sd,5.1)),
        ")"
    );
    output;

    row_order=3;
    row_label="Median";
    value=strip(put(median,5.1));
    output;

    row_order=4;
    row_label="Range";
    value=cats(
        strip(put(min,3.)),
        " - ",
        strip(put(max,3.))
    );
    output;

    keep section_order row_order row_label trtn value;
run;


proc sql;
    create table age_group_count as
    select trtn,
           agegr1n,
           count(distinct usubjid) as count
    from adsl_all
    group by trtn, agegr1n
    order by trtn, agegr1n;
quit;


data age_group_shell;
    length row_label $100;

    do trtn=1 to 3;

        agegr1n=1;
        row_order=2;
        row_label="18–40";
        output;

        agegr1n=2;
        row_order=3;
        row_label="41–64";
        output;

        agegr1n=3;
        row_order=4;
        row_label=">= 65";
        output;

    end;
run;

proc sort data=age_group_shell;
    by trtn agegr1n;
run;

proc sort data=age_group_count;
    by trtn agegr1n;
run;

data age_group_complete;
    merge age_group_shell(in=inshell)
          age_group_count;
    by trtn agegr1n;

    if inshell;

    if missing(count) then count=0;
run;

proc sort data=age_group_complete;
    by trtn;
run;

proc sort data=denominators;
    by trtn;
run;

data age_group_rows;
    merge age_group_complete(in=a)
          denominators;
    by trtn;

    if a;

    length value $40;

    section_order=2;

    value=cats(
        strip(put(count,3.)),
        " (",
        strip(put(100*count/denominator,5.1)),
        "%)"
    );

    keep section_order row_order row_label trtn value;
run;


data age_group_n;
    set denominators;

    length row_label $100 value $40;

    section_order=2;
    row_order=1;
    row_label="n";
    value=strip(put(denominator,8.));

    keep section_order row_order row_label trtn value;
run;


proc sql;
    create table sex_count as
    select trtn,
           count(distinct usubjid) as count
    from adsl_all
    where upcase(strip(sex))="F"
    group by trtn
    order by trtn;
quit;

proc sort data=sex_count;
    by trtn;
run;

data sex_rows;
    merge denominators(in=a)
          sex_count;
    by trtn;

    if a;

    if missing(count) then count=0;

    length row_label $100 value $40;

    section_order=3;
    row_order=2;
    row_label="Female";

    value=cats(
        strip(put(count,3.)),
        " (",
        strip(put(100*count/denominator,5.1)),
        "%)"
    );

    keep section_order row_order row_label trtn value;
run;


data sex_n;
    set denominators;

    length row_label $100 value $40;

    section_order=3;
    row_order=1;
    row_label="n";
    value=strip(put(denominator,8.));

    keep section_order row_order row_label trtn value;
run;

proc sql;
    create table ethnicity_count as
    select trtn,
           upcase(strip(ethnic)) as ethnic_value length=50,
           count(distinct usubjid) as count
    from adsl_all
    group by trtn, calculated ethnic_value
    order by trtn, calculated ethnic_value;
quit;


data ethnicity_shell;
    length ethnic_value $50 row_label $100;

    do trtn=1 to 3;

        ethnicity_order=1;
        row_order=2;
        ethnic_value="HISPANIC OR LATINO";
        row_label="Hispanic or Latino";
        output;

        ethnicity_order=2;
        row_order=3;
        ethnic_value="NOT HISPANIC OR LATINO";
        row_label="Not Hispanic or Latino";
        output;

        ethnicity_order=3;
        row_order=4;
        ethnic_value="NOT AVAILABLE";
        row_label="Not Available";
        output;

    end;
run;

proc sort data=ethnicity_shell;
    by trtn ethnic_value;
run;

proc sort data=ethnicity_count;
    by trtn ethnic_value;
run;

data ethnicity_complete;
    merge ethnicity_shell(in=inshell)
          ethnicity_count;
    by trtn ethnic_value;

    if inshell;

    if missing(count) then count=0;
run;

proc sort data=ethnicity_complete;
    by trtn;
run;

data ethnicity_rows;
    merge ethnicity_complete(in=a)
          denominators;
    by trtn;

    if a;

    length value $40;

    section_order=4;

    value=cats(
        strip(put(count,3.)),
        " (",
        strip(put(100*count/denominator,5.1)),
        "%)"
    );

    keep section_order row_order row_label trtn value;
run;


data ethnicity_n;
    set denominators;

    length row_label $100 value $40;

    section_order=4;
    row_order=1;
    row_label="n";
    value=strip(put(denominator,8.));

    keep section_order row_order row_label trtn value;
run;


data table_long;
    set age_rows
        age_group_n
        age_group_rows
        sex_n
        sex_rows
        ethnicity_n
        ethnicity_rows;
run;

proc sort data=table_long;
    by section_order row_order row_label trtn;
run;


proc print data=table_long noobs;
    title "Diagnostic: Long-format demographic table";
run;

title;


proc transpose data=table_long
               out=table_wide(drop=_name_)
               prefix=col;

    by section_order row_order row_label;
    id trtn;
    var value;
run;


data final_table;
    set table_wide;

    length display_label $100;

    if section_order=1 and row_order=1 then
        display_label="Age (yr)";

    else if section_order=2 and row_order=1 then
        display_label="Age group (yr)";

    else if section_order=3 and row_order=1 then
        display_label="Sex";

    else if section_order=4 and row_order=1 then
        display_label="Ethnicity";

    else
        display_label=cats("   ",strip(row_label));
run;


proc print data=final_table noobs;
    title "Diagnostic: Final demographic table";
run;

title;


ods listing close;

ods rtf file="&OUTPATH./Output_1.rtf"
        style=journal
        bodytitle;

title1 j=c height=10pt "Table 14.1/5";
title2 j=c height=10pt "Demographic and Baseline Characteristics";
title3 j=c height=10pt "Randomized Patients";

/* footnote1 j=l height=8pt "Study PRJ5457C" */
/*           j=r "Page 14 of 80"; */

/* footnote2 j=l height=8pt "TLG Specifications, Version v1.0" */
/*           j=r "Date: %sysfunc(today(),date9.)"; */

proc report data=final_table
            nowd
            missing
            split="|"

            style(report)=[
                frame=hsides
                rules=groups
                cellpadding=1
                cellspacing=0
                width=6.5in
                font_face="Arial"
                font_size=9pt
            ]

            style(header)=[
                font_face="Arial"
                font_size=9pt
                font_weight=normal
                just=center
            ]

            style(column)=[
                font_face="Arial"
                font_size=9pt
            ];

    columns section_order
            row_order
            display_label
            col1
            col2
            col3;

    define section_order /
        order
        noprint;

    define row_order /
        order
        noprint;

    define display_label /
        display
        " "
        style(column)=[
            cellwidth=2.4in
            just=left
            asis=on
        ];

    define col1 /
        display
        "Placebo|(n=&n_placebo)"
        style(column)=[
            cellwidth=1.2in
            just=center
        ];

    define col2 /
        display
        "CMP-135|(n=&n_cmp)"
        style(column)=[
            cellwidth=1.2in
            just=center
        ];

    define col3 /
        display
        "All Patients|(n=&n_total)"
        style(column)=[
            cellwidth=1.2in
            just=center
        ];

    compute before section_order;
        line " ";
    endcomp;

run;

ods rtf close;
ods listing;

title;
footnote;

proc printto;
run;