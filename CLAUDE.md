# CLAUDE.md - AI Assistant Guide for fl_private_school Repository

## Project Overview

This repository analyzes the relationship between Florida community demographics and access to private schools using year 2000 Census data. The analysis constructs PUMA-level demographic measures from IPUMS microdata and merges them with private school exposure metrics aggregated from block-level geographic data.

**Author:** Myles Owens
**Institution:** Hoover Institution, Stanford University
**Email:** myles.owens@stanford.edu
**Language:** Stata (all .do files)
**Data Period:** Year 2000 (cross-sectional analysis)
**Geographic Unit:** PUMA (Public Use Microdata Area)

## Research Question

What is the relationship between community demographic characteristics (income, race, ethnicity, education) and access to private schools in Florida? How do these patterns vary by school type (religious vs. non-religious) and school diversity?

## Core Methodology

- **Approach:** Cross-sectional analysis using year 2000 data
- **Geographic Unit:** PUMA - Census geographic areas containing at least 100,000 people
- **Distance Buffer:** 5-mile radius (school counts within 5 miles of each block, aggregated to PUMA level)
- **Analysis:** Bivariate regressions examining correlations between demographics and school exposure
- **Key Challenge:** Linking Census microdata (PUMA geography) with school location data (block geography) via geographic crosswalk

## Repository Structure

```
fl_private_school/
├── README.md                       # Project documentation
├── CLAUDE.md                       # This file - AI assistant guide
├── code/                           # All Stata scripts
│   ├── fl_demo_reg.do              # Build PUMA-level demographics from IPUMS
│   ├── blockxpuma.do               # Link block-level schools to PUMAs
│   └── puma_school_analysis.do    # Cross-sectional regression analysis
└── data/                           # Data directory (files not in repo)
    ├── fl_demo.dta                 # [External] IPUMS microdata
    ├── geocorr2000_pxb2.csv        # [External] PUMA × Block crosswalk
    ├── block_school_counts_all.dta # [Generated] Combined school counts
    ├── fl_puma2000_analysis.dta    # [Generated] PUMA demographics
    ├── blockxpuma_clean.dta        # [Generated] Cleaned crosswalk
    ├── pumaxblock_school_all.dta   # [Generated] PUMA-level school counts
    └── school_count_final.dta      # [Generated] Final analysis dataset
```

**Total Code:** ~320 lines across 3 Stata .do files

## Understanding .DO Files

### What are .do files?

- Plain-text Stata script files containing sequential commands for data analysis
- Equivalent to R scripts (.R) or Python scripts (.py), but for Stata statistical software
- Execute data cleaning, transformation, merging, statistical analysis, and visualization
- Comments start with `*` (line comment) or `//` (inline comment)
- Multi-line comments use `/* ... */`

### Common Stata Commands You'll See

| Command | Purpose | Example |
|---------|---------|---------|
| `use` | Load .dta file | `use "data/file.dta", clear` |
| `merge` | Join datasets | `merge 1:m puma using schools` |
| `collapse` | Aggregate data | `collapse (mean) income, by(puma)` |
| `gen` | Create new variable | `gen is_black = race == 2` |
| `replace` | Modify existing variable | `replace x = 0 if missing(x)` |
| `preserve`/`restore` | Save/restore data in memory | `preserve ... restore` |
| `bysort` | Group operations | `bysort puma: egen mean_x = mean(x)` |
| `reg` | Linear regression | `reg y x1 x2` |
| `eststo` | Store regression results | `eststo: reg y x` |
| `esttab` | Export results table | `esttab using "table.tex"` |

## Data Flow Pipeline

### Phase I: PUMA Demographics Construction

```
Raw IPUMS Microdata (fl_demo.dta)
        │
        v
    fl_demo_reg.do
        │
        ├──> Filter: Florida only (statefip==12)
        ├──> Filter: Year 2000, 5% sample (sample==200001)
        │
        ├──> Household-level: Average household income (weighted by hhwt)
        │
        ├──> Person-level:
        │    • Race shares (black_share, white_share, other_share)
        │    • Hispanic share (hisp_share)
        │    • Education distribution (less_hs, hs_grad, some_college, college_plus)
        │    • Average age (avg_age)
        │
        v
    fl_puma2000_analysis.dta
```

**Key Operations:**

