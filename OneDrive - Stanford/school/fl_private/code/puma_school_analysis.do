clear
set more off
cd "$florida/data"
use school_count_final, clear

keep if distance == 5

* give clean labels
label var avg_income   "Average income"
label var black_share  "Percent Black"
label var hisp_share   "Percent Hispanic"
label var avg_age      "Average age"
label var hs_grad      "HS graduate share"
label var less_hs      "Less than HS"
label var some_college "Some college"
label var college_plus "College+"

label var total_school      "Total schools"
label var non_relig         "Non-religious schools"
label var relig             "Religious schools"
label var distinct_fine     "Distinct types (fine)"
label var distinct_collapsed "Distinct types (collapsed)"

summarize avg_income hisp_share black_share white_share avg_age ///
                           less_hs hs_grad some_college college_plus ///
				 total_school relig non_relig distinct_fine distinct_collapsed 

outreg2 using summary_stats.doc, sum(log) replace
* loop over exposures
foreach exp in total_school non_relig relig distinct_fine distinct_collapsed {
    eststo clear
    eststo: reg avg_income   `exp'
    eststo: reg black_share  `exp'
    eststo: reg hisp_share   `exp'
    eststo: reg avg_age      `exp'
    eststo: reg hs_grad      `exp'
    eststo: reg less_hs      `exp'
    eststo: reg some_college `exp'
    eststo: reg college_plus `exp'

    * export each exposure's table separately
    esttab using "$florida/output/charts/reg_`exp'.tex", replace ///
        se r2 ar2 label style(tex) ///
        title("Regression Results using `exp'")
}


reg avg_income total_school avg_age hs_grad white_share hisp_share black_share



