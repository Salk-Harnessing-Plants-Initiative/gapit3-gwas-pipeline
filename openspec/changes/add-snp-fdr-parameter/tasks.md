## 1. Implementation

- [x] 1.1 Add `SNP_FDR` environment variable to `scripts/entrypoint.sh` with empty default
- [x] 1.2 Add `--snp-fdr` argument to R script option parser in `scripts/run_gwas_single_trait.R`
- [x] 1.3 Pass `SNP.FDR` parameter to GAPIT() call when value is provided
- [x] 1.4 Add FDR threshold to runtime configuration logging in entrypoint.sh
- [x] 1.5 Add FDR threshold to R script runtime logging
- [x] 1.6 Add metadata tracking for FDR parameter

## 2. Documentation

- [x] 2.1 Update `.env.example` with `SNP_FDR` documentation
- [x] 2.2 Update help text in entrypoint.sh

## 3. Testing

- [ ] 3.1 Test pipeline with SNP_FDR=0.05
- [ ] 3.2 Test pipeline without SNP_FDR (backward compatibility)
- [ ] 3.3 Verify GAPIT output includes FDR-filtered results
