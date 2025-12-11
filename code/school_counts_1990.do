/*==============================================================================
Project    : Florida Private School Exposure Analysis
File       : school_counts_1990.do
Purpose    : Construct 1990 block-level count of all schools at different radii
Author     : Myles Owens
Institution: Hoover Institution, Stanford University
Date       : 2025-12-11
───────────────────────────────────────────────────────────────────────────────
Description:
    This script constructs block-level private school exposure measures by
    calculating school counts within distance buffers (1-10 miles) for each
    1990 Census block centroid in Florida. The analysis is performed separately
    for three school levels (elementary, middle, high school) and generates
    counts by school type (religious vs. non-religious) and type diversity
    measures.

    Uses geonear package to identify schools within specified distance buffers
    from each block centroid. For each distance radius, aggregates school
    counts and calculates diversity metrics based on both fine-grained and
    collapsed school type classifications.

    IMPORTANT: This version uses 1990 Census block boundaries for temporal
    accuracy. Census block boundaries changed between 1990 and 2000, so
    separate files are required for each decade.

Inputs:
    - fl_blocks1990_centroids.dta    1990 block centroids with lat/lon coordinates
    - florida_privates_lat_lon.dta   Private school locations with type classifications

Outputs:
    - block_school_counts_all_elem_1990.dta    Elementary school counts by block × distance
    - block_school_counts_all_middle_1990.dta  Middle school counts by block × distance
    - block_school_counts_all_high_1990.dta    High school counts by block × distance
    - block_school_counts_all_1990.dta         Combined all school levels

Key Variables Created:
    - baseid              15-character Census block identifier (from STFID)
    - total_school        Total private schools within buffer
    - non_relig           Non-religious private schools count
    - relig               Religious private schools count
    - distinct_fine       Number of distinct school types (fine classification)
    - distinct_collapsed  Number of distinct school types (collapsed classification)
    - distance            Distance buffer radius (1-10 miles)

Notes:
    - Distance buffers: 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 miles
    - School type classifications:
        * Fine: Original granular type categories (type_num_fine)
        * Collapsed: 10 aggregated categories (type_num_collapsed)
    - Runs separately for each school level (elem, middle, high)
    - Requires geonear package for geographic distance calculations
    - Zero counts explicitly assigned for blocks with no schools in buffer
    - Block centroids obtained from Florida Geographic Data Library (FGDL)
      https://fgdl.org/

==============================================================================*/
*Housekeeping
clear
set more off
cd "$florida\data"

* Data prep
* Create dta files from .shp and .dbf for 1990 Census blocks
* Source: Florida Geographic Data Library (FGDL) - https://fgdl.org/
spshape2dta cenblk1990, replace saving(flo_1990)


* Load attribute table
use flo_1990.dta, clear

* Check the fields
describe

* Check coordinate values to determine if they're lat/lon or projected
summarize _CX _CY

* If _CY is between 25-31 and _CX is between -87 to -80, they are lat/lon
* Otherwise, they are in a projected coordinate system and need conversion
* For FGDL 1990 data, _CX and _CY are typically the centroid coordinates
* Rename _CY to INTPTLAT90 and _CX to INTPTLON90
rename (_CY _CX) (INTPTLAT90 INTPTLON90)

* Keep only what you need
keep STFID INTPTLAT90 INTPTLON90 _ID
rename (INTPTLAT90 INTPTLON90) (lat lon)

save fl_blocks1990_centroids.dta, replace

*need geonear package

* Block centroids dataset (1990 Census blocks)
use fl_blocks1990_centroids, clear
destring lat lon, replace
rename (lat lon STFID) (baselat baselon baseid)
tempfile blocks
save `blocks'

* ------------------------------
* Schools prep
* ------------------------------
use florida_privates_lat_lon, clear

* Define education grade-level flags
local edu elem middle high

foreach s of local edu{
* restrict to edu
preserve
keep if `s' == 1

* fine-grained: every raw 'type' is its own code
capture drop type_num_fine
encode type, gen(type_num_fine)

