# Florida Private School Exposure Analysis

This project analyzes the relationship between Florida community demographics and access to private schools using year 2000 data. The analysis links Census microdata at the PUMA level with private school counts aggregated from block-level geographic data.

## Overview

The workflow constructs a PUMA-level dataset for Florida in 2000, merges it with private school exposure metrics, and examines cross-sectional correlations between community characteristics and private school access.

## Data Sources

- **IPUMS 2000 Census microdata** (5% sample, Florida only): Individual and household-level demographic data
- **Block-level school locations**: Private school counts by type within distance buffers
- **PUMA × Block crosswalk** (geocorr2000_pxb2.csv): Geographic concordance for aggregating block-level school data to PUMA geography

## Code Structure

### 1. `fl_demo_reg.do` - PUMA Demographics Construction

Processes IPUMS microdata to create PUMA-level demographic measures for Florida in 2000:

**Demographic variables constructed:**
- `avg_income`: Household-weighted average household income
- `black_share`, `white_share`, `other_share`: Racial composition (person-weighted, percent)
- `hisp_share`: Hispanic ethnicity share (person-weighted, percent)
- `less_hs`, `hs_grad`, `some_college`, `college_plus`: Educational attainment distribution (person-weighted, percent)
- `avg_age`: Person-weighted average age

**Output:** `fl_puma2000_analysis.dta`

### 2. `blockxpuma.do` - School Exposure Aggregation

Links block-level school counts to PUMA geographies and merges with demographics:

**Steps:**
1. Imports PUMA × Block crosswalk
2. Loads block-level school counts (combined elementary, middle, and high schools)
3. Aggregates school counts to PUMA level by distance radius
4. Merges with PUMA demographics from `fl_puma2000_analysis.dta`

**School exposure measures:**
- `total_school`: Total private schools
- `relig`: Religious private schools
- `non_relig`: Non-religious private schools
- `distinct_fine`: School type diversity (fine classification)
- `distinct_collapsed`: School type diversity (collapsed classification)

All measures are calculated at multiple distance buffers (aggregated by `distance` variable).

**Output:** `school_count_final.dta`

### 3. `puma_school_analysis.do` - Cross-Sectional Analysis

Analyzes relationships between demographics and private school exposure:

**Analysis:**
1. Filters to 5-mile distance radius
2. Generates summary statistics for all variables
3. Runs bivariate regressions: each demographic variable regressed on each school exposure measure
4. Exports results as LaTeX tables (one per exposure measure)

**Output:**
- Summary statistics table
- Regression tables: `reg_total_school.tex`, `reg_relig.tex`, `reg_non_relig.tex`, `reg_distinct_fine.tex`, `reg_distinct_collapsed.tex`

## Current Limitations

**Not yet implemented:**
- 1990 data and demographic measures
- 1990→2000 geographic crosswalk
- Change analysis (Δ income, Δ race, Δ education, etc.)
- Urban/rural classification
- Multivariate regression models

## Analysis Focus

This is a **cross-sectional analysis** examining year 2000 correlations between:
- Community socioeconomic status (income, education)
- Demographic composition (race, ethnicity, age)
- Private school exposure (total count, religious vs. non-religious, type diversity)

Geographic unit: **PUMA** (Public Use Microdata Area) - Census geographic areas containing at least 100,000 people

Distance buffer: **5 miles** (school counts within 5-mile radius of each block, aggregated to PUMA)