1. **Household Income:** Compute at household level using one record per `serial` (household ID), weighted by `hhwt`
2. **Person Characteristics:** Collapse person-level data using person weights (`perwt`)
3. **Race/Ethnicity:** Create indicator variables, compute weighted shares as percentages
4. **Education:** Use IPUMS `educ` codes to create attainment categories

### Phase II: School-PUMA Linkage

```
Block-Level School Data                  PUMA × Block Crosswalk
(block_school_counts_all.dta)           (geocorr2000_pxb2.csv)
        │                                        │
        v                                        v
    blockxpuma.do
        │
        ├──> Parse crosswalk: county + tract + block → baseid (15-char ID)
        │
        ├──> Merge school counts to crosswalk on baseid
        │
        ├──> Collapse to PUMA level: (mean) school counts by(puma5 distance)
        │
        v
    pumaxblock_school_all.dta
```

**Key Operations:**

1. **Crosswalk Parsing:**
   - Split tract into whole and fractional parts (e.g., "9841.01" → "9841" + "01")
   - Pad components: `tract_whole4` (4 digits), `tract_frac2` (2 digits), `block4` (4 digits)
   - Construct `baseid` = county (5) + tract (6) + block (4) = 15 characters

2. **Geographic Aggregation:**
   - Multiple distance buffers stored in `distance` variable (analysis uses 5-mile)
   - School counts averaged across blocks within each PUMA

### Phase III: Merge and Analysis

```
fl_puma2000_analysis.dta     pumaxblock_school_all.dta
        │                              │
        └──────────┬───────────────────┘
                   v
            blockxpuma.do (merge)
                   │
                   v
        school_count_final.dta
                   │
                   v
        puma_school_analysis.do
                   │
                   ├──> Filter: distance == 5 miles
                   ├──> Summary statistics for all variables
                   ├──> Bivariate regressions: each demographic ~ each school measure
                   └──> Export LaTeX tables
                   │
                   v
            Output: reg_total_school.tex, reg_relig.tex, etc.
```

## Key Variables

### Demographic Variables (from IPUMS)

| Variable | Description | Source | Weight |
|----------|-------------|--------|--------|
| `avg_income` | Average household income (2000 dollars) | `hhincome` | `hhwt` |
| `black_share` | % Black population | `race==2` | `perwt` |
| `white_share` | % White population | `race==1` | `perwt` |
| `other_share` | % Other race population | `race>2` | `perwt` |
| `hisp_share` | % Hispanic population | `hispan!=0` | `perwt` |
| `less_hs` | % Less than high school | `educ` 0-5 | `perwt` |
| `hs_grad` | % High school graduate | `educ==6` | `perwt` |
| `some_college` | % Some college | `educ` 7-9 | `perwt` |
| `college_plus` | % College or higher | `educ` 10-11 | `perwt` |
| `avg_age` | Average age | `age` | `perwt` |

### School Exposure Variables (aggregated to PUMA)

| Variable | Description | Unit |
|----------|-------------|------|
| `total_school` | Total private schools within buffer | Count |
| `relig` | Religious private schools | Count |
| `non_relig` | Non-religious private schools | Count |
| `distinct_fine` | School type diversity (fine classification) | Count of unique types |
| `distinct_collapsed` | School type diversity (collapsed classification) | Count of unique types |
| `distance` | Distance buffer radius | Miles |

### Geographic Identifiers

| Identifier | Format | Length | Description | Example |
|------------|--------|--------|-------------|---------|
| `puma` | Numeric | Varies | PUMA code (numeric) | 3810 |
| `puma5` | String | 5 chars | PUMA code (zero-padded) | "03810" |
| `baseid` | String | 15 chars | County + Tract + Block | "120110984101001" |
| `county` | Numeric | 5 digits | State FIPS (2) + County FIPS (3) | 12011 |
| `tract` | String | Varies | Tract code (may include decimals) | "9841.01" |
| `block` | Numeric | 4 digits | Block number | 1001 |
| `statefip` | Numeric | 2 digits | State FIPS code (Florida = 12) | 12 |

## Coding Conventions

### Global Path Configuration

**CRITICAL:** All scripts require this global to be set:

```stata
global florida "C:\Users\<user>\path\to\fl_private_school"
```

- Set this at the beginning of your Stata session or in a master .do file
- All file paths reference `$florida/data/...` or `$florida/output/...`
- **AI Assistants:** When modifying code, preserve this path structure

