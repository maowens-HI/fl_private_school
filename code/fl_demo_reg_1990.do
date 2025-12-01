/*==============================================================================
Project    : Florida Private School Exposure Analysis
File       : fl_demo_reg_1990.do
Purpose    : Construct PUMA-level demographic measures from IPUMS microdata (1990)
Author     : Myles Owens
Institution: Hoover Institution, Stanford University
Date       : 2025-12-01
───────────────────────────────────────────────────────────────────────────────
Description:
    This script builds year 1990 PUMA-level demographic characteristics from
    IPUMS USA Census microdata for Florida. It constructs both person-level
    measures (race, ethnicity, education, age) and household-level measures
    (income), properly weighting each by their respective sampling weights.

Inputs:
    - fl_demo.dta                 IPUMS USA microdata (includes 1990 Florida)

Outputs:
    - fl_puma1990_analysis.dta    PUMA-level demographic characteristics

Key Variables Created:
    - avg_income      Average household income (household-weighted)
    - black_share     Percent Black population (person-weighted)
    - white_share     Percent White population (person-weighted)
    - other_share     Percent Other race population (person-weighted)
    - hisp_share      Percent Hispanic population (person-weighted)
    - less_hs         Percent with less than high school (person-weighted)
    - hs_grad         Percent with high school diploma (person-weighted)
    - some_college    Percent with some college (person-weighted)
    - college_plus    Percent with college degree or higher (person-weighted)
    - avg_age         Average age (person-weighted)

Notes:
    - Uses year 1990 Census 5% sample (sample == 199001)
    - Florida only (statefip == 12)
    - Household income uses ONE record per household (serial) with hhwt weights
    - Person characteristics use person-level data with perwt weights
    - All share variables expressed as percentages (0-100 scale)
    - Bad income codes (< 0 or 9999999) are dropped
==============================================================================*/

clear all
set more off

*** ---------------------------------------------------------------------------
*** Section 1: Load IPUMS Data and Apply Filters
*** ---------------------------------------------------------------------------

cd "$florida\data"
use fl_demo.dta, clear

* Filter to Florida, year 1990, 5% sample only
keep if statefip == 12        // Florida FIPS code
keep if year == 1990          // Census 1990
keep if sample == 199001      // 1990 5% sample

* Save filtered base file for merging demographic measures
tempfile merger
save `merger'

*** ---------------------------------------------------------------------------
*** Section 2: Household Income (Household-Weighted)
*** ---------------------------------------------------------------------------

* Household income must be computed at the HOUSEHOLD level using hhwt,
* not person level. We keep one record per household (identified by serial).

use `merger', clear

preserve
    * Keep only household-level variables
    keep year sample statefip serial gq puma hhincome hhwt

    * One record per household (serial = unique household ID within year/sample)
    duplicates drop serial, force

    * Drop invalid income codes
    drop if hhincome < 0 | hhincome == 9999999

    * Compute weighted mean household income by PUMA
    collapse (mean) avg_income = hhincome [pw=hhwt], by(puma)

    label variable avg_income "Average household income (HH-weighted, 1990 PUMA)"

    tempfile puma_income
    save `puma_income'
restore

* Merge household income back to person-level base file
use `puma_income', clear
merge 1:m puma using `merger'
drop _merge
save `merger', replace

*** ---------------------------------------------------------------------------
*** Section 3: Race Shares (Person-Weighted)
*** ---------------------------------------------------------------------------

* Compute percentage of population by race category within each PUMA
* Uses person weights (perwt) since this is a person-level characteristic

preserve
    * Sum person weights by race within each PUMA
    gen pop_race = perwt
    collapse (sum) pop_race, by(puma race)

    * Calculate total population in each PUMA (sum across all races)
    bysort puma: egen total_puma = total(pop_race)

    * Compute race shares as percentages
    gen black_share = 100 * pop_race / total_puma if race == 2
    gen white_share = 100 * pop_race / total_puma if race == 1
    gen other_share = 100 * pop_race / total_puma if race > 2

    * Collapse to one observation per PUMA (keeping the non-missing shares)
    collapse (max) black_share white_share other_share, by(puma)

    tempfile race_share
    save `race_share'
restore

* Merge race shares back to base file
use `race_share', clear
merge 1:m puma using `merger'
drop _merge
save `merger', replace

*** ---------------------------------------------------------------------------
*** Section 4: Hispanic Share (Person-Weighted)
*** ---------------------------------------------------------------------------

* Compute percentage Hispanic within each PUMA
* Hispanic ethnicity is separate from race in Census classification

preserve
    gen pop_hisp = perwt
    collapse (sum) pop_hisp, by(puma hispan)

    * Calculate total population in each PUMA
    bysort puma: egen total_puma = total(pop_hisp)

    * Compute Hispanic share (hispan != 0 indicates Hispanic origin)
    gen hisp_share = 100 * pop_hisp / total_puma if hispan != 0

    * Collapse to one observation per PUMA
    collapse (max) hisp_share, by(puma)

    tempfile hisp_share
    save `hisp_share'
restore

* Merge Hispanic share back to base file
clear
use `hisp_share', clear
merge 1:m puma using `merger'
drop _merge
save `merger', replace

*** ---------------------------------------------------------------------------
*** Section 5: Educational Attainment (Person-Weighted)
*** ---------------------------------------------------------------------------

* Create educational attainment categories based on IPUMS educ codes:
* 0-5: Less than high school
* 6: High school graduate
* 7-9: Some college (including Associate's degree)
* 10-11: Bachelor's degree or higher

preserve
    * Create indicator variables for each education category
    gen less_hs      = inrange(educ, 0, 5)
    gen hs_grad      = educ == 6
    gen some_college = inrange(educ, 7, 9)
    gen college_plus = inrange(educ, 10, 11)

    * Compute weighted mean shares by PUMA (automatically gives percentages as 0-1)
    collapse (mean) less_hs hs_grad some_college college_plus [pw=perwt], by(puma)

    * Convert to percentages (0-100 scale) - currently done in final step below
    * Note: These are already weighted means, so they represent population shares

    label var less_hs      "% Less than HS"
    label var hs_grad      "% HS graduate"
    label var some_college "% Some college"
    label var college_plus "% College or higher"

    tempfile educ_share
    save `educ_share'
restore

* Merge education shares back to base file
clear
use `educ_share', clear
merge 1:m puma using `merger'
drop _merge
save `merger', replace

*** ---------------------------------------------------------------------------
*** Section 6: Average Age (Person-Weighted)
*** ---------------------------------------------------------------------------

* Compute mean age within each PUMA using person weights

preserve
    collapse (mean) avg_age = age [pw=perwt], by(puma)

    label var avg_age "Average age (weighted, 1990 PUMA)"

    tempfile avg_age
    save `avg_age'
restore

* Merge average age back to base file
clear
use `avg_age', clear
merge 1:m puma using `merger'
drop _merge
save `merger', replace

*** ---------------------------------------------------------------------------
*** Section 7: Final Cleanup and Export
*** ---------------------------------------------------------------------------

* Keep only the PUMA-level summary variables (one record per PUMA)
keep puma avg_age less_hs hs_grad some_college college_plus ///
     hisp_share black_share white_share other_share avg_income year sample

* Create 5-character string version of PUMA for merging with geographic data
gen str puma5 = string(puma, "%05.0f")

* Remove duplicate PUMA records (we now have PUMA-level summaries only)
duplicates drop puma5, force

* Save final PUMA-level demographic dataset
save fl_puma1990_analysis.dta, replace

*** ---------------------------------------------------------------------------
*** End of Script
*** ---------------------------------------------------------------------------
