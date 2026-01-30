# Tasks: Add Ultra High-Memory Template

## Phase 1: Template Creation

### 1.1 Create ultra-highmem template
- [x] Copy `gapit3-single-trait-template-highmem.yaml` to `gapit3-single-trait-template-ultrahighmem.yaml`
- [x] Update template name to `gapit3-gwas-single-trait-ultrahighmem`
- [x] Update memory request to 160Gi
- [x] Update memory limit to 180Gi
- [x] Update CPU request to 16
- [x] Update CPU limit to 24
- [x] Update header comments to document use case
- [x] Validate YAML syntax

### 1.2 Apply template to cluster
- [x] Run `kubectl apply -f` for new template
- [x] Verify template appears in `kubectl get workflowtemplates`

## Phase 2: Tooling Updates

### 2.1 Update retry-argo-traits.sh
- [x] Add `--ultrahighmem` flag option (160Gi/16 CPU)
- [x] Update help text with memory tier guidance
- [x] Update template selection logic for three tiers (standard, highmem, ultrahighmem)
- [x] Fix parameter extraction for v3.0.0 naming (`model` not `models`)
- [x] Extract and propagate file path parameters (`genotype-file`, `phenotype-file`, `accession-ids-file`)
- [x] Extract additional GAPIT parameters (`pca-total`, `snp-maf`, `kinship-algorithm`, `snp-effect`, `snp-impute`)
- [x] Pass all extracted parameters to generated retry workflow YAML

### 2.3 Add parallelism configuration (spec: argo-workflow-configuration)
- [x] Add `--parallelism N` CLI flag to argument parsing
- [x] Set template-specific defaults (standard/highmem: 10, ultrahighmem: 5)
- [x] Use user-specified value or template default in YAML generation
- [x] Display parallelism in dry-run output (default vs user-specified)

### 2.2 Update manage-workflow.md skill
- [x] Add ultra-highmem option to resource table
- [x] Update remediation guidance for large datasets
- [x] Add memory estimation output for OOMKilled failures

## Phase 3: Documentation

### 3.1 Update cluster/argo/README.md
- [x] Add template tier table with memory guidelines
- [x] Document SNP count thresholds for template selection

### 3.2 Create memory estimation guide
- [x] Document memory formula: `samples × SNPs × 8 × 5` (documented in README and manage-workflow.md)
- [x] Add examples for different dataset sizes
- [x] Link from validate-data skill (guidance in manage-workflow.md)

## Phase 4: Retry Failed Traits

### 4.1 Wait for current workflow to complete
- [x] Monitor `gapit3-gwas-parallel-h5nzl` until all retries exhausted (98 complete, 88 incomplete)

### 4.2 Submit retry workflow
- [x] Use retry-argo-traits.sh to identify failed traits (88 traits missing Filter file)
- [x] Submit retry with `--ultrahighmem` flag → `gapit3-gwas-retry-h5nzl-n7qs5`
- [ ] Monitor until completion
- [ ] Verify all 186 traits have complete outputs

## Phase 5: Validation

### 5.1 Validate results
- [ ] Check Filter files exist for all traits
- [ ] Verify GWAS results for BLINK, FarmCPU, MLM
- [ ] Run aggregation if not already done

## Dependencies

- `update-argo-workflows-v3` (completed)
- Current workflow must finish before retry
