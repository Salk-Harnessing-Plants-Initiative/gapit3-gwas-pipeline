# results-aggregation Specification

## Purpose

This spec defines the behavior of the GAPIT results aggregation script (`scripts/collect_results.R`), which collects significant SNPs from multiple trait analyses into a single summary output with model tracking.
## Requirements
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

### Requirement: Results aggregation produces output CSV with complete SNP information

The aggregation script MUST produce a CSV file containing all significant SNPs from all traits with complete statistical information and model tracking.

The output CSV has columns: `SNP,Chr,Pos,P.value,MAF,nobs,effect,H&B.P.Value,trait,model` (includes model column for filtering by GWAS model).

#### Scenario: Complete aggregated output format

**Given** aggregation of 186 traits with 2 models

**When** aggregation completes

**Then** the output file MUST:
- Be named: `all_traits_significant_snps.csv`
- Include `model` column as the last column
- Contain all significant SNPs from all traits
- Be sorted by P.value ascending
- Have one row per (SNP, model) combination

### Requirement: Fail-fast on incomplete traits

When `GAPIT.Association.Filter_GWAS_results.csv` does not exist for a trait, the aggregation script MUST fail with a clear error message by default. The Filter file is the definitive completion signal - GAPIT only creates it after ALL models finish successfully.

#### Scenario: Aggregation fails when any trait is incomplete

- **GIVEN** 185 trait directories where 181 have Filter files and 4 are missing Filter files
- **AND** the `--allow-incomplete` flag is NOT set
- **WHEN** the aggregation script runs
- **THEN** the script MUST:
  - NOT create any output files
  - Exit with code 1 (error)
  - Print error: `"ERROR: 4 traits are incomplete (missing Filter file)"`
  - List each incomplete trait directory
  - Suggest: `"Run retry-argo-traits.sh --output-dir <path> first, or use --allow-incomplete to skip."`

#### Scenario: Aggregation succeeds with all complete traits

- **GIVEN** 185 trait directories where ALL have Filter files
- **WHEN** the aggregation script runs
- **THEN** the script MUST:
  - Process all 185 traits
  - Create `all_traits_significant_snps.csv`
  - Create `summary_table.csv`
  - Exit with code 0 (success)

#### Scenario: Allow-incomplete flag skips incomplete traits with warning

- **GIVEN** 185 trait directories where 181 have Filter files and 4 are missing Filter files
- **AND** the `--allow-incomplete` flag IS set
- **WHEN** the aggregation script runs
- **THEN** the script MUST:
  - Emit warning for each incomplete trait: `"WARNING: Skipping trait_XXX (missing Filter file)"`
  - Process only the 181 complete traits
  - Create output files with partial results
  - Print summary: `"Aggregated 181 of 185 traits (4 skipped due to missing Filter file)"`
  - Exit with code 0 (success)

### Requirement: Aggregation must generate human-readable markdown summary report

The aggregation script MUST generate a `pipeline_summary.md` file alongside the existing JSON and CSV outputs, containing a formatted summary of the GWAS results suitable for sharing with scientific collaborators.

#### Scenario: Markdown report generated during successful aggregation

- **GIVEN** aggregation of 186 traits with BLINK, FarmCPU, and MLM models
- **AND** aggregation completes successfully producing `summary_stats.json` and `all_traits_significant_snps.csv`
- **WHEN** the aggregation script finishes
- **THEN** the script MUST:
  - Create `pipeline_summary.md` in the same directory as other outputs
  - Include executive summary with total traits, success rate, and total significant SNPs
  - Include top 20 SNPs table sorted by p-value
  - Include model statistics breakdown
  - Include reproducibility information (workflow ID, timestamp)
  - Complete markdown generation in <5 seconds

#### Scenario: Markdown report handles zero significant SNPs

- **GIVEN** aggregation of traits where no SNPs meet significance threshold
- **WHEN** the aggregation script finishes
- **THEN** the script MUST:
  - Create `pipeline_summary.md` with appropriate message
  - Executive summary shows "0 significant SNPs"
  - Top SNPs table shows "No significant SNPs found at threshold X"
  - Model statistics show all zeros
  - NOT fail or produce empty file

#### Scenario: Markdown can be regenerated from existing data

- **GIVEN** existing `summary_stats.json` and `all_traits_significant_snps.csv` files
- **AND** user runs aggregation with `--markdown-only` flag
- **WHEN** the script executes
- **THEN** the script MUST:
  - Read existing JSON and CSV files
  - Generate new `pipeline_summary.md`
  - NOT re-read trait directories
  - NOT modify existing JSON or CSV files

---

### Requirement: Markdown summary must include executive summary section

The markdown report MUST begin with an executive summary section providing at-a-glance statistics for quick assessment.

#### Scenario: Executive summary content for complete run

- **GIVEN** aggregation results with:
  - Workflow ID: `gapit3-gwas-parallel-6hjx8`
  - 186 traits, all successful
  - 1886 significant SNPs
  - Top hit: PERL1.8641002 with p-value 3.97e-88
