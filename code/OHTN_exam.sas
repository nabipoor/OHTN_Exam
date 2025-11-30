consistent
/* Import adherence and clinical visits*/
PROC IMPORT DATAFILE='/home/u61968265/adherence_social.xlsx' 
	DBMS=XLSX
	OUT=WORK.adhere;
	GETNAMES=YES;
RUN;

PROC IMPORT DATAFILE='/home/u61968265/clinical_visits.xlsx' 
	DBMS=XLSX
	OUT=WORK.clinic;
	GETNAMES=YES;
RUN;

PROC CONTENTS DATA=WORK.adhere; RUN;
PROC CONTENTS DATA=WORK.adhere; RUN;


libname mj '/home/u61968265';

/* Link adherence and clinical visits bu ID and visit date */
proc sql;
create table mj.cohort as
select a.*, b.*
from adhere a left join clinic b
on a.id=b.id and a.visit_date=b.visit_date;
quit;

proc contents data= mj.cohort; run;

/* convert character date into date9. format */
data mj.cohort1;
set mj.cohort;
format vis_dat date9.;
vis_dat = input(visit_date, yymmdd10.);
drop visit_date;
run;

/* check duplicates */
proc sql;
create table duplicates as
select * 
from mj.cohort1
group by ID, vis_dat
having count(*) > 1
order by id, vis_dat;
quit;
/* There is no duplicates */

/* check missing values */
proc means data=mj.cohort1 n nmiss; run;
/* There is one missing value in each columns of art_adherence_percent and viral_load */

/* impute missings by MICE or conditional chains */
proc mi data=mj.cohort1 out=mj.cohort_imputed seed=12345 nimpute=1;
class housing_stability;
fcs;
var art_adherence_percent housing_stability viral_load cd4_count age;
run;
/* 2 missing values are imputed */

/* ordering data by ID vis_dat*/
proc sql;
create table mj.cohort2 as 
select * 
from mj.cohort_imputed
order by id, vis_dat desc;
quit;


/* check for logical consistency */
proc freq data=mj.cohort2;
table housing_stability art_status;
run;
/* the categorical data both have two categories and are correct */

proc means data=mj.cohort2 min max;
var art_adherence_percent hiv_stigma_score age viral_load cd4_count;
run;
/* art_adherence_percent 44.69%-95%  hiv_stigma_score 18-48 age 36-52 viral_load imputed value out of range cd4_count 180-480 */
/* imputed value for viral_load is a large outlier*/

proc means data=mj.cohort2;
var viral_load;
run;
/* the imputed value is 794000 < 1000,000 then we accept it, 
and this value is large because the patient has a rare situation unstable housing not in art low cd4 counts and ... */

/* age increases over time for each person */
data age_check;
    set mj.cohort2;
    by id;

    retain prev_age;
    if first.id then prev_age = age;
    else do;
        if age > prev_age then flag_age_decrease = 1;
        prev_age = age;
    end;
    if flag_age_decrease = 1;
    keep id vis_dat age flag_age_decrease;
run;
/* all age are correct later dates of one person has larger age */

/* cd4 counts and viral loads have negative correlat */
proc corr data=mj.cohort2 plots=matrix;
    var cd4_count viral_load;
run;
/* corr ~ -0.3 low they are negatively correlated, but the matrix shows a large interruption in imputed value for viral_load */
/*replace the imputed value with 100000 */
data mj.cohort3;
set mj.cohort2;
if viral_load > 100000 then viral_load=100000;
run;

/* check correlation again */
proc corr data=mj.cohort3 plots=matrix;
    var cd4_count viral_load;
run;
/* yep! correlation improved */


/* ART_Status vs Viral_Load: Patients on ART should generally have lower viral load */
proc means data=mj.cohort3;
class art_status;
var viral_load;
run;

/* data are cosnsistent and in the range */


/* write a SAS macro that takes a dataset and returns the number of rows and columns */

%macro nrow_ncol(data = );
%local ds nobs nvars rc;

%let ds = %sysfunc(open(&data));
%if &ds = 0 %then %do;
   %put Error: dataset cannot be opened.;
   %let nrow = 0;
   %let ncol = 0;
   %return;
%end

%let nobs = %sysfunc(attrn(&ds, nobs));
%let nvars = %sysfunc(attrn(&ds, nvars));

/* assign global values */
%let nrows = &nobs;
%let ncols = &nvars;

%if &nobs = 0 %then %do;
  %put Warning: Dataset is empty;
%end;

%let rc = %sysfunc(close(&ds));

/* If NOBS missing, force SAS to count rows */
%if %superq(nobs) = %then %do;
        data _null_;
            if 0 then set &data nobs=_n;
            call symputx('nobs', _n);
            stop;
        run;
%end;

%put Dataset: &data;
%put Number of observations: &nobs;
%put Number of variables: &nvars;

%mend nrow_ncol;

%nrow_ncol(data = mj.cohort3)




























