/* Output 7 */;
options validvarname=upcase
        nodate
        nonumber
        orientation=portrait
        missing=" ";

ods escapechar="^";

%let INPATH  = /home/u64124548/sasuser.v94/TLF - Creation/Input;
%let OUTPATH = /home/u64124548/sasuser.v94/TLF - Creation/Output;


proc printto
    log="&OUTPATH./Output_7.log"
    new;
run;


proc import
    datafile="&INPATH./ADEFF.xls"
    out=work.adeff_raw
    dbms=xls
    replace;

    sheet="ADEFF";
    getnames=yes;
run;


proc contents data=work.adeff_raw varnum;
run;

proc print data=work.adeff_raw(obs=20) noobs;
    title "Diagnostic: Imported ADEFF";
run;

title;


data viral_load;
    set work.adeff_raw;

    where upcase(strip(ittfl))="Y"
      and upcase(strip(paramcd))="VLOAD"
      and upcase(strip(anl01fl))="Y"
      and not missing(aval);

    length treatment $20
           test_day  $20;

    if upcase(strip(trt01a))="ACTIVE A" then do;
        trtn=1;
        treatment="Active A";
    end;

    else if upcase(strip(trt01a))="ACTIVE B" then do;
        trtn=2;
        treatment="Active B";
    end;

    else delete;


    select (avisitn);

        when (1) do;
            visit_order=1;
            test_day="Week 1";
        end;

        when (4) do;
            visit_order=2;
            test_day="Week 4";
        end;

        when (8) do;
            visit_order=3;
            test_day="Week 8";
        end;

        when (12) do;
            visit_order=4;
            test_day="Week 12";
        end;

        when (16) do;
            visit_order=5;
            test_day="Week 16";
        end;

        otherwise delete;

    end;
run;



proc freq data=viral_load;
    tables test_day*treatment / missing;

    title "Diagnostic: Viral Load Records by Visit and Treatment";
run;

title;

proc means data=viral_load
           n nmiss mean std stderr min max
           maxdec=4;

    class test_day treatment;
    var aval;

    title "Diagnostic: Viral Load Summary";
run;

title;


proc means data=viral_load
           nway
           noprint;

    class visit_order
          test_day
          trtn
          treatment;

    var aval;

    output out=viral_summary_raw(drop=_type_ _freq_)
        n      = n
        mean   = mean
        stderr = se;
run;



data visit_shell;
    length test_day $20;

    visit_order=1;
    test_day="Week 1";
    output;

    visit_order=2;
    test_day="Week 4";
    output;

    visit_order=3;
    test_day="Week 8";
    output;

    visit_order=4;
    test_day="Week 12";
    output;

    visit_order=5;
    test_day="Week 16";
    output;
run;


data treatment_shell;
    length treatment $20;

    trtn=1;
    treatment="Active A";
    output;

    trtn=2;
    treatment="Active B";
    output;
run;


proc sql;
    create table report_shell as

    select v.visit_order,
           v.test_day,
           t.trtn,
           t.treatment

    from visit_shell as v
         cross join treatment_shell as t

    order by v.visit_order,
             t.trtn;
quit;



proc sql;
    create table viral_report_raw as

    select s.visit_order,
           s.test_day,
           s.trtn,
           s.treatment,

           a.n,
           a.mean,
           a.se

    from report_shell as s

    left join viral_summary_raw as a

      on  s.visit_order=a.visit_order
      and s.trtn=a.trtn

    order by s.visit_order,
             s.trtn;
quit;



data viral_report;
    set viral_report_raw;

    length n_display      $10
           result_display $40
           day_display    $20;

    if not missing(n) then
        n_display=strip(put(n,3.));
    else
        n_display="0";


    if not missing(mean) then
        result_display=cats(
            strip(put(mean,8.3)),
            " (",
            strip(put(se,8.3)),
            ")"
        );
    else
        result_display="NE";


    by visit_order trtn;

    if first.visit_order then
        day_display=test_day;
    else
        day_display="";
run;



proc print data=viral_report noobs;
    var visit_order
        day_display
        treatment
        n_display
        result_display;

    title "Diagnostic: Final Table 11 Dataset";
run;

title;



ods listing close;

ods rtf
    file="&OUTPATH./Output_7.rtf"
    style=journal
    bodytitle;


title1 j=c height=10pt
    "Table 11:";

title2 j=c height=10pt
    "Summary of Viral Load over time";

title3 j=c height=10pt
    "ITT Population";


footnote1 j=l height=8pt
    "Calculated using PROC MEANS.";


proc report
    data=viral_report
    nowd
    missing
    split="|"

    style(report)=[
        frame=hsides
        rules=groups
        cellpadding=2
        cellspacing=0
        width=6.8in
        font_face="Times New Roman"
        font_size=9pt
    ]

    style(header)=[
        font_face="Times New Roman"
        font_size=9pt
        font_weight=normal
        just=center
        borderbottomwidth=1
    ]

    style(column)=[
        font_face="Times New Roman"
        font_size=9pt
    ];


    columns visit_order
            day_display
            trtn
            treatment
            n_display
            result_display;


    define visit_order /
        order
        noprint;


    define day_display /
        display
        "Test Day"
        style(column)=[
            cellwidth=1.45in
            just=left
            asis=on
        ];


    define trtn /
        order
        noprint;


    define treatment /
        display
        "Treatment"
        style(column)=[
            cellwidth=1.50in
            just=left
        ];


    define n_display /
        display
        "N"
        style(column)=[
            cellwidth=.85in
            just=center
        ];


    define result_display /
        display
        "Unadjusted Mean (SE)"
        style(column)=[
            cellwidth=2.20in
            just=center
        ];


    compute after visit_order;
        line " ";
    endcomp;

run;


ods rtf close;
ods listing;


title;
footnote;

proc printto;
run;