/* Output 3 */;
options validvarname=upcase
        nodate
        nonumber
        orientation=landscape;

ods escapechar="^";

%let INPATH  = /home/u64124548/sasuser.v94/TLF - Creation/Input;
%let OUTPATH = /home/u64124548/sasuser.v94/TLF - Creation/Output;

proc printto
    log="&OUTPATH./Output_3.log"
    new;
run;

libname xtte xport "&INPATH./ADTTE.xpt";

proc copy in=xtte out=work memtype=data;
run;

libname xtte clear;


data pfs;
    set work.adtte;

    where upcase(strip(ittfl))="Y"
      and upcase(strip(paramcd))="TTPFS";

    if upcase(strip(trt01a))="PLACEBO" then trtn=1;
    else if upcase(strip(trt01a))="CMP-135" then trtn=2;
    else delete;


    if cnsr < 0.5 then event=1;
    else event=0;

    if index(upcase(evntdesc),"DISEASE PROGRESSION") > 0 then
        event_type=1;

    else if index(upcase(evntdesc),"DEATH") > 0 then
        event_type=2;

    else event_type=0;
run;


proc freq data=pfs;
    tables remissn*trt01a
           remissn*event
           / missing;
run;


data pfs_analysis;
    set pfs;

    groupn=remissn;
    output;

    groupn=3;
    output;
run;


proc sql;
    create table count_summary as
    select groupn,
           trtn,

           count(distinct usubjid) as nsub,

           count(distinct
                 case when event=1
                      then usubjid
                 end) as nevent,

           count(distinct
                 case when event_type=1
                      then usubjid
                 end) as nprogression,

           count(distinct
                 case when event_type=2
                      then usubjid
                 end) as ndeath,

           count(distinct
                 case when event=0
                      then usubjid
                 end) as ncensored

    from pfs_analysis

    group by groupn,
             trtn

    order by groupn,
             trtn;
quit;


data count_rows;
    set count_summary;

    length row_label $100
           value     $40;

    row_order=1;
    row_label="No. of Subjects";
    value=strip(put(nsub,4.));
    output;

    row_order=2;
    row_label="   No. of Subjects with an event (%)";

    value=cats(
        strip(put(nevent,3.)),
        " (",
        strip(put(100*nevent/nsub,5.1)),
        "%)"
    );
    output;

    row_order=3;
    row_label="      Earliest contributing event:";
    value="";
    output;

    row_order=4;
    row_label="         Disease progression";
    value=strip(put(nprogression,3.));
    output;

    row_order=5;
    row_label="         Death";
    value=strip(put(ndeath,3.));
    output;

    row_order=6;
    row_label="   No. of Subjects without an event (%)";

    value=cats(
        strip(put(ncensored,3.)),
        " (",
        strip(put(100*ncensored/nsub,5.1)),
        "%)"
    );
    output;

    keep groupn trtn row_order row_label value;
run;