### Naming Conventions

**Variable Naming:**

- Use underscores for multi-word variables: `avg_income`, `black_share`
- Suffix `_share` for percentage variables: `black_share`, `hisp_share`
- Prefix indicators with `is_`: `is_black`, `is_hisp` (before collapsing)
- Temporary variables: `temp_*`, `pop_*`, `hh_*`
- String versions of numeric IDs: append number (e.g., `puma5` = 5-char string version of `puma`)

**File Naming:**

- Descriptive names indicating purpose: `fl_demo_reg.do`, `blockxpuma.do`
- Intermediate data files describe content: `blockxpuma_clean.dta`, `pumaxblock_school_all.dta`
- Output files indicate analysis: `school_count_final.dta`

### Code Structure Pattern

Every .do file follows this structure:

```stata
/*==============================================================================
Project    : Florida Private School Exposure Analysis
File       : filename.do
Purpose    : [Clear description]
Author     : Myles Owens
Institution: Hoover Institution, Stanford University
Date       : YYYY-MM-DD
───────────────────────────────────────────────────────────────────────────────
Inputs:    - Input file 1
           - Input file 2
Outputs:   - Output file 1
Notes:     - Implementation details
==============================================================================*/

clear all
set more off
cd "$florida/data"

*** ---------------------------------------------------------------------------
*** Section 1: Data Import
*** ---------------------------------------------------------------------------

[code here]

*** ---------------------------------------------------------------------------
*** Section 2: Data Processing
*** ---------------------------------------------------------------------------

[code here]

*** ---------------------------------------------------------------------------
*** Section 3: Save Output
*** ---------------------------------------------------------------------------

save "output.dta", replace
```

## Data Operations Patterns

### Working with Weighted Means

**Household-level statistics (use `hhwt`):**

```stata
* One record per household
bys serial: keep if _n == 1

* Weighted mean
collapse (mean) avg_income = hhincome [pw=hhwt], by(puma)
```

**Person-level statistics (use `perwt`):**

```stata
* Create indicator
gen is_black = race == 2

* Weighted share
collapse (mean) black_share = is_black [pw=perwt], by(puma)

* Convert to percent
replace black_share = 100 * black_share
```

### Preserve/Restore Pattern

Used extensively to compute different aggregations from same base data:

```stata
use base_data.dta, clear

* --- Compute person-level stats ---
preserve
    [person-level operations]
    tempfile person_stats
    save `person_stats'
restore

* --- Compute household-level stats ---
preserve
    [household-level operations]
    tempfile hh_stats
    save `hh_stats'
restore

* --- Merge results ---
use `person_stats', clear
merge 1:1 puma using `hh_stats'
```

### String Manipulation for Geographic IDs

```stata
* Parse decimal tract codes
gen str tract_whole = substr(tract, 1, strpos(tract,".")-1) if strpos(tract,".")>0
replace tract_whole = tract if missing(tract_whole)

gen str tract_frac = substr(tract, strpos(tract,".")+1, .) if strpos(tract,".")>0

* Format with padding
gen str tract_whole4 = string(real(tract_whole), "%04.0f")
gen str tract_frac2  = cond(missing(tract_frac), "00", string(real(tract_frac), "%02.0f"))

* Combine into standardized ID
gen str tract6 = tract_whole4 + tract_frac2
```

### Collapse with Multiple Distance Buffers

```stata
* Aggregate school counts to PUMA, preserving distance dimension
collapse (mean) total_school non_relig relig distinct_fine distinct_collapsed, ///
    by(puma5 distance)
```

### Regression Loop Pattern

