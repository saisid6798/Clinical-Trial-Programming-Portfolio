/* Output 5 */;
options validvarname=upcase
        nodate
        nonumber
        orientation=landscape
        missing=" ";

ods escapechar="^";

%let INPATH  = /home/u64124548/sasuser.v94/TLF - Creation/Input;
%let OUTPATH = /home/u64124548/sasuser.v94/TLF - Creation/Output;


proc printto
    log="&OUTPATH./Output_5.log"
    new;
run;


data _null_;
    file "&OUTPATH./Output_5_Path_Test.txt";
    put "The Output folder is writable.";
run;


libname xtte xport "&INPATH./ADTTE.xpt";

proc copy
    in=xtte
    out=work
    memtype=data;
run;

libname xtte clear;


proc contents data=work.adtte varnum;
run;


proc format;
    value trtf
        1 = "Placebo"
        2 = "CMP-135";
run;



data pfs_second;
    set work.adtte;

    where upcase(strip(ittfl))  = "Y"
      and upcase(strip(paramcd)) = "TTPFS"
      and remissn = 1;

    length treatment $20;

    if upcase(strip(trt01a)) = "PLACEBO" then do;
        trtn      = 1;
        treatment = "Placebo";
    end;

    else if upcase(strip(trt01a)) = "CMP-135" then do;
        trtn      = 2;
        treatment = "CMP-135";
    end;

    else delete;



    if cnsr < 0.5 then status = 0;
    else status = 1;
    format trtn trtf.;
run;


proc sort data=pfs_second;
    by trtn aval;
run;



title "Diagnostic: Second-Remission PFS Population";

proc freq data=pfs_second;
    tables trtn*status / missing;
    format trtn trtf.;
run;

proc print data=pfs_second(obs=20) noobs;
    var usubjid
        trtn
        trt01a
        remissn
        paramcd
        aval
        cnsr
        status
        evntdesc;

    format trtn trtf.;
run;

title;


proc sql noprint;

    select count(distinct usubjid)
    into :n_placebo trimmed
    from pfs_second
    where trtn = 1;

    select count(distinct usubjid)
    into :n_cmp trimmed
    from pfs_second
    where trtn = 2;

quit;

%put NOTE: Placebo denominator = &n_placebo;
%put NOTE: CMP-135 denominator = &n_cmp;


ods exclude all;

ods output Quartiles=quart_placebo;

proc lifetest data=pfs_second
              method=km
              alpha=0.05
              notable;

    where trtn = 1;

    time aval*status(1);
run;

ods exclude none;


ods exclude all;

ods output Quartiles=quart_cmp;

proc lifetest data=pfs_second
              method=km
              alpha=0.05
              notable;

    where trtn = 2;

    time aval*status(1);
run;

ods exclude none;


%let median_placebo = NE;
%let median_cmp     = NE;


data _null_;
    set quart_placebo;

    percentile = input(vvaluex("PERCENT"), best.);
    estimate   = input(vvaluex("ESTIMATE"), best.);

    if percentile = 50 then do;

        if missing(estimate) then
            call symputx("median_placebo", "NE");

        else
            call symputx(
                "median_placebo",
                strip(put(estimate, 6.1))
            );

    end;
run;


data _null_;
    set quart_cmp;

    percentile = input(vvaluex("PERCENT"), best.);
    estimate   = input(vvaluex("ESTIMATE"), best.);

    if percentile = 50 then do;

        if missing(estimate) then
            call symputx("median_cmp", "NE");

        else
            call symputx(
                "median_cmp",
                strip(put(estimate, 6.1))
            );

    end;
run;

%put NOTE: Placebo median PFS = &median_placebo;
%put NOTE: CMP-135 median PFS = &median_cmp;


ods exclude all;

ods output HazardRatios=hazard_ratio_output;

proc phreg data=pfs_second;

    class trtn(ref="1") / param=ref;

    model aval*status(1) = trtn
        / risklimits;

    hazardratio trtn / diff=ref;

    format trtn trtf.;
run;

ods exclude none;


%let hazard_ratio = NE;
%let hazard_lcl   = NE;
%let hazard_ucl   = NE;


data _null_;
    set hazard_ratio_output;

    hr  = input(vvaluex("HAZARDRATIO"), best.);
    lcl = input(vvaluex("HRLOWERCL"), best.);
    ucl = input(vvaluex("HRUPPERCL"), best.);

    if not missing(hr) then
        call symputx(
            "hazard_ratio",
            strip(put(hr, 6.3))
        );

    if not missing(lcl) then
        call symputx(
            "hazard_lcl",
            strip(put(lcl, 6.3))
        );

    if not missing(ucl) then
        call symputx(
            "hazard_ucl",
            strip(put(ucl, 6.3))
        );
