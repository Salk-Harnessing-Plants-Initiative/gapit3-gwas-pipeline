# Spec: GAPIT Filter File Handling with Empty File Optimization

## ADDED Requirements

### Requirement: Aggregation must return empty immediately for Filter files without traits column

When a GAPIT Filter file exists but does not contain a `traits` column, the aggregation script MUST return an empty data.frame immediately without attempting to read GWAS_Results files.

**Rationale**: Filter files without a `traits` column indicate no significant SNPs were found. Reading GWAS_Results files (1.4M rows) to confirm this is unnecessary.

#### Scenario: Filter file exists with no traits column and no data

**Given** a trait directory containing:
- `GAPIT.Association.Filter_GWAS_results.csv` with header: `SNP,Chr,Pos,P.value,MAF,nobs,Effect,H.B.P.Value`
- No `traits` column in header
- No data rows (empty body)

**When** the aggregation script processes this trait

**Then** the script MUST:
- Detect the missing `traits` column
- Return an empty data.frame immediately
- NOT call `read_gwas_results_fallback()`
- NOT read any GWAS_Results files
- Complete in <0.1 seconds for this trait

#### Scenario: Multiple traits with empty Filter files

**Given** 186 trait directories
**And** 30 of them have Filter files without `traits` column (no significant SNPs)

**When** the aggregation script processes all 186 traits

**Then** the script MUST:
- Skip the 30 empty traits immediately (no fallback)
- Process the 156 non-empty traits normally
- Complete in <30 seconds total
- NOT read 30 × 2 × 1.4M = 84M unnecessary rows

---

### Requirement: Aggregation must preserve fallback for completely missing Filter files

When a Filter file does not exist at all, the aggregation script MUST fall back to reading GWAS_Results files to support backward compatibility with older GAPIT runs.

#### Scenario: Filter file completely missing

**Given** a trait directory containing:
- `GAPIT.Association.GWAS_Results.BLINK.trait_name.csv` (1.4M rows)
- NO `GAPIT.Association.Filter_GWAS_results.csv` file

**When** the aggregation script processes this trait

**Then** the script MUST:
- Detect the missing Filter file
- Call `read_gwas_results_fallback(trait_dir, threshold)`
- Read GWAS_Results files
- Filter for P.value < threshold
- Infer model from filename
- Return results with model column

---

### Requirement: Aggregation must handle Filter files with traits column but no rows

When a Filter file contains a `traits` column but has no data rows, the aggregation script MUST return an empty data.frame immediately.

#### Scenario: Filter file has traits column but no data

**Given** a trait directory containing:
- `GAPIT.Association.Filter_GWAS_results.csv` with header: `SNP,Chr,Pos,P.value,MAF,traits`
- Header includes `traits` column
- No data rows (empty body)

**When** the aggregation script processes this trait

**Then** the script MUST:
- Detect the `traits` column exists
- Detect nrow(filter_data) == 0
- Return empty data.frame immediately
- NOT attempt to parse model information
- Complete in <0.1 seconds

---

### Requirement: Aggregation must use informational messages instead of warnings for empty traits

When the aggregation script encounters a Filter file without a `traits` column, it MUST NOT emit a warning message, since this is expected behavior for traits with no significant SNPs.

#### Scenario: Console output for empty trait

**Given** a trait directory with Filter file lacking `traits` column

**When** the aggregation script processes this trait

**Then** the console output MUST NOT include:
- "Warning: Filter file missing 'traits' column"
- "Warning: using GWAS_Results fallback"

**And** the console output MAY optionally include:
- An informational note like "No significant SNPs found in trait_003"

---

## MODIFIED Requirements

### Requirement: Aggregation reads Filter files to extract significant SNPs

The aggregation script MUST read `GAPIT.Association.Filter_GWAS_results.csv` files to extract significant SNPs, and MUST handle both empty and populated Filter files efficiently.

**Previously**: Script read Filter files but always fell back to GWAS_Results when `traits` column was missing.

**Now**: Script returns empty immediately when Filter file lacks `traits` column, falling back to GWAS_Results only when Filter file is completely missing.

#### Scenario: Three-way branching logic

**Given** the aggregation script is processing a trait directory

**When** determining how to read SNP data

**Then** the script MUST follow this decision tree:

```
1. Filter file exists?
   ├─ NO  → Call read_gwas_results_fallback() (backward compatibility)
   └─ YES → Continue to step 2

2. Filter file has 'traits' column?
   ├─ NO  → Return empty data.frame (no significant SNPs)
   └─ YES → Continue to step 3

3. Filter file has data rows?
   ├─ NO  → Return empty data.frame
   └─ YES → Parse model from traits column, return data
```

---

## REMOVED Requirements

None. This change adds optimization without removing existing functionality.