```stata
* Loop over outcome variables
foreach exp in total_school non_relig relig distinct_fine distinct_collapsed {
    eststo clear
    eststo: reg avg_income   `exp'
    eststo: reg black_share  `exp'
    eststo: reg hisp_share   `exp'

    * Export table for this exposure measure
    esttab using "$florida/output/charts/reg_`exp'.tex", replace ///
        se r2 ar2 label style(tex) ///
        title("Regression Results using `exp'")
}
```

## Common Tasks for AI Assistants

### Task 1: Add New Demographic Variables

**Location:** `fl_demo_reg.do`

**Pattern to follow:**

```stata
preserve
    * Create indicator or transformation
    gen new_var = [transformation of IPUMS variable]

    * Collapse with appropriate weight
    collapse (mean) new_var [pw=perwt], by(puma)

    * Label
    label var new_var "Description"

    tempfile new_var_file
    save `new_var_file'
restore

* Merge back to main dataset
use `new_var_file', clear
merge 1:m puma using `merger'
drop _merge
save `merger', replace
```

**Example additions:**
- Poverty rates
- Home ownership rates
- Family structure variables
- Employment statistics

### Task 2: Modify Distance Buffer Analysis

**Location:** `puma_school_analysis.do`

**Current code:**
```stata
keep if distance == 5
```

**To analyze different distance:**
```stata
keep if distance == 3  // Change to 3-mile radius
```

**To compare multiple distances:**
```stata
* Don't filter - keep all distances
* Add distance to regression
reg avg_income total_school i.distance
```

### Task 3: Add Control Variables to Regressions

**Location:** `puma_school_analysis.do`

**Current specification (bivariate):**
```stata
reg avg_income total_school
```

**Add controls (multivariate):**
```stata
reg avg_income total_school black_share hisp_share avg_age college_plus
```

**Full modification example:**
```stata
* Instead of simple loop, run multivariate specifications
eststo clear
eststo: reg total_school avg_income, robust
eststo: reg total_school avg_income black_share hisp_share, robust
eststo: reg total_school avg_income black_share hisp_share avg_age college_plus, robust

esttab using "$florida/output/charts/reg_multivariate.tex", replace ///
    se r2 ar2 label style(tex) ///
    title("Multivariate Regression Results")
```

### Task 4: Add School Level Analysis

**Location:** Create new script or modify `blockxpuma.do`

**Current aggregation:**
```stata
* Combined all school levels
use block_school_counts_all, clear
```

**To analyze by school level:**
```stata
* Keep level variable
collapse (mean) total_school non_relig relig distinct_fine distinct_collapsed, ///
    by(puma5 distance level)

* In analysis, subset or interact with level
use school_count_final, clear
keep if level == "high"  // Only high schools
```

### Task 5: Debug Merge Issues

**Common problems:**

1. **ID format mismatch:**
```stata
* Check formats before merge
describe puma  // Is it numeric or string?
describe puma5 // Is it string with correct padding?

* Convert if needed
gen str puma5 = string(puma, "%05.0f")
```

2. **Duplicate keys:**
```stata
* Check for duplicates before merge
duplicates report puma5
duplicates list puma5 if [condition]

* Remove duplicates if appropriate
duplicates drop puma5, force
```

3. **Merge results:**
```stata
merge 1:m puma5 using other_data
tab _merge  // Check match rates

* Investigate unmatched
list puma5 if _merge != 3
```

### Task 6: Add Summary Statistics

**Location:** `puma_school_analysis.do` or new script

**Basic summary:**
```stata
summarize varlist, detail
```

**Summary by group:**
```stata
bysort some_category: summarize varlist
```

**Export to table:**
```stata
outreg2 using summary_stats.doc, sum(log) replace
```

**Custom summary table:**
```stata
* Manual approach for custom formatting
tabstat avg_income black_share hisp_share total_school, ///
    statistics(mean sd min max) columns(statistics)
```

## Data Quality and Validation

### Built-in Quality Checks

The codebase includes implicit quality validation:

1. **Sample Filtering:** Ensures consistent 2000 5% sample (`sample==200001`)
2. **Geographic Consistency:** Florida only (`statefip==12`)
3. **Income Validity:** Drops bad codes (`hhincome < 0 | hhincome == 9999999`)
4. **ID Length Validation:** Checks `baseid` has exactly 15 characters
5. **Merge Verification:** Uses `tab _merge` to verify linkages

### When to Be Cautious

⚠️ **Warning Signs:**

- Large numbers of unmatched records in merges (`_merge != 3`)
- Missing values in key demographic variables after collapse
- `baseid` length != 15 (geographic ID construction error)
- Extreme outliers in school counts (may indicate data error)
- PUMAs with zero population or missing demographics

**Best Practices:**

- Always check `tab _merge` after merges
- Use `count if missing(key_var)` to check completeness
- Verify `baseid` construction: `count if length(baseid) != 15`
- Cross-check totals before and after aggregation
- Generate summary statistics with `summarize, detail` to spot outliers

### Validation Commands

```stata
* After merge
tab _merge
list puma5 total_school if _merge != 3 & _n <= 10

