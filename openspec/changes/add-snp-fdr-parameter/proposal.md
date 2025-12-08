## Why

Collaborators require FDR (Benjamini-Hochberg) controlled significance thresholds for reporting statistically significant SNPs in GWAS results. Currently the pipeline only supports fixed p-value thresholds (SNP_THRESHOLD), but GAPIT3 natively supports `SNP.FDR` for FDR-controlled analysis. This is needed for the iron traits project meeting on December 10th.

## What Changes

- Add `SNP_FDR` environment variable to `entrypoint.sh` (default: empty/disabled)
- Add `--snp-fdr` command-line argument to `run_gwas_single_trait.R`
- Pass `SNP.FDR` parameter to GAPIT() call when specified
- Update `.env.example` with documentation for `SNP_FDR`
- Log FDR threshold in runtime configuration output

## Impact

- Affected specs: `runtime-configuration` (from add-dotenv-configuration change)
- Affected code:
  - `scripts/entrypoint.sh` (add env var, pass to R script)
  - `scripts/run_gwas_single_trait.R` (add argument, pass to GAPIT)
  - `.env.example` (documentation)
- Backward compatible: Empty/unset `SNP_FDR` maintains current behavior