- **WHEN** markdown report is generated
- **THEN** the executive summary MUST include:
  ```markdown
  ## Executive Summary

  | Metric | Value |
  |--------|-------|
  | Dataset | gapit3-gwas-parallel-6hjx8 |
  | Analysis Date | 2025-12-09 |
  | Total Traits | 186 |
  | Successful | 186 (100%) |
  | Failed | 0 |
  | Total Significant SNPs | 1,886 |
  | Top Hit | PERL1.8641002 (p = 3.97e-88) |
  | Top Trait | mean_TotLen.EucLen_day_1(NYC) (668 SNPs) |
  ```

#### Scenario: Executive summary with partial failures

- **GIVEN** aggregation with `--allow-incomplete` flag
- **AND** 181 successful traits, 5 skipped due to missing Filter files
- **WHEN** markdown report is generated
- **THEN** the executive summary MUST show:
  - Total Traits: 186
  - Successful: 181 (97.3%)
  - Failed/Skipped: 5
  - Warning note about incomplete traits

---

### Requirement: Markdown summary must include top SNPs table

The markdown report MUST include a table of the most significant SNPs sorted by p-value.

#### Scenario: Top 20 SNPs displayed in table format

- **GIVEN** 1886 significant SNPs across multiple traits
- **WHEN** markdown report is generated
- **THEN** the top SNPs section MUST:
  - Show heading "## Top Significant SNPs"
  - Display exactly 20 rows (or all if fewer than 20)
  - Include columns: Rank, SNP, Chr, Pos, P-value, MAF, Model, Trait
  - Sort by P-value ascending (most significant first)
  - Format p-values in scientific notation (e.g., "3.97e-88")
  - Truncate trait names longer than 40 characters with "..."
  - Include note: "Showing top 20 of 1,886 total significant SNPs"

#### Scenario: Top SNPs table with duplicate SNP across models

- **GIVEN** SNP PERL1.8641127 found by both BLINK and FarmCPU
- **WHEN** markdown report is generated
- **THEN** the table MUST:
  - Show each (SNP, model) combination as separate row
  - Display the model that found it with lower p-value first

---

### Requirement: Markdown summary must include model statistics

The markdown report MUST include a breakdown of significant SNPs by GWAS model.

#### Scenario: Model statistics for multi-model run

- **GIVEN** aggregation results with:
  - FarmCPU: 1345 SNPs
  - BLINK: 427 SNPs
  - MLM: 114 SNPs
  - Overlap (found by 2+ models): 198 SNPs
- **WHEN** markdown report is generated
- **THEN** the model statistics section MUST include:
  ```markdown
  ## Model Statistics

  | Model | SNPs Found | % of Total |
  |-------|------------|------------|
  | FarmCPU | 1,345 | 71.4% |
  | BLINK | 427 | 22.6% |
  | MLM | 114 | 6.0% |

  **Cross-Model Validation:** 198 SNPs (10.5%) found by multiple models
  ```

---

### Requirement: Markdown summary must include chromosome distribution

The markdown report MUST include a summary of significant SNPs by chromosome.

#### Scenario: Chromosome distribution table

- **GIVEN** significant SNPs distributed across 5 chromosomes:
  - Chr 4: 809 SNPs
  - Chr 1: 495 SNPs
  - Chr 5: 256 SNPs
  - Chr 2: 173 SNPs
  - Chr 3: 153 SNPs
- **WHEN** markdown report is generated
- **THEN** the chromosome section MUST include:
  ```markdown
  ## Chromosome Distribution

  | Chromosome | SNP Count | % of Total |
  |------------|-----------|------------|
  | 4 | 809 | 42.9% |
  | 1 | 495 | 26.2% |
  | 5 | 256 | 13.6% |
  | 2 | 173 | 9.2% |
  | 3 | 153 | 8.1% |
  ```

---

### Requirement: Markdown summary must include reproducibility information

The markdown report MUST include provenance information for FAIR compliance and reproducibility.

#### Scenario: Reproducibility block with full provenance

- **GIVEN** aggregation run with Argo workflow metadata available
- **WHEN** markdown report is generated
- **THEN** the reproducibility section MUST include:
  ```markdown
  ## Reproducibility

  | Field | Value |
  |-------|-------|
  | Workflow ID | gapit3-gwas-parallel-6hjx8 |
  | Workflow UID | abc123-def456-... |
  | Container Image | ghcr.io/talmo-lab/gapit3-gwas-pipeline:sha-xyz |
  | Collection Time | 2025-12-09 21:25:24 |
  | Aggregation Host | collector-pod-xyz |
  | R Version | R version 4.4.1 (2024-06-14) |
  | GAPIT Version | 3.5.0 |
  ```

#### Scenario: Reproducibility block with missing provenance

- **GIVEN** aggregation run outside Argo (local execution)
- **AND** workflow metadata not available
- **WHEN** markdown report is generated
- **THEN** the reproducibility section MUST:
  - Show "N/A" for unavailable fields
  - Still include available fields (collection time, R version)
  - NOT fail or omit the section entirely

---

### Requirement: Markdown generation can be disabled

The aggregation script MUST support a `--no-markdown` flag to skip markdown report generation.

#### Scenario: Skip markdown generation with flag

- **GIVEN** user runs aggregation with `--no-markdown` flag
- **WHEN** aggregation completes
- **THEN** the script MUST:
  - Create `summary_stats.json` and `all_traits_significant_snps.csv`
  - NOT create `pipeline_summary.md`
  - Print message: "Skipping markdown report generation (--no-markdown)"