%macro km_summary(group=, outprefix=);

    data km_input;
        set pfs_analysis;
        where groupn=&group;
    run;

    proc sort data=km_input;
        by trtn;
    run;


    ods exclude all;

    ods output Quartiles=&outprefix._quartiles;

    proc lifetest data=km_input
                  method=km
                  alpha=0.05
                  notable;

        time aval*event(0);
        strata trtn;
    run;

    ods exclude none;


    proc sort data=km_input
              out=&outprefix._minmax_source;

        by trtn aval;
    run;

    data &outprefix._minmax;
        set &outprefix._minmax_source;

        by trtn aval;

        retain minimum
               maximum
               min_event
               max_event;

        if first.trtn then do;
            minimum=aval;
            maximum=aval;
            min_event=event;
            max_event=event;
        end;

        maximum=aval;
        max_event=event;

        if last.trtn then do;

            length minimum_text $20
                   maximum_text $20
                   value        $50;

            minimum_text=strip(put(minimum,5.1));
            maximum_text=strip(put(maximum,5.1));

            if min_event=0 then
                minimum_text=cats(minimum_text,"+");

            if max_event=0 then
                maximum_text=cats(maximum_text,"+");

            value=cats(
                minimum_text,
                " - ",
                maximum_text
            );

            groupn=&group;
            row_order=12;
            row_label="   Minimum–maximum";

            output;
        end;

        keep groupn trtn row_order row_label value;
    run;


    data &outprefix._quartiles_clean;
        set &outprefix._quartiles;

        length value     $50
               row_label $100;

        trtn=input(compress(vvaluex("STRATUM"),,"KD"),best.);

        percentile=input(vvaluex("PERCENT"),best.);
        estimate  =input(vvaluex("ESTIMATE"),best.);
        lower_ci  =input(vvaluex("LOWERLIMIT"),best.);
        upper_ci  =input(vvaluex("UPPERLIMIT"),best.);

        groupn=&group;


        if percentile=50 then do;

            row_order=8;
            row_label="   Median";

            if missing(estimate) then value="NE";
            else value=strip(put(estimate,5.1));

            output;


            row_order=9;
            row_label="      (95% CI)";

            value=cats(
                "(",
                ifc(
                    missing(lower_ci),
                    "NE",
                    strip(put(lower_ci,5.1))
                ),
                ", ",
                ifc(
                    missing(upper_ci),
                    "NE",
                    strip(put(upper_ci,5.1))
                ),
                ")"
            );

            output;
        end;

        keep groupn
             trtn
             percentile
             estimate
             row_order
             row_label
             value;
    run;



    proc sql;
        create table &outprefix._percentiles as
        select &group as groupn,

               input(
                   compress(vvaluex("STRATUM"),,"KD"),
                   best.
               ) as trtn,

               max(
                   case
                       when input(vvaluex("PERCENT"),best.)=25
                       then input(vvaluex("ESTIMATE"),best.)
                   end
               ) as q25,

               max(
                   case
                       when input(vvaluex("PERCENT"),best.)=75
                       then input(vvaluex("ESTIMATE"),best.)
                   end
               ) as q75

        from &outprefix._quartiles

        group by calculated trtn;
    quit;

    data &outprefix._percentile_row;
        set &outprefix._percentiles;

        length row_label $100
               value     $50;

        row_order=11;
        row_label="   25th–75th percentile";

        value=cats(
            ifc(
                missing(q25),
                "NE",
                strip(put(q25,5.1))
            ),
            " - ",
            ifc(
                missing(q75),
                "NE",
                strip(put(q75,5.1))
            )
        );

        keep groupn trtn row_order row_label value;
    run;

%mend km_summary;


%km_summary(group=1, outprefix=second);
%km_summary(group=2, outprefix=third);
%km_summary(group=3, outprefix=overall);



data pfs_descriptive_rows;
    set count_rows

        second_quartiles_clean
        second_percentile_row
        second_minmax

        third_quartiles_clean
        third_percentile_row
        third_minmax

        overall_quartiles_clean
        overall_percentile_row
        overall_minmax;
run;


data pfs_heading;
    length row_label $100
           value     $50;

    do groupn=1 to 3;
        do trtn=1 to 2;

            row_order=7;
            row_label="Progression-Free survival (month)";
            value="";

            output;
        end;
    end;
run;

data pfs_descriptive_rows;
    set pfs_descriptive_rows
        pfs_heading;
run;


%macro unstratified(group=, outprefix=);

    data model_input;
        set pfs_analysis;
        where groupn=&group;
    run;


    ods exclude all;

    ods output HazardRatios=&outprefix._hr;

    proc phreg data=model_input;

        class trtn(ref="1") / param=ref;

        model aval*event(0)=trtn
            / risklimits;

        hazardratio trtn / diff=ref;
    run;

    ods exclude none;


    data &outprefix._hr_rows;
        set &outprefix._hr;

        length row_label $100
               value     $50;

        groupn=&group;

        trtn=2;

        hazard_ratio=input(vvaluex("HAZARDRATIO"),best.);
        lower_ci    =input(vvaluex("HRLOWERCL"),best.);
        upper_ci    =input(vvaluex("HRUPPERCL"),best.);


        row_order=14;
        row_label="   Hazard ratio (relative to placebo)";
        value=strip(put(hazard_ratio,6.3));
        output;


        row_order=15;
        row_label="      (95% CI)";

        value=cats(
            "(",
            strip(put(lower_ci,6.3)),
            ", ",
            strip(put(upper_ci,6.3)),
            ")"
        );

        output;

        keep groupn trtn row_order row_label value;
    run;


    ods exclude all;

    ods output HomTests=&outprefix._tests;

    proc lifetest data=model_input
                  notable;

        time aval*event(0);

        strata trtn /
            test=(
                logrank
                wilcoxon
            );
    run;

    ods exclude none;


    data &outprefix._test_rows;
        set &outprefix._tests;

        length row_label $100
               value     $50
               test_name $100;

        groupn=&group;
        trtn=2;

        test_name=upcase(vvaluex("TEST"));

        pvalue=input(vvaluex("PROBCHISQ"),best.);

        if missing(pvalue) then
            pvalue=input(vvaluex("PVALUE"),best.);


        if index(test_name,"LOG") > 0 then do;

            row_order=17;
            row_label="      Log-rank";
            value=strip(put(pvalue,7.4));
            output;

        end;


        else if index(test_name,"WIL") > 0 then do;

            row_order=18;
            row_label="      Wilcoxon";
            value=strip(put(pvalue,7.4));
            output;

        end;

        keep groupn trtn row_order row_label value;
    run;

