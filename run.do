/****************************************************************************************
* MASTER SCRIPT: run.do
* PROJECT: 
* AUTHOR: Myles Owens
* PURPOSE:
*   - Run entire workflow from raw data → cleaned panels → analysis → outputs
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


* --- 2. Build datasets -------------------------------------------------------------------
do "`ProjectDir'/code/fl_demo_reg.do"
do "`ProjectDir'/code/blockxpuma.do"


* --- 3. Analysis -------------------------------------------------------------------------
do "`ProjectDir'/code/puma_school_analysis.do"


* --- 5. Wrap up --------------------------------------------------------------------------
local datetime2 = clock("$S_DATE $S_TIME", "DMYhms")
di "Runtime (hours): " %-12.2fc (`datetime2' - `datetime1')/(1000*60*60)
log close
