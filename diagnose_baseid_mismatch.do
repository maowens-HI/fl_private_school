/*==============================================================================
Project    : Florida Private School Exposure Analysis
File       : diagnose_baseid_mismatch.do
Purpose    : Diagnose why baseids don't match between crosswalk and school counts
Author     : Myles Owens
Date       : 2025-12-11
==============================================================================*/

clear all
set more off
cd "$florida/data"

*** ---------------------------------------------------------------------------
*** Check baseid format in school counts file
*** ---------------------------------------------------------------------------

di ""
di "=========================================="
di "SCHOOL COUNTS FILE (from shapefile STFID)"
di "=========================================="

use block_school_counts_all_1990.dta, clear

* Get unique baseids
egen tag = tag(baseid)
keep if tag
keep baseid

di "Number of unique blocks: " _N
di "Sample baseids from school counts file:"
list baseid in 1/20

* Check baseid characteristics
gen len = length(baseid)
tab len
di "Baseids with length != 15: "
count if len != 15

tempfile school_ids
save `school_ids'

*** ---------------------------------------------------------------------------
*** Check baseid format in crosswalk file
*** ---------------------------------------------------------------------------

di ""
di "=========================================="
di "CROSSWALK FILE (constructed from components)"
di "=========================================="

use blockxpuma_clean_1990.dta, clear

* Get unique baseids
egen tag = tag(baseid)
keep if tag
keep baseid county tract block4 tract6

di "Number of unique blocks: " _N
di "Sample baseids from crosswalk file:"
list baseid county tract block4 tract6 in 1/20

* Check baseid characteristics
gen len = length(baseid)
tab len
di "Baseids with length != 15: "
count if len != 15

tempfile crosswalk_ids
save `crosswalk_ids'

*** ---------------------------------------------------------------------------
*** Check for matches
*** ---------------------------------------------------------------------------

di ""
di "=========================================="
di "MATCHING TEST"
di "=========================================="

use `school_ids', clear
gen in_schools = 1

merge 1:1 baseid using `crosswalk_ids'

di "Merge results:"
tab _merge

di ""
di "Sample of matched baseids:"
list baseid if _merge == 3 in 1/10

di ""
di "Sample of school-only baseids (should match but don't):"
list baseid if _merge == 1 in 1/10

di ""
di "Sample of crosswalk-only baseids (should match but don't):"
list baseid if _merge == 2 in 1/10

*** ---------------------------------------------------------------------------
*** Check if it's a formatting issue
*** ---------------------------------------------------------------------------

di ""
di "=========================================="
di "CHECKING FOR FORMATTING DIFFERENCES"
di "=========================================="

* Extract first 5 chars (county) from both
use `school_ids', clear
gen county_from_schools = substr(baseid, 1, 5)
tab county_from_schools

use `crosswalk_ids', clear
gen county_from_crosswalk = substr(baseid, 1, 5)
tab county_from_crosswalk
