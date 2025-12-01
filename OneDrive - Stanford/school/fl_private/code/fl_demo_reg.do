
*House Keeping
clear 
set more off

cd "$florida\data"
use fl_demo.dta


*Florida Only
keep if statefip==12
keep if year == 2000 
keep if sample == 200001

tempfile merger
save `merger'
*save fl_demo_clean_2000, replace

/*
*Collapse into PUMA level measures use fl_demo_clean_2000 
* Turn HHINCOME (SUM) into and average 
preserve 
drop duplicates gen hh_income_wt = hhincome 
* hhwt 
collapse (sum) hh_income_wt (sum) hhwt, by(puma) gen avg_income = hh_income_wt / hhwt label variable avg_income "Average household income (weighted, 2000 PUMA)" tempfile puma_income save puma_income' 
restore
use 'puma_income' 
merge 1:m puma using fl_demo_clean_2000 
drop _merge 
save fl_demo_clean_2000, replace
*/
*Collapse into PUMA level measures: correct household income construction
use `merger', clear

preserve

* One record per household
keep year sample statefip serial gq puma hhincome hhwt
duplicates drop serial, force
drop if hhincome < 0 | hhincome == 9999999   // strip bad codes
* Weighted mean household income by PUMA
collapse (mean) avg_income = hhincome [pw=hhwt], by(puma)

    label variable avg_income "Average household income (HH-weighted, 2000 PUMA)"
    tempfile puma_income
    save `puma_income'
restore

* Merge back to person-level file
use `puma_income', clear
merge 1:m puma using `merger'
drop _merge
save `merger', replace


* race shares (percent Black, white, other)

preserve 
*weighted counts by race
gen pop_race=perwt
collapse (sum) pop_race, by(puma race)
bysort puma: egen total_puma = total(pop_race)

gen black_share =  100 * pop_race/ total_puma if race==2
gen white_share =  100 * pop_race/ total_puma if race==1
gen other_share =  100 * pop_race/ total_puma if race > 2

collapse (max) black_share white_share other_share, by(puma)

tempfile race_share
save `race_share'
restore

use `race_share'
merge 1:m puma using `merger'
drop _merge
save `merger', replace


*Hispanic
preserve
gen pop_hisp = perwt
collapse (sum) pop_hisp, by (puma hispan)
bysort puma: egen total_puma = total(pop_hisp)
gen hisp_share = 100 * pop_hisp/ total_puma if hispan != 0
collapse (max) hisp_share, by(puma)
tempfile hisp_share
save `hisp_share'
restore
clear
use `hisp_share'
merge 1:m puma using `merger'
drop _merge
save `merger', replace


* Educational attainment
preserve
gen less_hs      = inrange(educ,0,5)
gen hs_grad      = educ==6
gen some_college = inrange(educ,7,9)
gen college_plus = inrange(educ,10,11)

collapse (mean) less_hs hs_grad some_college college_plus [pw=perwt], by(puma)

label var less_hs      "% Less than HS"
label var hs_grad      "% HS graduate"
label var some_college "% Some college"
label var college_plus "% College or higher"

tempfile educ_share
save `educ_share'
restore

clear
use `educ_share'

merge 1:m puma using `merger'
drop _merge
save `merger', replace

* Turn Age into and average age
preserve
collapse (mean) avg_age=age [pw=perwt], by(puma)
label var avg_age "Average age (weighted, 2000 PUMA)"
tempfile avg_age
save `avg_age'
restore

clear
use `avg_age'
merge 1:m puma using `merger'
drop _merge
save `merger', replace
keep puma avg_age less_hs hs_grad some_college college_plus hisp_share black_share white_share other_share avg_income year sample 
gen str  puma5 = string(puma, "%05.0f")
duplicates drop puma5, force
save fl_puma2000_analysis.dta, replace

/*
/********************************************************************
*  Project   : Florida Private School Concentration
*  File      : fl_puma_analysis.do
*  Purpose   : Build 2000 PUMA-level characteristics and join to schools
*  Data In   : fl_demo.dta (IPUMS microdata, includes 2000 FL)
*  Data Out  : fl_puma2000_analysis.dta
*  Author    : Myles Owens
********************************************************************/