%mend unstratified;


%unstratified(group=1, outprefix=second_un);
%unstratified(group=2, outprefix=third_un);
%unstratified(group=3, outprefix=overall_un);


data unstratified_headings;
    length row_label $100
           value     $50;

    do groupn=1 to 3;
        do trtn=1 to 2;

            row_order=13;
            row_label="Unstratified analysis";
            value="";
            output;

            row_order=16;
            row_label="   p-value (relative to placebo)";
            value="";
            output;

        end;
    end;
run;


data unstratified_rows;
    set second_un_hr_rows
        second_un_test_rows

        third_un_hr_rows
        third_un_test_rows

        overall_un_hr_rows
        overall_un_test_rows

        unstratified_headings;
run;


ods exclude all;

ods output HazardRatios=stratified_hr;

proc phreg data=pfs;

    class trtn(ref="1") / param=ref;

    model aval*event(0)=trtn
        / risklimits;

    strata remissn;

    hazardratio trtn / diff=ref;
run;

ods exclude none;


data stratified_hr_rows;
    set stratified_hr;

    length row_label $100
           value     $50;

    groupn=3;
    trtn=2;

    hazard_ratio=input(vvaluex("HAZARDRATIO"),best.);
    lower_ci    =input(vvaluex("HRLOWERCL"),best.);
    upper_ci    =input(vvaluex("HRUPPERCL"),best.);


    row_order=20;
    row_label="   Hazard ratio (relative to placebo)";
    value=strip(put(hazard_ratio,6.3));
    output;


    row_order=21;
    row_label="      (95% CI)";

    value=cats(
        "(",
        strip(put(lower_ci,6.3)),
        ", ",
        strip(put(upper_ci,6.3)),
        ")"
    );

    output;

    keep groupn trtn row_order row_label value;
run;


ods exclude all;

ods output HomTests=stratified_tests;

proc lifetest data=pfs
              notable;

    time aval*event(0);

    strata trtn /
        group=remissn
        test=(
            logrank
            wilcoxon
        );
run;

ods exclude none;


data stratified_test_rows;
    set stratified_tests;

    length row_label $100
           value     $50
           test_name $100;

    groupn=3;
    trtn=2;

    test_name=upcase(vvaluex("TEST"));

    pvalue=input(vvaluex("PROBCHISQ"),best.);

    if missing(pvalue) then
        pvalue=input(vvaluex("PVALUE"),best.);


    if index(test_name,"LOG") > 0 then do;

        row_order=23;
        row_label="      Log-rank";
        value=strip(put(pvalue,7.4));
        output;

    end;


    else if index(test_name,"WIL") > 0 then do;

        row_order=24;
        row_label="      Wilcoxon";
        value=strip(put(pvalue,7.4));
        output;

    end;

    keep groupn trtn row_order row_label value;
run;


data stratified_headings;
    length row_label $100
           value     $50;

    groupn=3;
    trtn=2;

    row_order=19;
    row_label="Stratified analysis";
    value="";
    output;

    row_order=22;
    row_label="   p-value (relative to placebo)";
    value="";
    output;
run;


data stratified_rows;
    set stratified_hr_rows
        stratified_test_rows
        stratified_headings;
run;


data complete_long;
    set pfs_descriptive_rows
        unstratified_rows
        stratified_rows;
run;



data complete_long;
    set complete_long;

    column_number=((groupn-1)*2)+trtn;
run;

proc sort data=complete_long;
    by row_order
       row_label
       column_number;
run;


proc transpose data=complete_long
               out=complete_wide(drop=_name_)
               prefix=col;

    by row_order row_label;

    id column_number;
    var value;
run;


data final_table;
    set complete_wide;

    length col1-col6 $50;

    if row_order in (3,7,13,16,19,22) then do;

        if row_order=3 then
            row_label="   Earliest contributing event:";

        col1="";
        col2="";
        col3="";
        col4="";
        col5="";
        col6="";
    end;
