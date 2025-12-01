/*==============================================================================
Project    : Florida Private School Exposure Analysis
File       : puma_school_analysis.do
Purpose    : Analyze relationship between demographics and private school access
Author     : Myles Owens
Institution: Hoover Institution, Stanford University
Date       : 2025-12-01
───────────────────────────────────────────────────────────────────────────────
Description:
    This script performs bivariate regression analysis examining the
    relationship between PUMA-level demographic characteristics and private
    school exposure measures. For each school exposure measure (total schools,
    religious schools, non-religious schools, school diversity), it runs
    separate regressions with each demographic variable to identify
    correlations between community characteristics and school access.

Inputs:
    - school_count_final.dta    Final merged dataset with demographics + schools

Outputs:
    - summary_stats.doc              Summary statistics for all variables
    - reg_total_school.tex           Regression results using total schools
    - reg_non_relig.tex              Regression results using non-religious schools
    - reg_relig.tex                  Regression results using religious schools
    - reg_distinct_fine.tex          Regression results using fine school diversity
    - reg_distinct_collapsed.tex     Regression results using collapsed school diversity

Analysis Specifications:
    - Distance Buffer: 5 miles (filters distance == 5)
    - Model Type: Bivariate OLS regression (Y ~ X, no controls)
    - Standard Errors: Default (non-robust)

    For each school exposure measure, run:
        demographic_variable = β₀ + β₁ × school_exposure + ε

    Where demographic_variable ∈ {avg_income, black_share, hisp_share,
                                    avg_age, hs_grad, less_hs,
                                    some_college, college_plus}

    And school_exposure ∈ {total_school, non_relig, relig,
                            distinct_fine, distinct_collapsed}

Interpretation:
    - Positive β₁: Higher school exposure associated with higher demographic value
    - Negative β₁: Higher school exposure associated with lower demographic value
    - Example: β₁ > 0 in (avg_income ~ total_school) means wealthier areas
               have more private schools

Notes:
    - Analysis focuses on 5-mile distance buffer (typical commuting distance)
    - Bivariate models identify correlations, not causal effects
    - Results tables exported in LaTeX format for publication
    - Final regression includes multiple controls for comparison
==============================================================================*/

clear all
set more off
cd "$florida/data"

*** ---------------------------------------------------------------------------
*** Section 1: Load Data and Apply Distance Filter
*** ---------------------------------------------------------------------------

* Load final merged dataset with demographics and school exposure
use school_count_final, clear

* Filter to 5-mile distance buffer (most relevant for school access)
* This buffer represents a reasonable driving distance for private school choice
keep if distance == 5

*** ---------------------------------------------------------------------------
*** Section 2: Apply Variable Labels
*** ---------------------------------------------------------------------------

* Apply descriptive labels for tables and output
* Demographic variables
label var avg_income   "Average income"
label var black_share  "Percent Black"
label var hisp_share   "Percent Hispanic"
label var avg_age      "Average age"
label var hs_grad      "HS graduate share"
label var less_hs      "Less than HS"
label var some_college "Some college"
label var college_plus "College+"

* School exposure variables
label var total_school       "Total schools"
label var non_relig          "Non-religious schools"
label var relig              "Religious schools"
label var distinct_fine      "Distinct types (fine)"
label var distinct_collapsed "Distinct types (collapsed)"

*** ---------------------------------------------------------------------------
*** Section 3: Summary Statistics
*** ---------------------------------------------------------------------------

* Generate summary statistics for all key variables
* This provides descriptive overview of the data before regression analysis
summarize avg_income hisp_share black_share white_share avg_age ///
         less_hs hs_grad some_college college_plus ///
         total_school relig non_relig distinct_fine distinct_collapsed

* Export summary statistics to Word document
outreg2 using summary_stats.doc, sum(log) replace

*** ---------------------------------------------------------------------------
*** Section 4: Bivariate Regression Analysis
*** ---------------------------------------------------------------------------

* For each school exposure measure, run bivariate regressions with all
* demographic variables. This identifies which demographics are correlated
* with private school access.

* Loop over each school exposure measure
foreach exp in total_school non_relig relig distinct_fine distinct_collapsed {

    * Clear stored estimates from previous iteration
    eststo clear

    * Run bivariate regressions: each demographic ~ school exposure
    * Specification: demographic_i = β₀ + β₁ × school_exposure + ε

    eststo: reg avg_income   `exp'    // Income and school access
    eststo: reg black_share  `exp'    // Race and school access
    eststo: reg hisp_share   `exp'    // Ethnicity and school access
    eststo: reg avg_age      `exp'    // Age and school access
    eststo: reg hs_grad      `exp'    // High school education and school access
    eststo: reg less_hs      `exp'    // Less than HS and school access
    eststo: reg some_college `exp'    // Some college and school access
    eststo: reg college_plus `exp'    // College education and school access

    * Export regression results to LaTeX table
    * se: Include standard errors
    * r2: Include R-squared
    * ar2: Include adjusted R-squared
    * label: Use variable labels in output
    * style(tex): Format for LaTeX
    esttab using "$florida/output/charts/reg_`exp'.tex", replace ///
        se r2 ar2 label style(tex) ///
        title("Regression Results using `exp'")
}

*** ---------------------------------------------------------------------------
*** Section 5: Multivariate Regression (Example)
*** ---------------------------------------------------------------------------

* Run one multivariate regression as an example of controlling for confounders
* This shows how results might differ when accounting for multiple factors
* simultaneously

* Specification: avg_income = β₀ + β₁×total_school + β₂×avg_age +
*                            β₃×hs_grad + β₄×white_share + β₅×hisp_share +
*                            β₆×black_share + ε

reg avg_income total_school avg_age hs_grad white_share hisp_share black_share

*** ---------------------------------------------------------------------------
*** End of Script
*** ---------------------------------------------------------------------------
