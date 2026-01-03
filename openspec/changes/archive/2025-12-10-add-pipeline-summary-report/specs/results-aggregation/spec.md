## ADDED Requirements

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
