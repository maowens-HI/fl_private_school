/****************************************************************************************
* MASTER SCRIPT: run.do
* PROJECT: Florida Private School Exposure Analysis
* AUTHOR: Myles Owens
* INSTITUTION: Hoover Institution, Stanford University
* PURPOSE:
*   - Run entire workflow from raw data → cleaned panels → analysis → outputs
*   - Processes both 1990 and 2000 Census data
*   - Creates block-level school exposure measures
*   - Links schools to PUMA demographics
*   - Performs statistical analysis and optional spatial visualization
*
* WORKFLOW:
*   Phase 0: School count data construction - COMMENTED OUT
*            (school_counts_1990.do - builds 1990 block-level school exposure)
*            (school_counts.do - builds 2000 block-level school exposure)
*   Phase I: PUMA demographics (fl_demo_reg_1990.do, fl_demo_reg.do)
*   Phase II: School-PUMA linkage (blockxpuma_1990.do, blockxpuma.do)
*   Phase III: Statistical analysis (puma_school_analysis_1990.do, puma_school_analysis.do)
*   Phase IV: Spatial visualization (maps.do) - COMMENTED OUT
*
* NOTE: Phases 0 and IV are commented out by default because they are:
*       - Computationally intensive
*       - Only need to be run once (Phase 0)
*       - Generate many large output files (Phase IV)
*       Uncomment if needed.
****************************************************************************************/

* --- 0. Define project root ---
* Change global to where the share_code file is located on your device
global florida "C:/Users/maowens/OneDrive - Stanford/Documents/florida_voucher"
local ProjectDir "$florida"
cd "`ProjectDir'"


cap assert !mi("`ProjectDir'")
if _rc {
    noi di as error "Error: must define global florida in run.do"
    error 9
}

* --- 1. Initialize environment -----------------------------------------------------------
local datetime1 = clock("$S_DATE $S_TIME", "DMYhms")
clear all
set more off

cap mkdir "`ProjectDir'/logs"
cap log close
local logdate : di %tcCCYY.NN.DD!_HH.MM.SS `datetime1'
local logfile "`ProjectDir'/logs/`logdate'.log.txt"
log using "`logfile'", text


* --- 2. Build school count data (Phase 0) -----------------------------------------------
* NOTE: This step is computationally intensive and only needs to be run once
* These scripts use FGDL Census block centroids to calculate distance-based school exposure
* Uncomment if you need to rebuild the block-level school count files
* IMPORTANT: Use separate block boundaries for 1990 vs 2000 for temporal accuracy
* do "`ProjectDir'/code/school_counts_1990.do"  // 1990 Census blocks → *_1990.dta files
* do "`ProjectDir'/code/school_counts.do"       // 2000 Census blocks → *.dta files


* --- 3. Build PUMA demographics (Phase I) ------------------------------------------------
* Process IPUMS microdata for both 1990 and 2000
do "`ProjectDir'/code/fl_demo_reg_1990.do"
do "`ProjectDir'/code/fl_demo_reg.do"


* --- 4. Link schools to PUMAs (Phase II) -------------------------------------------------
* Aggregate block-level school counts to PUMA geography for both years
do "`ProjectDir'/code/blockxpuma_1990.do"
do "`ProjectDir'/code/blockxpuma.do"


* --- 5. Statistical analysis (Phase III) -------------------------------------------------
* Run bivariate and multivariate regressions for both years
do "`ProjectDir'/code/puma_school_analysis_1990.do"
do "`ProjectDir'/code/puma_school_analysis.do"


* --- 6. Spatial visualization (Phase IV - Optional) --------------------------------------
* Create choropleth maps of school exposure patterns
* NOTE: This step is time-consuming and creates many output files
* Comment out if you don't need spatial visualizations
* do "`ProjectDir'/code/maps.do"


* --- 7. Wrap up --------------------------------------------------------------------------
local datetime2 = clock("$S_DATE $S_TIME", "DMYhms")
di "Runtime (hours): " %-12.2fc (`datetime2' - `datetime1')/(1000*60*60)
log close
