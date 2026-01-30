# GitHub Issue: Pipeline Improvements

**Title**: Pipeline Improvements: Memory Estimation, Template Selection, and Retry Workflow Updates

**Labels**: enhancement

---

## Summary

During the January 2026 iron deficiency GWAS run, we encountered OOMKilled failures on ~45% of traits due to the normalized dataset having 1.9x more SNPs than the original. This issue tracks improvements to prevent similar issues in future runs.

## Background

- **Dataset**: `20260104_Elohim_Bello_iron_deficiency_GAPIT_GWAS_normalized`
- **Problem**: MAC-based filtering (MAC >= 8) retained 2.64M SNPs vs 1.38M with MAF filtering
- **Impact**: 96Gi memory insufficient; need 160Gi for MLM with large datasets
- **Reference**: See `docs/session_review_20260104.md` for full analysis

## High Priority Tasks

### 1. Create Ultra High-Memory Template
- [ ] Create `gapit3-single-trait-template-ultrahighmem.yaml`
- [ ] Memory: 160Gi request, 180Gi limit
- [ ] CPU: 16 request, 24 limit
- [ ] Apply to cluster

### 2. Update retry-argo-traits.sh
- [ ] Add `--ultrahighmem` flag
- [ ] Fix parameter extraction for v3.0.0 naming (`model` not `models`)
- [ ] Extract and propagate file path parameters (`genotype-file`, `phenotype-file`, `accession-ids-file`)
- [ ] Add memory estimation to output

### 3. Add Memory Estimation to Validation
- [ ] Update `/validate-data` skill to extract SNP count
- [ ] Calculate memory estimate: `samples × SNPs × 8 × 5 / 1024³ × 1.5`
- [ ] Recommend template based on dataset size

## Medium Priority Tasks

### 4. Documentation Updates
- [ ] Create template selection guide in `cluster/argo/README.md`
- [ ] Add memory considerations to `docs/DATA_REQUIREMENTS.md`
- [ ] Document MAC vs MAF filtering impact on resources

### 5. Claude Skills Updates
- [ ] Update `/manage-workflow` with ultra-highmem option
- [ ] Improve OOMKilled failure analysis
- [ ] Create `/estimate-memory` skill

## Low Priority Tasks

### 6. CI/CD Improvements
- [ ] Add template YAML validation to CI
- [ ] Add parameter consistency checks across templates
- [ ] Add retry script unit tests

### 7. Pre-submission Validation
- [ ] Add genotype file size check before workflow submission
- [ ] Warn if dataset size exceeds template capacity

## Template Selection Guide (Proposed)

| SNP Count | Base Memory | Recommended Template |
|-----------|-------------|---------------------|
| < 500K | < 2 GB | standard (64Gi) |
| 500K - 1.5M | 2-6 GB | highmem (96Gi) |
| > 1.5M | > 6 GB | ultrahighmem (160Gi) |

## Memory Estimation Formula

```
Peak Memory (GB) ≈ (samples × SNPs × 8 × 5) / (1024³) × 1.5
```

Example for Elohim normalized dataset:
```
(546 × 2,641,151 × 8 × 5) / (1024³) × 1.5 = 86 GB × 1.5 = 129 GB
```

This confirms need for >104Gi (current highmem limit) but <160Gi (proposed ultrahighmem).

## Related

- OpenSpec change: `add-ultra-highmem-template`
- Workflow: `gapit3-gwas-parallel-h5nzl`
- Session review: `docs/session_review_20260104.md`

---

**To create this issue manually:**
1. Go to https://github.com/salk-harnessing-plants-initiative/gapit3-gwas-pipeline/issues/new
2. Copy content above
3. Add label: `enhancement`
