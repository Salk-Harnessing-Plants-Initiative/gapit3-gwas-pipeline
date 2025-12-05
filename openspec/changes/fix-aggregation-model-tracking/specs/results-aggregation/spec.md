# Spec: GAPIT Results Aggregation with Model Tracking

## ADDED Requirements

### Requirement: Aggregation must read GAPIT Filter files instead of complete GWAS_Results files

The aggregation script MUST read `GAPIT.Association.Filter_GWAS_results.csv` files which contain only significant SNPs instead of reading complete `GAPIT.Association.GWAS_Results.*.csv` files which contain all SNPs.

#### Scenario: Aggregating results from trait with Filter file

**Given** a trait directory containing:
- `GAPIT.Association.Filter_GWAS_results.csv` (5 rows: header + 4 significant SNPs)
- `GAPIT.Association.GWAS_Results.BLINK.trait_name.csv` (1,400,000 rows)

**When** the aggregation script processes this trait

**Then** the script MUST:
- Read `GAPIT.Association.Filter_GWAS_results.csv`
- NOT read `GAPIT.Association.GWAS_Results.BLINK.*.csv`
- Extract all 4 significant SNPs from Filter file
- Complete in <1 second for this trait

#### Scenario: Performance improvement for 186 traits with 2 models

**Given** 186 trait directories, each with BLINK and FarmCPU models
**And** each trait has ~5 significant SNPs on average

**When** the aggregation script processes all 186 traits

**Then** the script MUST:
- Read 186 Filter files (~1,000 total rows)
- NOT read 372 GWAS_Results files (~521M total rows)
- Complete in <30 seconds
- Use <2GB memory

---

### Requirement: Model information must be extracted from Filter file traits column

The aggregation script MUST parse the `traits` column in the Filter file to extract both the GAPIT model name and the trait name.

#### Scenario: Parsing standard model and trait name

**Given** a Filter file with row:
```csv
SNP,Chr,Pos,P.value,MAF,nobs,effect,H&B.P.Value,traits
SNP_123,1,12345,1.2e-9,0.15,500,0.05,2.3e-8,BLINK.root_length
```

**When** the script parses the `traits` column

**Then** the script MUST:
- Extract model: `"BLINK"` (everything before first period)
- Extract trait: `"root_length"` (everything after first period)
- Create columns: `model="BLINK"`, `trait="root_length"`
- Remove original `traits` column

#### Scenario: Parsing trait name with periods

**Given** a Filter file with `traits` value: `"BLINK.mean_GR_rootLength_day_1.2(NYC)"`

**When** the script parses the `traits` column

**Then** the script MUST:
- Extract model: `"BLINK"`
- Extract trait: `"mean_GR_rootLength_day_1.2(NYC)"` (preserving internal periods)
- NOT split on periods within trait name

---

### Requirement: Output CSV must include model column

The aggregated results CSV MUST include a `model` column indicating which GAPIT model identified each significant SNP.

#### Scenario: Output format with model column

**Given** aggregation of traits with BLINK and FarmCPU models

**When** the aggregated CSV is written

**Then** the output MUST have columns in this order:
```
SNP,Chr,Pos,P.value,MAF,nobs,effect,H&B.P.Value,trait,model
```

#### Scenario: SNP found by multiple models appears as multiple rows

**Given** a SNP at chr1:12345 found by BLINK (p=1.2e-9) and FarmCPU (p=2.3e-9)

**When** the aggregated CSV is created

**Then** the output MUST contain two rows:
```csv
SNP_123,1,12345,1.2e-9,0.15,500,0.05,2.3e-8,root_length,BLINK
SNP_123,1,12345,2.3e-9,0.15,500,0.06,3.1e-8,root_length,FarmCPU
```

---

### Requirement: Summary statistics must include per-model counts

The aggregation summary statistics MUST include counts of significant SNPs per model and identification of SNPs found by multiple models.

#### Scenario: Summary statistics for multi-model run

**Given** aggregated results with:
- 25 SNPs found only by BLINK
- 17 SNPs found only by FarmCPU
- 11 SNPs found by both models

**When** summary statistics are generated

**Then** `summary_stats.json` MUST include:
```json
{
  "snps_by_model": {
    "BLINK": 25,
    "FarmCPU": 28,
    "both_models": 11
  }
}
```

---

### Requirement: Aggregation must sort output by P.value

The aggregated results CSV MUST be sorted in ascending order by P.value.

#### Scenario: Output sorted by significance

**Given** aggregated SNPs with P.values: 5.2e-10, 1.2e-9, 3.4e-8, 8.7e-9

**When** the output CSV is written

**Then** rows MUST be sorted:
```
Row 1: P.value = 5.2e-10  (most significant)
Row 2: P.value = 1.2e-9
Row 3: P.value = 8.7e-9
Row 4: P.value = 3.4e-8
```

---

### Requirement: Fallback to GWAS_Results when Filter file missing

When `GAPIT.Association.Filter_GWAS_results.csv` does not exist, the aggregation script MUST fall back to reading GWAS_Results files with a warning.

#### Scenario: Filter file missing for a trait

**Given** a trait directory without `GAPIT.Association.Filter_GWAS_results.csv`
**And** directory contains `GAPIT.Association.GWAS_Results.BLINK.trait_name.csv`

**When** the aggregation script processes this trait

**Then** the script MUST:
- Detect Filter file is missing
- Emit warning: `"WARNING: Filter file missing for trait_XXX, using GWAS_Results fallback"`
- Read GWAS_Results file and filter for P.value < threshold
- Infer model from filename or set model="unknown"
- Continue processing remaining traits

---

### Requirement: Console output must report per-model statistics

The aggregation script console output MUST display per-model SNP counts.

#### Scenario: Console output for multi-model aggregation

**Given** aggregation with BLINK and FarmCPU models

**When** the script runs

**Then** console output MUST include:
```
Collecting significant SNPs...
  - Reading Filter files (fast mode)
  - Models detected: BLINK, FarmCPU
  - Total significant SNPs: 42
    - BLINK: 25 SNPs
    - FarmCPU: 28 SNPs
    - Found by both models: 11 SNPs
```

---

## MODIFIED Requirements

### Requirement: Results aggregation produces output CSV with complete SNP information

The aggregation script MUST produce a CSV file containing all significant SNPs from all traits with complete statistical information and model tracking.

**Previously**: Output CSV had columns: `SNP,Chr,Pos,P.value,MAF,nobs,effect,H&B.P.Value,trait` (missing model information)

**Now**: Output CSV has columns: `SNP,Chr,Pos,P.value,MAF,nobs,effect,H&B.P.Value,trait,model` (includes model column)

#### Scenario: Complete aggregated output format

**Given** aggregation of 186 traits with 2 models

**When** aggregation completes

**Then** the output file MUST:
- Be named: `all_traits_significant_snps.csv`
- Include `model` column as the last column
- Contain all significant SNPs from all traits
- Be sorted by P.value ascending
- Have one row per (SNP, model) combination

---

## REMOVED Requirements

None. This change adds functionality without removing existing features.