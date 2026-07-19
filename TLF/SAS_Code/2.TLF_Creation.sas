/* Output 2 */;
options validvarname=upcase
        nodate
        nonumber
        orientation=portrait;

ods escapechar='^';

%let INPATH = /home/u64124548/sasuser.v94/TLF - Creation/Input;
%let OUTPATH = /home/u64124548/sasuser.v94/TLF - Creation/Output;

proc printto
    log="&OUTPATH./Output_2.log"
    new;
run;


libname xsl xport "&INPATH./ADSL.xpt";
libname xae xport "&INPATH./ADAE.xpt";

proc copy in=xsl out=work memtype=data;
run;

proc copy in=xae out=work memtype=data;
run;

libname xsl clear;
libname xae clear;


data adsl_safety;
    set work.adsl;

    where upcase(strip(saffl))="Y";

    if upcase(strip(trt01a))="PLACEBO" then trtn=1;
    else if upcase(strip(trt01a))="CMP-135" then trtn=2;
    else delete;
run;

proc sql;
    create table safety_denominators as
    select trtn,
           count(distinct usubjid) as denominator
    from adsl_safety
    group by trtn
    order by trtn;
quit;

proc sql noprint;
    select denominator
    into :n_placebo trimmed
    from safety_denominators
    where trtn=1;

    select denominator
    into :n_cmp trimmed
    from safety_denominators
    where trtn=2;
quit;

%put NOTE: Placebo safety denominator = &n_placebo;
%put NOTE: CMP-135 safety denominator = &n_cmp;


data adae_te;
    set work.adae;

    where upcase(strip(saffl))="Y"
      and upcase(strip(trtem))="Y";

    if upcase(strip(trt01a))="PLACEBO" then trtn=1;
    else if upcase(strip(trt01a))="CMP-135" then trtn=2;
    else delete;

    length soc $200
           pt  $200;

    soc=upcase(strip(aebodsys));
    pt=propcase(strip(aedecod));

    if missing(aetoxgrn) then grade=99;
    else grade=aetoxgrn;
run;


proc sort data=adae_te
          out=pt_sorted;
    by trtn
       usubjid
       soc
       pt
       descending grade;
run;

data pt_worst;
    set pt_sorted;

    by trtn
       usubjid
       soc
       pt
       descending grade;

    if first.pt;
run;


proc sort data=adae_te
          out=soc_sorted;
    by trtn
       usubjid
       soc
       descending grade;
run;

data soc_worst;
    set soc_sorted;

    by trtn
       usubjid
       soc
       descending grade;

    if first.soc;

    length pt $200;
    pt="- Overall -";
run;


proc sort data=adae_te
          out=any_sorted;
    by trtn
       usubjid
       descending grade;
run;

data any_worst;
    set any_sorted;

    by trtn
       usubjid
       descending grade;

    if first.usubjid;

    length soc pt $200;

    soc="- ANY ADVERSE EVENTS -";
    pt ="";
run;


data pt_all;
    set pt_worst;
    grade=0;
run;

data soc_all;
    set soc_worst;
    grade=0;
run;

data any_all;
    set any_worst;
    grade=0;
run;


data ae_count_source;
    length level 8;

    set any_all  (in=a)
        any_worst(in=b)
        soc_all  (in=c)
        soc_worst(in=d)
        pt_all   (in=e)
        pt_worst (in=f);

    if a or b then level=1;
    else if c or d then level=2;
    else if e or f then level=3;
run;


proc sql;
    create table ae_counts as
    select level,
           soc,
           pt,
           grade,
           trtn,
           count(distinct usubjid) as count
    from ae_count_source
    group by level,
             soc,
             pt,
             grade,
             trtn;
quit;



proc sql;
    create table soc_order as
    select distinct soc
    from soc_worst
    order by soc;
quit;

data soc_order;
    set soc_order;
    soc_order=_n_;
run;


proc sql;
    create table pt_total_count as
    select soc,
           pt,
           count(distinct usubjid) as total_count
    from pt_worst
    group by soc,
             pt;
quit;

proc sort data=pt_total_count;
    by soc
       descending total_count
       pt;
run;

data pt_order;
    set pt_total_count;

    by soc;

    if first.soc then pt_order=0;
    pt_order+1;
run;



data any_hierarchy;
    length soc pt $200;

    level=1;
    soc="- ANY ADVERSE EVENTS -";
    pt="";
    soc_order=0;
    pt_order=0;

    output;
run;

proc sql;
    create table soc_hierarchy as
    select 2 as level,
           a.soc,
           "- Overall -" as pt length=200,
           a.soc_order,
           0 as pt_order
    from soc_order as a;
quit;


proc sql;
    create table pt_hierarchy as
    select 3 as level,
           a.soc,
           a.pt,
           b.soc_order,
           a.pt_order
    from pt_order as a

    left join soc_order as b
        on a.soc=b.soc;
quit;


data hierarchy;
    set any_hierarchy
        soc_hierarchy
        pt_hierarchy;
run;


data grade_shell;
    length grade_label $30;

    grade_order=1;
    grade=0;
    grade_label="- All grades -";
    output;

    grade_order=2;
    grade=5;
    grade_label="5";
    output;

    grade_order=3;
    grade=4;
    grade_label="4";
    output;

    grade_order=4;
    grade=3;
    grade_label="3";
    output;

    grade_order=5;
    grade=2;
    grade_label="2";
    output;

    grade_order=6;
    grade=1;
    grade_label="1";
    output;

    grade_order=7;
    grade=99;
    grade_label="Not graded";
    output;
