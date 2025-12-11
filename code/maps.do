
*Housekeeping
clear 
set more off
cd "$florida\data"

* Data prep
/*
*Create dta files from .shp and .dbf
spshape2dta cenblk2000_may09, replace saving(flo)


* Load attribute table
use flo.dta, clear

* Check the fields
describe

* Keep only what you need
keep STFID INTPTLAT00 INTPTLON00 _ID
rename (INTPTLAT00 INTPTLON00) (lat lon)

save fl_blocks2000_centroids.dta, replace
*/


*need geonear package

* Block centroids dataset
use fl_blocks2000_centroids, clear
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
save block_school_counts_all_`s'.dta, replace

restore
}

* Loop over school levels
*ocal levels elem middle high
local charts total_school non_relig relig distinct_fine distinct_collapsed
foreach s of local levels {
    use block_school_counts_all_`s'.dta, clear

    * Loop over variables
    foreach var of local charts {

        * Run kmeans clustering just for this var
        set seed 12345
        cluster kmeans `var', k(6) name(km_`var') iterate(100)

        * Collect cluster bounds
        preserve
        collapse (min) minv=`var' (max) maxv=`var', by(km_`var')
        sort maxv

        local br_`var'
        forvalues i = 1/`=_N' {
            local this = maxv[`i']
            local br_`var' `br_`var'' `this'
        }
        restore

* Jam in zero as the floor
local br_`var' `br_`var''

* Sort and dedupe so zero isn't repeated
numlist "`br_`var''", sort
local brlist `r(numlist)'


* Show final cleaned breakpoints
di as text "Breaks for `var' (`s'): `brlist'"

		* Show the breakpoints in the log
di as text "Breaks for `var' (`s'): `brlist'"
        * Loop over distances
        forvalues d = 1/10 {
            preserve
            keep if distance == `d'

            spmap `var' using flo_shp.dta, id(_ID) ///
                fcolor(Purples) clmethod(custom) clbreaks(`brlist') ///
                ocolor(none ..) osize(vvthin ..) ///
                legtitle("`var' (`s') within `d' miles") ///
                ndocolor(gs15) ///
                title("`var' (`s'), `d'-mile radius") ///
                note("Bins from kmeans") ///
				name(`var'_`s'_d`d', replace)
				
            * Export if you want files
graph export "C:/Users/maowens/OneDrive - Stanford/Documents/florida_voucher/output/charts/fl_`var'_`s'_d`d'.png"

            restore
        }
    }
}

* Loop over school levels
local levels elem middle high
local charts total_school non_relig relig distinct_fine distinct_collapsed

foreach s of local levels {
    use block_school_counts_all_`s'.dta, clear

    * Loop over variables
    foreach var of local charts {

        * Loop over distances
        forvalues d = 1/10 {
            preserve
            keep if distance == `d'

            spmap `var' using flo_shp.dta, id(_ID) ///
                fcolor(Purples) clmethod(kmeans) clnumber(6) ///
                ocolor(none ..) osize(vvthin ..) ///
                legtitle("`var' (`s') within `d' miles") ///
                ndocolor(gs15) ///
                title("`var' (`s'), `d'-mile radius") ///
                note("Bins from spmap kmeans") ///
                name(`var'_`s'_d`d', replace)

            * Export with fl2_ prefix
            graph export "C:/Users/maowens/OneDrive - Stanford/Documents/florida_voucher/output/charts/fl2_`var'_`s'_d`d'.png", replace

            restore
        }
    }
}

use block_school_counts_all_elem, clear
tostring baseid, replace force
gen countyfips = substr(baseid, 1, 5)
keep if distance == 5

* county codes of interest
local counties 12086 12011 12099

foreach c of local counties {
    preserve
    keep if countyfips == "`c'"

    * set human-readable name
    local cname = cond("`c'"=="12086","Miami-Dade", ///
                cond("`c'"=="12011","Broward", ///
                cond("`c'"=="12099","Palm Beach","")))

    spmap total_school using flo_shp.dta, id(_ID) ///
        fcolor(Purples) clmethod(kmeans) clnumber(6) ///
        ocolor(black ..) osize(vvthin ..) ///
        legtitle("Total schools (elem) within 5 miles") ///
        ndocolor(gs15) ///
        title("Total schools (elem), 5-mile radius" "`cname' County") ///
        note("County FIPS: `c'") ///
        name(map_elem5_`c', replace)

    graph export "C:/Users/maowens/OneDrive - Stanford/Documents/florida_voucher/output/charts/elem5_total_school_`c'.png", replace
    restore
}

use block_school_counts_all_elem, clear
tostring baseid, replace force
gen countyfips = substr(baseid, 1, 5)

* keep only distance = 5 and tri-county corridor
keep if distance == 5 & inlist(countyfips, "12086", "12011", "12099")

spmap total_school using flo_shp.dta, id(_ID) ///
    fcolor(Purples) clmethod(kmeans) clnumber(6) ///
    ocolor(black ..) osize(vvthin ..) ///
    legtitle("Total schools (elem) within 5 miles") ///
    ndocolor(gs15) ///
    title("Total schools (elem), 5-mile radius" "Miami-Dade, Broward, Palm Beach") ///
    note("Counties: 12086 (Miami-Dade), 12011 (Broward), 12099 (Palm Beach)") ///
    name(map_elem5_tricounty, replace)

graph export "C:/Users/maowens/OneDrive - Stanford/Documents/florida_voucher/output/charts/elem5_total_school_tricounty.png", replace