* collapsed per David
capture drop type_num_collapsed
gen type_num_collapsed = .

replace type_num_collapsed = 1  if type == "NON-RELIGIOUS"
replace type_num_collapsed = 2  if inlist(type, "EVANGELICAL", "APOSTOLIC-PENTECOSTAL-CHARISMATIC")
replace type_num_collapsed = 3  if type == "CATHOLIC"
replace type_num_collapsed = 4  if type == "BAPTIST"
replace type_num_collapsed = 5  if inlist(type, "LUTHERAN","METHODIST","PRESBYTERIAN","EPISCOPAL")
replace type_num_collapsed = 6  if type == "ADVENTIST"
replace type_num_collapsed = 7  if type == "JEWISH"
replace type_num_collapsed = 8  if type == "MUSLIM"
replace type_num_collapsed = 9  if type == "OTHER CHRISTIAN"
replace type_num_collapsed = 10 if type == "OTHER RELIGION"

label define type_collapsed_lbl 1 "Non-religious" 2 "Evangelical" 3 "Catholic" 4 "Baptist" ///
                               5 "Mainline Protestant" 6 "Adventist" 7 "Jewish" 8 "Muslim" ///
                               9 "Other Christian" 10 "Other Religion"
label values type_num_collapsed type_collapsed_lbl

* sanity: ensure coords exist
assert !missing(priv_g_lat, priv_g_lon)

* give each school an id
gen long priv_g_id = _n

tempfile schools
save `schools'

* ------------------------------
* One big panel: block x distance
* ------------------------------
clear
tempfile allcounts
save `allcounts', emptyok

forvalues d = 1/10 {
    di as text "Processing radius = `d' miles"

    * find neighbors within d miles
    use `blocks', clear
    geonear baseid baselat baselon using `schools', ///
        neighbors(priv_g_id priv_g_lat priv_g_lon) ///
        long within(`d') miles

    * attach school attributes for counting
    merge m:1 priv_g_id using `schools', keep(match master) nogen

    * if there were zero neighbors statewide, create empty shell for merge
    capture confirm variable priv_g_id
    if _rc {
        preserve
        use `blocks', clear
        gen total_school = 0
        gen non_relig   = 0
        gen relig       = 0
        gen distinct_fine = 0
        gen distinct_collapsed = 0
        gen distance = `d'
        append using `allcounts'
        save `allcounts', replace
        restore
        continue
    }

    * counts
    gen total_school = 1
    gen non_relig    = (type == "NON-RELIGIOUS")
    gen relig        = (type != "NON-RELIGIOUS")

    * distinct (fine): tag first row per baseid x type_num_fine
    bysort baseid type_num_fine: gen byte tag_f = (_n==1)

    * distinct (collapsed): tag first row per baseid x type_num_collapsed
    bysort baseid type_num_collapsed: gen byte tag_c = (_n==1)

    * collapse to block level; sum of tags = number of unique categories present
    collapse (sum) total_school non_relig relig tag_f tag_c, by(baseid)
    rename (tag_f tag_c) (distinct_fine distinct_collapsed)

    * bring coords (and _ID for spmap) back in, zero-fill missings
    merge 1:1 baseid using `blocks', nogen
    foreach v in total_school non_relig relig distinct_fine distinct_collapsed {
        replace `v' = 0 if missing(`v')
    }

    * add distance
    gen byte distance = `d'

    * append into the master panel
    append using `allcounts'
    save `allcounts', replace
}

* final save
use `allcounts', clear
order baseid _ID baselat baselon distance total_school non_relig relig distinct_fine distinct_collapsed
compress
save block_school_counts_all_`s'_1990.dta, replace

restore
}




clear all

* Start with HIGH
use "block_school_counts_all_high_1990.dta", clear
gen level = "high"

* Append MIDDLE
append using "block_school_counts_all_middle_1990.dta"
replace level = "middle" if missing(level)

* Append ELEM
append using "block_school_counts_all_elem_1990.dta"
replace level = "elem" if missing(level)

save "block_school_counts_all_1990.dta", replace
