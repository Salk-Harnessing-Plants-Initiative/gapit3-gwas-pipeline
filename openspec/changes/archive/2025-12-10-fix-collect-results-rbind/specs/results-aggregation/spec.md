## ADDED Requirements

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

## REMOVED Requirements

### Requirement: Fallback to GWAS_Results when Filter file missing

**Reason**: The fallback approach is fundamentally flawed. Missing Filter file indicates incomplete GAPIT execution, not a legitimate state. Fallback masks data quality issues and causes technical problems (column mismatch in rbind). Traits missing Filter files should be retried, not approximated.

**Migration**: Before running aggregation, use `retry-argo-traits.sh --output-dir <path>` to detect and retry incomplete traits.
