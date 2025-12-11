/*==============================================================================
Project    : Florida Private School Exposure Analysis
File       : blockxpuma.do
Purpose    : Link block-level school counts to PUMAs via geographic crosswalk
Author     : Myles Owens
Institution: Hoover Institution, Stanford University
Date       : 2025-12-01
───────────────────────────────────────────────────────────────────────────────
Description:
    This script links Census block-level private school counts to PUMA-level
    demographics. It processes a PUMA × Block geographic crosswalk file,
    constructs standardized 15-character block IDs (baseid), merges with
    school exposure data, and aggregates school counts to the PUMA level.
    Finally, it merges PUMA demographics with PUMA-level school exposure
    measures to create the final analysis dataset.

Inputs:
    - geocorr2000_pxb2.csv           Geographic crosswalk (PUMA × Block)
    - block_school_counts_all.dta    Block-level private school counts
    - fl_puma2000_analysis.dta       PUMA-level demographic characteristics

Outputs:
    - blockxpuma_clean.dta           Cleaned geographic crosswalk with baseid
    - pumaxblock_school_all.dta      PUMA-level school counts (aggregated)
    - school_count_final.dta         Final merged dataset (demographics + schools)

Geographic ID Construction:
    baseid = 15-character Census block identifier
           = county (5 digits) + tract (6 digits) + block (4 digits)

    Example: county=12011, tract=9841.01, block=1 → baseid="120110984101001"

    Tract parsing handles decimal notation:
    - "9841.01" → whole="9841", frac="01" → tract6="984101"
    - "9841" → whole="9841", frac="" → tract6="984100"

Key Variables:
    - baseid              15-character block identifier (county+tract+block)
    - puma5               5-character PUMA identifier (string, zero-padded)
    - total_school        Total private schools within distance buffer
    - relig               Religious private schools count
    - non_relig           Non-religious private schools count
    - distinct_fine       Number of distinct school types (fine classification)
    - distinct_collapsed  Number of distinct school types (coarse classification)
    - distance            Distance buffer radius (in miles)

Notes:
    - Multiple distance buffers exist in the data (1, 3, 5, 10 miles)
    - School counts are averaged across blocks within each PUMA
    - Final dataset is PUMA × distance, with one record per PUMA-distance pair
    - Merge diagnostics (_merge) are checked but not saved in final data
==============================================================================*/

clear all
set more off
cd "$florida/data"

*** ---------------------------------------------------------------------------
*** Section 1: Load and Parse Geographic Crosswalk
*** ---------------------------------------------------------------------------

* Load PUMA × Block crosswalk from MCDC Geocorr 2000
import delimited using "geocorr2000_pxb2.csv", clear varnames(1)
drop in 1  // Drop first data row if it contains formatting info

* FILTER TO FLORIDA ONLY (state FIPS = 12)
* Florida counties range from 12001 to 12139
keep if county >= 12001 & county <= 12999

* Convert county and block to numeric; keep tract as STRING (contains decimals)
destring county block, replace force

* Drop observations with missing blocks (data quality issue)
drop if missing(block)

* Parse tract into whole and fractional parts
* Some tracts are like "9841.01" (need to split), others are "9841" (no decimal)

* Extract whole number part (everything before the decimal point)
gen str tract_whole = substr(tract, 1, strpos(tract, ".") - 1) if strpos(tract, ".") > 0
replace tract_whole = tract if missing(tract_whole)  // If no decimal, use entire tract

* Extract fractional part (everything after the decimal point)
gen str tract_frac = substr(tract, strpos(tract, ".") + 1, .) if strpos(tract, ".") > 0

* Pad tract components to standard widths
gen str tract_whole4 = string(real(tract_whole), "%04.0f")  // 4 digits for whole part
gen str tract_frac2  = cond(missing(tract_frac), "00", string(real(tract_frac), "%02.0f"))  // 2 digits for fraction

* Combine into 6-character tract code
gen str tract6 = tract_whole4 + tract_frac2

* Create 4-character padded block code
gen str block4 = string(block, "%04.0f")

* Construct 15-character baseid: county (5) + tract (6) + block (4)
gen str baseid = string(county, "%05.0f") + tract6 + block4

* Verify all baseids have correct length (should all be 15 characters)
count if length(baseid) != 15
if r(N) > 0 {
    display as error "WARNING: " r(N) " observations have baseid != 15 characters"
    list county tract block baseid if length(baseid) != 15 & _n <= 10
}

* Display sample of constructed IDs for verification
list county tract block baseid in 1/10

* Save cleaned crosswalk
save blockxpuma_clean.dta, replace

*** ---------------------------------------------------------------------------
*** Section 2: Merge School Counts to Crosswalk
*** ---------------------------------------------------------------------------

* Load the cleaned crosswalk
use blockxpuma_clean, clear

* Rename 'block' to avoid conflict with block variable in school data
rename block block_id

* Merge with block-level school counts on baseid (many-to-many)
* Many-to-many because:
*   - One block can map to multiple PUMAs (rare but possible at boundaries)
*   - One block has multiple distance buffers (1, 3, 5, 10 miles)
merge m:m baseid using block_school_counts_all

* Check merge results
tab _merge
* _merge == 1: Blocks in crosswalk but no schools (rural/no private schools)
* _merge == 2: Blocks with schools but not in crosswalk (shouldn't happen)
* _merge == 3: Successful match

drop _merge

*** ---------------------------------------------------------------------------
*** Section 3: Aggregate School Counts to PUMA Level
*** ---------------------------------------------------------------------------

* Average school counts across all blocks within each PUMA-distance pair
* We use (mean) because blocks may have different allocation weights to PUMAs,
* and we want the average exposure within the PUMA

collapse (mean) total_school non_relig relig distinct_fine distinct_collapsed, ///
    by(puma5 distance)

* Save PUMA-level school exposure data
save pumaxblock_school_all, replace

*** ---------------------------------------------------------------------------
*** Section 4: Merge Demographics with School Exposure
*** ---------------------------------------------------------------------------

* Load PUMA-level demographic characteristics (from fl_demo_reg.do)
use fl_puma2000_analysis.dta, clear

* Merge with PUMA-level school counts (one-to-many: one PUMA, many distances)
merge 1:m puma5 using pumaxblock_school_all

* Check merge results
tab _merge
* _merge == 1: PUMAs with demographics but no school data (shouldn't happen)
* _merge == 2: PUMAs with schools but no demographics (shouldn't happen)
* _merge == 3: Successful match (expected for all observations)

drop _merge

*** ---------------------------------------------------------------------------
*** Section 5: Save Final Analysis Dataset
*** ---------------------------------------------------------------------------

* Save final dataset with both demographics and school exposure
* Structure: One observation per PUMA-distance pair
* Variables: Demographics (avg_income, race shares, etc.) + School counts

save school_count_final, replace

*** ---------------------------------------------------------------------------
*** End of Script
*** ---------------------------------------------------------------------------
