# Florida Private School Exposure Analysis

This project analyzes the relationship between Florida community demographics and access to private schools using Census data from 1990 and 2000. The analysis constructs block-level school exposure measures, aggregates them to PUMA geography, links them with Census microdata demographics, and examines cross-sectional correlations between community characteristics and private school access.

## Overview

The workflow processes raw school location data to create block-level exposure measures, constructs PUMA-level demographic datasets for both 1990 and 2000, merges them with private school exposure metrics, and performs both statistical analysis and spatial visualization. This enables examination of patterns in private school access across Florida communities and how they relate to demographic characteristics.

## Data Sources

- **IPUMS Census microdata** (5% sample, Florida only): Individual and household-level demographic data for 1990 and 2000
- **Private school locations** (florida_privates_lat_lon.dta): Geocoded private school locations with type classifications and grade levels
- **Census block centroids** (fl_blocks2000_centroids.dta): Block-level geographic coordinates for distance calculations
- **PUMA × Block crosswalks**: These were created using the Missouri Census Data Ceter "Geocorr 2000: Geographic Correspondence Engine".
  - `geocorr2000_pxb2.csv`: 2000 PUMA boundaries
  - `geocorr1990.csv`: 1990 PUMA boundaries

## Code Structure

### Master Script

**`run.do`** - Executes the complete workflow from raw data to final analysis. Sets global paths, runs all component scripts in sequence, and logs timing information.

### Phase 0: School Count Data Construction

**`school_counts.do`** - Constructs block-level private school exposure measures

Processes raw school location data to create school counts within distance buffers for each Census block:

**Steps:**
1. Loads Census block centroids with lat/lon coordinates
2. Loads geocoded private school locations with type and grade-level classifications
3. Uses `geonear` package to count schools within 1-10 mile buffers of each block centroid
4. Separates analysis by school level (elementary, middle, high school)
5. Calculates school type metrics using both fine-grained and collapsed classifications

**School type classifications:**
- Fine-grained: Original detailed type categories
- Collapsed: 10 aggregated categories (Non-religious, Evangelical, Catholic, Baptist, Mainline Protestant, Adventist, Jewish, Muslim, Other Christian, Other Religion)

**Outputs:**
- `block_school_counts_all_elem.dta`: Elementary school counts by block × distance
- `block_school_counts_all_middle.dta`: Middle school counts by block × distance
- `block_school_counts_all_high.dta`: High school counts by block × distance
- `block_school_counts_all.dta`: Combined file with all levels

### Phase I: PUMA Demographics Construction (1990 & 2000)

**`fl_demo_reg.do`** - Year 2000 PUMA demographics

**`fl_demo_reg_1990.do`** - Year 1990 PUMA demographics

Both scripts process IPUMS microdata to create PUMA-level demographic measures:

**Demographic variables constructed:**
- `avg_income`: Household-weighted average household income
- `black_share`, `white_share`, `other_share`: Racial composition (person-weighted, percent)
- `hisp_share`: Hispanic ethnicity share (person-weighted, percent)
- `less_hs`, `hs_grad`, `some_college`, `college_plus`: Educational attainment distribution (person-weighted, percent)
- `avg_age`: Person-weighted average age

**Outputs:**
- `fl_puma2000_analysis.dta` (year 2000)
- `fl_puma1990_analysis.dta` (year 1990)

### Phase II: School-PUMA Linkage (1990 & 2000)

**`blockxpuma.do`** - Year 2000 school-PUMA linkage

**`blockxpuma_1990.do`** - Year 1990 school-PUMA linkage

Both scripts link block-level school counts to PUMA geographies:

**Steps:**
1. Import PUMA × Block geographic crosswalk
2. Parse and construct standardized 15-character block IDs (baseid = county + tract + block)
3. Merge with block-level school counts
4. Aggregate school counts to PUMA level by distance radius
5. Merge with PUMA demographics

**School exposure measures:**
- `total_school`: Total private schools within buffer
- `relig`: Religious private schools
- `non_relig`: Non-religious private schools
- `distinct_fine`: School type (fine classification)
- `distinct_collapsed`: School type (collapsed classification)
- `distance`: Distance buffer radius (1-10 miles)

**Outputs:**
- `school_count_final.dta` (year 2000)
- `school_count_final_1990.dta` (year 1990)

### Phase III: Analysis (1990 & 2000)

**`puma_school_analysis.do`** - Year 2000 cross-sectional analysis

**`puma_school_analysis_1990.do`** - Year 1990 cross-sectional analysis

Both scripts analyze relationships between demographics and private school exposure:

**Analysis:**
1. Filter to 5-mile distance radius
2. Generate summary statistics for all variables
3. Run bivariate regressions: each demographic variable regressed on each school exposure measure
4. Include multivariate specification with demographic controls

**Outputs (2000):**
- `summary_stats.doc`
- Regression tables: `reg_total_school.tex`, `reg_relig.tex`, `reg_non_relig.tex`, `reg_distinct_fine.tex`, `reg_distinct_collapsed.tex`

**Outputs (1990):**
- `summary_stats_1990.doc`
- Regression tables: `reg_1990_total_school.tex`, `reg_1990_relig.tex`, etc.

### Phase IV: Visualization

**`maps.do`** - Spatial visualization of school exposure patterns

Creates choropleth maps showing geographic distribution of school access:

**Features:**
- Maps for each school level (elementary, middle, high)
- Maps for each exposure measure (total, religious, non-religious, diversity)
- Maps for each distance buffer (1-10 miles)
- County-specific maps (Miami-Dade, Broward, Palm Beach)
- Tri-county corridor visualization
- Uses k-means clustering for bin classification

## Analysis Focus

This project performs **cross-sectional analyses** for both 1990 and 2000, examining correlations between:
- Community socioeconomic status (income, education)
- Demographic composition (race, ethnicity, age)
- Private school exposure (total count, religious vs. non-religious, type diversity)

**Geographic unit:** PUMA (Public Use Microdata Area) - Census geographic areas containing at least 100,000 people

**Distance buffers:** 1-10 miles (primary analysis uses 5-mile radius)

**School levels:** Elementary, middle, and high school analyzed separately

## Current Limitations

**Not yet implemented:**
- Panel/change analysis linking 1990→2000 (requires PUMA concordance across decades)
- Urban/rural classification