run;


proc sql;
    create table ungraded_rows as
    select distinct level,
           soc,
           pt
    from ae_counts
    where grade=99;
quit;


proc sql;
    create table hierarchy_grades as
    select h.level,
           h.soc,
           h.pt,
           h.soc_order,
           h.pt_order,
           g.grade,
           g.grade_order,
           g.grade_label
    from hierarchy as h,
         grade_shell as g

    where g.grade ne 99

       or exists
          (
              select 1
              from ungraded_rows as u
              where h.level=u.level
                and h.soc=u.soc
                and h.pt=u.pt
          )

    order by h.soc_order,
             h.level,
             h.pt_order,
             g.grade_order;
quit;



data treatment_shell;
    do trtn=1 to 2;
        output;
    end;
run;

proc sql;
    create table full_shell as
    select h.*,
           t.trtn
    from hierarchy_grades as h,
         treatment_shell as t

    order by h.soc_order,
             h.level,
             h.pt_order,
             h.grade_order,
             t.trtn;
quit;


proc sql;
    create table ae_full as
    select s.level,
           s.soc,
           s.pt,
           s.soc_order,
           s.pt_order,
           s.grade,
           s.grade_order,
           s.grade_label,
           s.trtn,
           coalesce(c.count,0) as count,
           d.denominator

    from full_shell as s

    left join ae_counts as c
        on  s.level=c.level
        and s.soc=c.soc
        and s.pt=c.pt
        and s.grade=c.grade
        and s.trtn=c.trtn

    left join safety_denominators as d
        on s.trtn=d.trtn

    order by s.soc_order,
             s.level,
             s.pt_order,
             s.grade_order,
             s.trtn;
quit;


data ae_formatted;
    set ae_full;

    length value $40;

    value=cats(
        strip(put(count,3.)),
        " (",
        strip(put(100*count/denominator,5.1)),
        "%)"
    );
run;


proc sort data=ae_formatted;
    by soc_order
       level
       pt_order
       soc
       pt
       grade_order
       grade
       grade_label
       trtn;
run;

proc transpose data=ae_formatted
               out=ae_wide(drop=_name_)
               prefix=col;

    by soc_order
       level
       pt_order
       soc
       pt
       grade_order
       grade
       grade_label;

    id trtn;
    var value;
run;


data final_ae;
    set ae_wide;

    length display_term $200;

    if grade=0 then do;

        if level=1 then
            display_term="- Any adverse events -";

        else if level=2 then
            display_term=upcase(strip(soc));

        else if level=3 then
            display_term="   " || strip(pt);

    end;

    else display_term="";


    retain row_number 0;

    row_number+1;

    page_group=ceil(row_number/38);
run;


proc print data=final_ae(obs=100) noobs;
    var soc_order
        level
        pt_order
        display_term
        grade_label
        col1
        col2;

    title "Diagnostic Output 2 Data";
run;

title;


ods listing close;

ods rtf file="&OUTPATH./Output_2.rtf"
        style=journal
        bodytitle;

title1 j=c height=9pt
       "Table 14.3/2";

title2 j=c height=9pt
       "Treatment-Emergent Adverse Events by MedDRA System Organ Class,";

title3 j=c height=9pt
       "Preferred Term and Maximum NCI-CTCAE Grade";

title4 j=c height=9pt
       "Safety-Evaluable Patients";

/* footnote1 j=l height=7pt */
/*     "NCI CTCAE = National Cancer Institute Common Terminology Criteria for Adverse Events."; */
/*  */
/* footnote2 j=l height=7pt */
/*     "A patient with multiple occurrences of the same preferred term is counted once at the highest grade."; */
/*  */
/* footnote3 j=l height=7pt */
/*     "Percentages are based on the number of safety-evaluable patients in each treatment group."; */
/*  */
/* footnote4 j=l height=7pt */
/*     "Study PRJ5457C     TLG Specifications, Version v1.0"; */

proc report data=final_ae
            nowd
            missing
            split="|"

            style(report)=[
                frame=hsides
                rules=groups
                cellpadding=0
                cellspacing=0
                width=6.8in
                font_face="Arial"
                font_size=7.5pt
            ]

            style(header)=[
                font_face="Arial"
                font_size=7.5pt
                font_weight=normal
                just=center
                borderbottomwidth=1
            ]

            style(column)=[
                font_face="Arial"
                font_size=7.5pt
            ];

    columns page_group
            soc_order
            level
            pt_order
            grade_order
            display_term
            grade_label
            col1
            col2;

    define page_group /
        order
        noprint;

    define soc_order /
        order
        noprint;

    define level /
        order
        noprint;

    define pt_order /
        order
        noprint;

    define grade_order /
        order
        noprint;

    define display_term /
        display
        "MedDRA System Organ Class and|Preferred Term"
        style(column)=[
            cellwidth=2.75in
            just=left
            asis=on
        ];

    define grade_label /
        display
        "NCI-CTCAE Grade"
        style(column)=[
            cellwidth=1.0in
            just=center
        ];

    define col1 /
        display
        "Placebo|(n=&n_placebo)"
        style(column)=[
            cellwidth=1.05in
            just=center
        ];

    define col2 /
        display
        "CMP-135|(n=&n_cmp)"
        style(column)=[
            cellwidth=1.05in
            just=center
        ];

    break after page_group / page;

run;

ods rtf close;
ods listing;

title;
footnote;

proc printto;
run;