run;


proc sql noprint;

    select count(distinct usubjid)
    into :n_2_pl trimmed
    from pfs
    where remissn=1
      and trtn=1;

    select count(distinct usubjid)
    into :n_2_cmp trimmed
    from pfs
    where remissn=1
      and trtn=2;

    select count(distinct usubjid)
    into :n_3_pl trimmed
    from pfs
    where remissn=2
      and trtn=1;

    select count(distinct usubjid)
    into :n_3_cmp trimmed
    from pfs
    where remissn=2
      and trtn=2;

    select count(distinct usubjid)
    into :n_all_pl trimmed
    from pfs
    where trtn=1;

    select count(distinct usubjid)
    into :n_all_cmp trimmed
    from pfs
    where trtn=2;

quit;

%put NOTE: 2nd remission Placebo N = &n_2_pl;
%put NOTE: 2nd remission CMP-135 N = &n_2_cmp;
%put NOTE: 3rd remission Placebo N = &n_3_pl;
%put NOTE: 3rd remission CMP-135 N = &n_3_cmp;
%put NOTE: Overall Placebo N = &n_all_pl;
%put NOTE: Overall CMP-135 N = &n_all_cmp;


proc print data=final_table noobs;
    var row_order
        row_label
        col1-col6;

    title "Diagnostic Dataset for Table 14.2/1";
run;

title;


ods listing close;

ods rtf file="&OUTPATH./Output_3.rtf"
        style=journal
        bodytitle;

title1 j=c height=9pt
       "Table 14.2/1";

title2 j=c height=9pt
       "Progression-Free Survival by Remission Status";

title3 j=c height=9pt
       "Randomized Subjects";


/* footnote1 j=l height=7pt */
/*     "+ = censored value."; */
/*  */
/* footnote2 j=l height=7pt */
/*     "Progression or death by any cause, whichever occurred first."; */
/*  */
/* footnote3 j=l height=7pt */
/*     "Summaries of time-to-event variables were estimated using Kaplan-Meier curves."; */
/*  */
/* footnote4 j=l height=7pt */
/*     "The 95% confidence interval for the median was calculated using the Brookmeyer and Crowley method."; */
/*  */
/* footnote5 j=l height=7pt */
/*     "The hazard ratio was estimated using Cox regression."; */
/*  */
/* footnote6 j=l height=7pt */
/*     "Study PRJ5457C     TLG Specifications, Version v1.0"; */


proc report data=final_table
            nowd
            missing
            split="|"

            style(report)=[
                frame=hsides
                rules=groups
                cellpadding=1
                cellspacing=0
                width=10.2in
                font_face="Arial"
                font_size=7.5pt
            ]

            style(header)=[
                font_face="Arial"
                font_size=7.5pt
                font_weight=normal
                just=center
            ]

            style(column)=[
                font_face="Arial"
                font_size=7.5pt
            ];

    columns row_order
            row_label

            ("2^{super nd} remission"
                col1
                col2
            )

            ("3^{super rd} remission"
                col3
                col4
            )

            ("Overall"
                col5
                col6
            );


    define row_order /
        order
        noprint;


    define row_label /
        display
        " "
        style(column)=[
            cellwidth=3.1in
            just=left
            asis=on
        ];


    define col1 /
        display
        "Placebo|(n=&n_2_pl)"
        style(column)=[
            cellwidth=1.15in
            just=center
        ];


    define col2 /
        display
        "CMP-135|(n=&n_2_cmp)"
        style(column)=[
            cellwidth=1.15in
            just=center
        ];


    define col3 /
        display
        "Placebo|(n=&n_3_pl)"
        style(column)=[
            cellwidth=1.15in
            just=center
        ];


    define col4 /
        display
        "CMP-135|(n=&n_3_cmp)"
        style(column)=[
            cellwidth=1.15in
            just=center
        ];


    define col5 /
        display
        "Placebo|(n=&n_all_pl)"
        style(column)=[
            cellwidth=1.15in
            just=center
        ];


    define col6 /
        display
        "CMP-135|(n=&n_all_cmp)"
        style(column)=[
            cellwidth=1.15in
            just=center
        ];

    compute row_label;

        if row_order=19 then
            call define(
                _row_,
                "style",
                "style=[bordertopwidth=1]"
            );

    endcomp;


    compute after;

        line " ";

    endcomp;

run;

ods rtf close;
ods listing;

title;
footnote;

proc printto;
run;