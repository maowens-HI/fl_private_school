/*==============================================================================
Project    : Florida Private School Exposure Analysis
File       : check_obs_difference.do
Purpose    : Investigate observation count differences between 1990 and 2000
Author     : Myles Owens
Institution: Hoover Institution, Stanford University
Date       : 2025-12-11
==============================================================================*/

clear all
set more off
cd "$florida/data"

*** ---------------------------------------------------------------------------
*** Check 2000 dataset structure
*** ---------------------------------------------------------------------------

use block_school_counts_all.dta, clear

di ""
di "============================================"
di "2000 Census Blocks Dataset"
di "============================================"
di "Total observations: " _N

* Check distance buffers
quietly tab distance
di "Number of distance buffers: " r(r)
tab distance

* Count unique blocks
quietly: egen tag_block = tag(baseid)
quietly: count if tag_block
local blocks_2000 = r(N)
di "Unique blocks: " `blocks_2000'

* Calculate expected observations
quietly tab distance
local distances = r(r)
di "Expected obs (blocks × distances): " `blocks_2000' * `distances'

*** ---------------------------------------------------------------------------
*** Check 1990 dataset structure
*** ---------------------------------------------------------------------------

use block_school_counts_all_1990.dta, clear

di ""
di "============================================"
di "1990 Census Blocks Dataset"
di "============================================"
di "Total observations: " _N

* Check distance buffers
quietly tab distance
di "Number of distance buffers: " r(r)
tab distance

* Count unique blocks
quietly: egen tag_block = tag(baseid)
quietly: count if tag_block
local blocks_1990 = r(N)
di "Unique blocks: " `blocks_1990'

* Calculate expected observations
quietly tab distance
local distances = r(r)
di "Expected obs (blocks × distances): " `blocks_1990' * `distances'

*** ---------------------------------------------------------------------------
*** Compare
*** ---------------------------------------------------------------------------

di ""
di "============================================"
di "Comparison"
di "============================================"
di "Difference in observations: " 10874970 - 9442860
di "Difference in unique blocks: " `blocks_2000' - `blocks_1990'
di "Percent increase in blocks: " string(100 * (`blocks_2000' - `blocks_1990') / `blocks_1990', "%5.2f") "%"

*** ---------------------------------------------------------------------------
*** Check if certain areas have more blocks in 2000
*** ---------------------------------------------------------------------------

* Extract county from baseid (first 5 characters)
use block_school_counts_all.dta, clear
gen county = substr(baseid, 1, 5)
egen tag_block = tag(baseid)
preserve
    keep if tag_block
    collapse (count) blocks_2000 = baseid, by(county)
    tempfile c2000
    save `c2000'
restore

use block_school_counts_all_1990.dta, clear
gen county = substr(baseid, 1, 5)
egen tag_block = tag(baseid)
preserve
    keep if tag_block
    collapse (count) blocks_1990 = baseid, by(county)

    merge 1:1 county using `c2000'
    gen block_change = blocks_2000 - blocks_1990
    gen pct_change = 100 * block_change / blocks_1990

    di ""
    di "============================================"
    di "Block Changes by County (Top 10 changes)"
    di "============================================"

    gsort -block_change
    list county blocks_1990 blocks_2000 block_change pct_change in 1/10, noobs
restore
