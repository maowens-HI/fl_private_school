/*
clear
set more off
cd "$florida/data"
* --- High schools ---
use block_school_counts_all_high, clear
gen level = "high"

* --- Append middle schools ---
append using block_school_counts_all_middle
replace level = "middle" if missing(level)

* --- Append elementary schools ---
append using block_school_counts_all_elem
replace level = "elem" if missing(level)

* --- Save combined file ---
gen block = substr(baseid, 12, 4)
destring block, replace
save block_school_counts_all, replace
*/

use block_school_counts_all,clear


import delimited using "geocorr2000_pxb2.csv", clear varnames(1)
drop in 1
* Make sure county and block are numeric, but KEEP tract as string
destring county block, replace force


* split tract into whole and fractional parts
gen str tract_whole = substr(tract, 1, strpos(tract,".")-1) if strpos(tract,".")>0
replace tract_whole = tract if missing(tract_whole)

gen str tract_frac = substr(tract, strpos(tract,".")+1, .) if strpos(tract,".")>0

* pad whole and fraction parts
gen str tract_whole4 = string(real(tract_whole), "%04.0f")
gen str tract_frac2  = cond(missing(tract_frac), "00", string(real(tract_frac), "%02.0f"))

* combine
gen str tract6 = tract_whole4 + tract_frac2

gen str block4 = string(block, "%04.0f")

gen str baseid = string(county, "%05.0f") + tract6 + block4


count if length(baseid) != 15
list county tract block baseid in 1/10

		   
save blockxpuma_clean.dta, replace


*merge 
use blockxpuma_clean, clear
rename block block_id
merge m:m baseid using block_school_counts_all
tab _merge
drop _merge
collapse (mean) total_school non_relig relig distinct_fine distinct_collapsed, ///
    by(puma5 distance)
save pumaxblock_school_all, replace


*merge 2
use  fl_puma2000_analysis.dta, clear

merge 1:m puma5 using pumaxblock_school_all
tab _merge
drop _merge


save school_count_final, replace