* Check missing data
foreach v of varlist * {
    count if missing(`v')
    if r(N) > 0 {
        display "`v': " r(N) " missing"
    }
}

* Check ID construction
count if length(baseid) != 15
list county tract block baseid if length(baseid) != 15 & _n <= 10

* Summary statistics for outliers
summarize varlist, detail
```

## File Dependencies

### Must Run in Order

**Phase I: Demographics**
1. `fl_demo_reg.do` - Creates PUMA-level demographics from IPUMS microdata
   - **Input:** `fl_demo.dta` (IPUMS raw data)
   - **Output:** `fl_puma2000_analysis.dta`

**Phase II: School-PUMA Linkage**
2. `blockxpuma.do` - Links block-level schools to PUMAs
   - **Inputs:**
     - `geocorr2000_pxb2.csv` (crosswalk)
     - `block_school_counts_all.dta` (school counts)
     - `fl_puma2000_analysis.dta` (from Phase I)
   - **Outputs:**
     - `blockxpuma_clean.dta` (cleaned crosswalk)
     - `pumaxblock_school_all.dta` (PUMA-level school counts)
     - `school_count_final.dta` (final merged dataset)

**Phase III: Analysis**
3. `puma_school_analysis.do` - Regression analysis
   - **Input:** `school_count_final.dta` (from Phase II)
   - **Outputs:** LaTeX tables (`reg_*.tex`)

### External Dependencies

**Data files (not in repo, must be obtained separately):**

- **IPUMS USA:** `fl_demo.dta`
  - Source: https://usa.ipums.org/usa/
  - Extract: 2000 Census 5% sample, Florida only
  - Variables needed: `statefip`, `puma`, `year`, `sample`, `perwt`, `hhwt`, `serial`, `race`, `hispan`, `educ`, `age`, `hhincome`

- **Geographic Crosswalk:** `geocorr2000_pxb2.csv`
  - Source: MCDC Geocorr 2000 (University of Missouri)
  - URL: http://mcdc.missouri.edu/applications/geocorr2000.html
  - Geographic units: PUMA × Block for Florida

- **School Location Data:** Block-level school counts
  - `block_school_counts_all_high.dta`
  - `block_school_counts_all_middle.dta`
  - `block_school_counts_all_elem.dta`
  - (Or combined: `block_school_counts_all.dta`)

**Stata Packages:**

Install using `ssc install`:
- `outreg2` - Export regression and summary tables
- `estout` / `esttab` - Export formatted regression tables

```stata
ssc install outreg2
ssc install estout
```

## Working with Git

### Current Branch

This project uses the branch: **`claude/create-claude-md-01SaKNKFhWupFCnAGUUv2dWw`**

**Important git practices:**

- Always develop on the designated `claude/*` branch
- Commit with clear, descriptive messages
- Push with `-u` flag: `git push -u origin <branch-name>`
- Never force push without explicit permission

### Typical Workflow

```bash
# Check status
git status

# Add modified files
git add code/new_file.do
git add CLAUDE.md

# Commit with message
git commit -m "Add multivariate regression specifications to school analysis"

# Push to remote
git push -u origin claude/create-claude-md-01SaKNKFhWupFCnAGUUv2dWw
```

### File Management

**.gitignore should include:**
- All `.dta` files (Stata data - too large for git)
- Output files (`.tex`, `.doc`, `.txt` results)
- Log files (`.log`)

**DO commit:**
- All `.do` files (code)
- Documentation (`.md` files)
- Crosswalk files (`.csv`) if small enough

## Interpreting Results

### Regression Output

The analysis produces bivariate regression tables:

```
Y (demographic) = β₀ + β₁ × School_Exposure + ε
```

**Coefficients to examine:**

- **Positive β₁:** Higher school exposure associated with higher demographic value
  - Example: `β_income > 0` → Wealthier areas have more private schools
  - Example: `β_college > 0` → More educated areas have more private schools

- **Negative β₁:** Higher school exposure associated with lower demographic value
  - Example: `β_black < 0` → Areas with more Black residents have fewer private schools

- **Near-zero β₁:** Little correlation between demographic and school access

**Statistical Significance:**

- `* p < 0.10`
- `** p < 0.05`
- `*** p < 0.01`

### Expected Patterns

**Hypotheses to test:**

1. **Income Sorting:** Wealthier areas have greater private school access
2. **Racial Segregation:** White areas have more private schools than Black/Hispanic areas
3. **Education Correlation:** College-educated areas have more school options
4. **Religious Schools:** Different demographic patterns than non-religious schools

### Summary Statistics

Examine distributions before regression:

```stata
summarize total_school relig non_relig, detail
```

Look for:
- Mean and median school counts
- Variability (SD) across PUMAs
- Outliers (min, max, p99)
- Zero counts (PUMAs with no private schools)

## Troubleshooting Common Issues

### "File not found" errors

**Cause:** Global path not set correctly

**Fix:**
```stata
global florida "/correct/path/to/fl_private_school"
cd "$florida/data"
```

### "Variable not found" errors

**Cause:** Missing merge or incorrect variable name

**Fix:**
```stata
* Check if previous script ran successfully
describe  // See what variables exist

* Verify merge was successful
tab _merge

* Check variable spelling (Stata is case-sensitive)
lookfor income  // Find variables containing "income"
```

### "No observations" errors

**Cause:** Too restrictive filtering

**Fix:**
```stata
count                    // Before filter
keep if distance == 5
count                    // After filter

* If too many dropped, check distance values
tab distance
```

### Merge produces no matches

**Cause:** ID format mismatch (string vs. numeric, padding)

**Fix:**
```stata
* Check ID formats in both datasets
describe puma puma5

* Ensure consistent string formatting
gen str puma5 = string(puma, "%05.0f")

* Verify IDs exist in both datasets
tab puma5  // In first dataset
use other_data.dta
tab puma5  // In second dataset
```

### Geographic ID construction fails

**Cause:** Tract decimal parsing or padding errors

**Fix:**
```stata
* Check tract format
list county tract block baseid if length(baseid) != 15

* Verify string manipulation
list tract tract_whole tract_frac tract6 in 1/20

* Check for missing components
count if missing(tract_whole) | missing(tract_frac)
```

## Best Practices for AI Assistants

### ✅ DO:

- Read existing files before making changes (use Read tool)
- Preserve header comments and update them if logic changes
- Maintain consistent style with existing code
- Test incrementally - check intermediate results with `tab`, `count`, `list`
- Document changes clearly in commit messages
- Validate merges with `tab _merge`
- Check data dimensions before and after operations (`count`, `describe`)
- Comment non-obvious transformations (especially geographic ID manipulation)

### ❌ DON'T:

- Don't modify global paths without user confirmation
- Don't delete seemingly redundant `preserve`/`restore` blocks - they're intentional
- Don't change variable names used in downstream scripts without updating all files
- Don't commit large data files (`.dta` files should be in `.gitignore`)
- Don't skip header documentation in new files
- Don't use hardcoded paths - always use `$florida`
- Don't remove weight specifications (`[pw=perwt]`) without understanding the implication
- Don't assume IPUMS variable codes - verify with IPUMS documentation

### When Uncertain:

- Ask the user for clarification
- Check existing patterns in similar sections of code
- Read the README.md for project context
- Consult IPUMS documentation for variable coding
- Test string manipulation for geographic IDs on small samples first

## Quick Reference

### Most Important Files

| File | Purpose |
|------|---------|
| `fl_demo_reg.do` | **Build PUMA demographics** - Core data construction from IPUMS |
| `blockxpuma.do` | **Link schools to PUMAs** - Geographic crosswalk and aggregation |
| `puma_school_analysis.do` | **Run analysis** - Regressions and output tables |
| `school_count_final.dta` | **Final dataset** - Merged demographics + school exposure |

### Most Important Variables

| Variable | Description |
|----------|-------------|
| `avg_income` | Average household income (outcome or control) |
| `black_share` | % Black population (key demographic) |
| `hisp_share` | % Hispanic population (key demographic) |
| `college_plus` | % College educated (education measure) |
| `total_school` | Total private school count (main exposure) |
| `relig` | Religious school count (exposure by type) |
| `non_relig` | Non-religious school count (exposure by type) |
| `distance` | Distance buffer (5-mile typical) |
| `puma5` | PUMA ID (5-char string, merge key) |

### Most Important Commands

| Command | Purpose |
|---------|---------|
| `use "file.dta", clear` | Load dataset |
| `preserve` ... `restore` | Temporary data operations |
| `collapse (mean) var [pw=weight], by(group)` | Weighted aggregation |
| `merge 1:m key using file` | Join datasets (1-to-many) |
| `tab _merge` | Check merge results |
| `gen str var = string(num, "%05.0f")` | Format numeric as padded string |
| `reg y x` | Linear regression |
| `eststo: reg y x` | Store regression results |
| `esttab using "file.tex"` | Export regression table |

### IPUMS Variable Quick Reference

| IPUMS Variable | Description | Values |
|----------------|-------------|--------|
| `statefip` | State FIPS code | 12 = Florida |
| `puma` | PUMA identifier | Numeric, varies by state |
| `year` | Census year | 2000 |
| `sample` | IPUMS sample | 200001 = 2000 5% |
| `serial` | Household ID | Unique within year/sample |
| `perwt` | Person weight | Use for person-level stats |
| `hhwt` | Household weight | Use for household-level stats |
| `race` | Race code | 1=White, 2=Black, 3+=Other |
| `hispan` | Hispanic origin | 0=Not Hispanic, 1+=Hispanic |
| `educ` | Educational attainment | 0-5=<HS, 6=HS, 7-9=Some college, 10-11=College+ |
| `age` | Age in years | 0-99+ |
| `hhincome` | Household income | Dollars; 9999999=N/A |

## Additional Resources

### IPUMS USA

- **Website:** https://usa.ipums.org/usa/
- **User Guide:** https://usa.ipums.org/usa/user_guide.shtml
- **Variable Descriptions:** Search variables at https://usa.ipums.org/usa-action/variables/group

### Geographic Resources

- **MCDC Geocorr 2000:** http://mcdc.missouri.edu/applications/geocorr2000.html
  - Tool for creating custom geographic crosswalks
- **Census PUMA Documentation:** https://www.census.gov/programs-surveys/geography/guidance/geo-areas/pumas.html

### Stata Resources

- **Stata Documentation:** https://www.stata.com/manuals/
- **Collapse:** `help collapse`
- **Merge:** `help merge`
- **Regression:** `help regress`
- **String Functions:** `help string functions`
- **Weights:** `help weight`

### Data Citation

If using this analysis, cite:

**IPUMS USA:**
> Steven Ruggles, Sarah Flood, Ronald Goeken, Megan Schouweiler, and Matthew Sobek. IPUMS USA: Version 13.0 [dataset]. Minneapolis, MN: IPUMS, 2023. https://doi.org/10.18128/D010.V13.0

## Current Limitations and Future Extensions

**Not yet implemented:**

- **1990 data:** IPUMS microdata for 1990 Census
- **1990→2000 crosswalk:** Geographic concordance for panel/change analysis
- **Change analysis:** Δ income, Δ race, Δ education over 1990-2000
- **Urban/rural classification:** Metropolitan vs. non-metropolitan PUMA categorization
- **Multivariate regressions:** Full model with multiple demographic controls
- **School quality measures:** Enrollment size, tuition, academic performance
- **Spatial analysis:** Spatial autocorrelation, local clustering (Moran's I)

**Potential Extensions:**

1. **Panel Analysis:** Add 1990 data and examine changes in demographics and school access
2. **Heterogeneity:** Separate analysis by urban/rural or by county
3. **Interaction Models:** `reg total_school c.avg_income##c.black_share`
4. **School Type Details:** Separate analysis by denomination (Catholic, other Christian, non-sectarian)
5. **Distance Sensitivity:** Compare results across 1-mile, 3-mile, 5-mile, 10-mile buffers
6. **Population Weighting:** Weight regressions by PUMA population

## Contact

**For questions about this codebase:**

- **Author:** Myles Owens
- **Email:** myles.owens@stanford.edu
- **Institution:** Hoover Institution, Stanford University
- **GitHub:** https://github.com/maowens-HI/fl_private_school

**For AI assistance:**

- This CLAUDE.md file is your primary reference
- Check README.md for project overview
- Review code comments for implementation details
- Consult IPUMS documentation for variable definitions

## Version History

| Date | Update |
|------|--------|
| 2025-12-01 | Initial CLAUDE.md creation with comprehensive codebase documentation |

---

*This guide is maintained for AI assistants (like Claude) to effectively understand and work with the fl_private_school codebase. Keep it updated as the project evolves.*