clear all
set more off

cd "$florida/data"

*** ------------------------------------------------------------------
*** 0) Load and filter once
*** ------------------------------------------------------------------
use fl_demo.dta, clear
keep if statefip == 12
keep if year == 2000
keep if sample == 200001

*** Keep only what we actually need downstream (lighter memory, faster)
keep puma perwt race hispan educ age hhincome hhwt serial year sample

*** ------------------------------------------------------------------
*** 1) Person-level PUMA stats in a single collapse
***    Shares are means of indicator vars with person weights.
*** ------------------------------------------------------------------
tempfile puma_person
preserve
    *** Race shares (Black/White/Other), Hispanic share, education shares, avg age
    gen is_black  = race == 2
    gen is_white  = race == 1
    gen is_other  = race >  2
    gen is_hisp   = hispan != 0

    gen less_hs      = inrange(educ,0,5)
    gen hs_grad      = educ == 6
    gen some_college = inrange(educ,7,9)
    gen college_plus = inrange(educ,10,11)

    collapse ///
        (mean) black_share = is_black ///
                white_share = is_white ///
                other_share = is_other ///
                hisp_share  = is_hisp  ///
                less_hs hs_grad some_college college_plus ///
                avg_age = age [pw=perwt], by(puma)

    *** Convert shares to percents if you insist on percent formatting
    foreach v in black_share white_share other_share hisp_share ///
                less_hs hs_grad some_college college_plus {
        replace `v' = 100*`v'
    }

    label var black_share   "% Black (person-weighted)"
    label var white_share   "% White (person-weighted)"
    label var other_share   "% Other race (person-weighted)"
    label var hisp_share    "% Hispanic (person-weighted)"
    label var less_hs       "% Less than HS (person-weighted)"
    label var hs_grad       "% HS graduate (person-weighted)"
    label var some_college  "% Some college (person-weighted)"
    label var college_plus  "% College+ (person-weighted)"
    label var avg_age       "Average age (person-weighted)"

    *** year/sample are constants; stamp them explicitly
    gen year   = 2000
    gen sample = 200001

    save `puma_person'
restore

*** ------------------------------------------------------------------
*** 2) Household income: compute at household level with HHWT, then PUMA
***    We don't average people's copies of household income. We average households.
*** ------------------------------------------------------------------
tempfile puma_hhinc
preserve
    keep puma hhincome hhwt serial
    keep if !missing(hhincome, hhwt, serial, puma)

    *** One obs per household (SERIAL identifies the household within year/sample)
    bys serial: keep if _n == 1

    gen hh_income_wt = hhincome * hhwt
    collapse (sum) hh_income_wt hhwt, by(puma)
    gen avg_income = hh_income_wt / hhwt
    label var avg_income "Average household income (HH-weighted, 2000 PUMA)"

    keep puma avg_income
    save `puma_hhinc'
restore

*** ------------------------------------------------------------------
*** 3) Merge the tidy pieces and write once
*** ------------------------------------------------------------------
use `puma_person', clear
merge 1:1 puma using `puma_hhinc', nogenerate

order puma year sample avg_income avg_age ///
      black_share white_share other_share hisp_share ///
      less_hs hs_grad some_college college_plus

gen str  puma5 = string(puma, "%05.0f")
save fl_puma2000_analysis.dta, replace
*/










/********************************************************************
*  Project   : Florida Private School Concentration
*  File      : fl_puma_analysis.do
*  Purpose   : Construct regional characteristics (2000, PUMA-level)
*              and regress them on private school exposure.
*
*  Data In   : ipums_2000_florida.dta   (IPUMS microdata, 2000 5% sample)
*              schools_puma2000.dta     (aggregated private school counts)
*
*  Data Out  : fl_puma2000_analysis.dta (PUMA-level characteristics + schools)
*
*  Author    : Myles Owens
********************************************************************/