run;

%put NOTE: Hazard ratio = &hazard_ratio;
%put NOTE: Hazard-ratio 95% CI = (&hazard_lcl, &hazard_ucl);


ods exclude all;

ods output HomTests=homogeneity_tests;

proc lifetest data=pfs_second
              method=km
              notable;

    time aval*status(1);

    strata trtn / test=logrank;

    format trtn trtf.;
run;

ods exclude none;


%let logrank_p = NE;

data _null_;
    set homogeneity_tests;

    length test_name $100;

    test_name = upcase(vvaluex("TEST"));

    if index(test_name, "LOG") > 0 then do;

        pvalue = input(vvaluex("PROBCHISQ"), best.);

        if missing(pvalue) then
            pvalue = input(vvaluex("PVALUE"), best.);

        if not missing(pvalue) then do;

            if pvalue < 0.0001 then
                call symputx("logrank_p", "<0.0001");

            else
                call symputx(
                    "logrank_p",
                    strip(put(pvalue, 6.4))
                );

        end;

    end;
run;

%put NOTE: Log-rank p-value = &logrank_p;


ods _all_ close;



ods html5
    path="&OUTPATH"
    gpath="&OUTPATH"
    file="Output_5.html"
    style=htmlblue
    options(bitmap_mode="separate");


ods graphics /
    reset=all
    reset=index
    width=9.2in
    height=5.7in
    imagename="Output_5"
    imagefmt=png
    border=off;


title1 j=c height=9pt
    "Figures 14.2.1/2";

title2 j=c height=9pt
    "Kaplan Meier Curves for Progression Free Survival by Treatment Arm in Second Remission";

title3 j=c height=9pt
    "Randomized Subjects with 2nd Remission";



proc lifetest data=pfs_second
              method=km

              plots=survival(
                  atrisk=0 to 15 by 3
                  outside
              );

    time aval*status(1);

    strata trtn / test=logrank;

    format trtn trtf.;
run;


ods html5 text=
"<p style='font-family:Arial; font-size:9pt;'>
Median Time (months):
Placebo=&median_placebo;
CMP-135=&median_cmp
</p>";

ods html5 text=
"<p style='font-family:Arial; font-size:9pt;'>
Hazard Ratio=&hazard_ratio;
95% CI=(&hazard_lcl, &hazard_ucl)
</p>";

ods html5 text=
"<p style='font-family:Arial; font-size:9pt;'>
Log-rank p-value=&logrank_p
</p>";


ods html5 close;


ods graphics /
    reset=all
    reset=index
    width=9.2in
    height=5.7in
    imagename="Output_5"
    imagefmt=png
    border=off;


ods rtf
    file="&OUTPATH./Output_5.rtf"
    style=journal
    bodytitle;


title1 j=c height=9pt
    "Figures 14.2.1/2";

title2 j=c height=9pt
    "Kaplan Meier Curves for Progression Free Survival by Treatment Arm in Second Remission";

title3 j=c height=9pt
    "Randomized Subjects with 2nd Remission";


/* footnote1 j=l height=7pt */
/*     "Study PRJ5457C" */
/*     j=r */
/*     "Page 69 of 80"; */
/*  */
/* footnote2 j=l height=7pt */
/*     "TLG Specifications, Version v1.0" */
/*     j=r */
/*     "Date: %sysfunc(today(),date9.)"; */


proc lifetest data=pfs_second
              method=km

              plots=survival(
                  atrisk=0 to 15 by 3
                  outside
              );

    time aval*status(1);

    strata trtn / test=logrank;

    format trtn trtf.;
run;


ods rtf text=
"^S={
    font_face='Arial'
    font_size=8pt
    just=left
}
Median Time (months): Placebo=&median_placebo; CMP-135=&median_cmp";


ods rtf text=
"^S={
    font_face='Arial'
    font_size=8pt
    just=left
}
Hazard Ratio=&hazard_ratio; 95% CI=(&hazard_lcl, &hazard_ucl)";


ods rtf text=
"^S={
    font_face='Arial'
    font_size=8pt
    just=left
}
Log-rank p-value=&logrank_p";


ods rtf close;


ods html5;

title;
footnote;


proc printto;
run;