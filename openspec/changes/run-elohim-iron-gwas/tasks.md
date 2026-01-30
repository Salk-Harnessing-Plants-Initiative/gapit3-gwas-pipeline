# Tasks: Run Elohim Iron Deficiency GWAS Analysis

**Approach**: Systematic validation at each stage before proceeding.

**Status**: Phase 4 in progress with memory failures. Retry with ultra-highmem template pending.

## Phase 1: Data Validation ✅ COMPLETE

### 1.1 Validate Genotype File
- [x] Check file exists and is readable (4.2 GB)
- [x] Verify HapMap format (11 metadata + 546 sample columns = 557 total)
- [x] Count SNPs: **2,641,151**
- [x] Count samples: **546**
- [x] Diploid encoding verified (CC, AA, TT, etc.)

### 1.2 Validate Phenotype File
- [x] Check file exists and is readable (1.9 MB)
- [x] Verify column count: **187** (1 ID + 186 traits)
- [x] Count samples: 571 total (546 with genotype data)
- [x] First column is "Taxa"
- [x] Values are normalized (rank-based inverse normal transformation)

### 1.3 Validate Metadata File
- [x] Check accession IDs file exists
- [x] Count IDs: **546** (matches genotype exactly)
- [x] Header is "Taxa"

### 1.4 Cross-File Validation
- [x] Genotype-Phenotype overlap: **546 samples**
- [x] 25 phenotype-only samples (no genotype - will be filtered by GAPIT)
- [x] Metadata matches genotype IDs: 546/546
- [x] MAF calculation verified: 0.0073 = MAC >= 8 for 546 samples

## Phase 2: Environment Configuration ✅ COMPLETE

### 2.1 Create .env File for This Run
- [x] Created `.env` file at `Z:\users\eberrigan\20260104_...\\.env`
- [x] Set Docker image: `ghcr.io/salk-harnessing-plants-initiative/gapit3-gwas-pipeline:sha-539fe5c-test`
- [x] Set cluster data paths
- [x] Configure GAPIT parameters per colleague's specs:
  - MODEL=BLINK,FarmCPU,MLM
  - PCA_TOTAL=3
  - SNP_MAF=0.0073
  - SNP_FDR=0.05
  - SNP_THRESHOLD=0.05
  - MULTIPLE_ANALYSIS=TRUE
- [x] Set trait range (START_TRAIT=2, END_TRAIT=187)
- [x] Set MAX_CONCURRENT=10 (reduced for 96Gi high-memory jobs)
- [x] Created outputs directory
- [x] Validate configuration with dry-run

### 2.2 Verify Cluster Access
- [x] Confirm argo CLI is working
- [x] Check project quota and resources
- [x] Verify NFS mounts are accessible

## Phase 3: Test Run (Single Trait) ✅ COMPLETE

### 3.1 Submit Test Job
- [x] Submit single trait job (trait index 2)
- [x] **Used high-memory template (96Gi, 12 CPU)**
- [x] Monitor job progress

### 3.2 Validate Test Output
- [x] Job completed successfully (exit code 0)
- [x] Output directory created: `trait_2_<name>/`
- [x] GWAS result files present

### 3.3 Scientific Validation of Test Results
- [x] Manhattan plot looks reasonable
- [x] QQ plot shows expected pattern
- [x] P-values in expected range

## Phase 4: Full Pipeline Run 🔄 IN PROGRESS

### 4.1 Submit All Traits
- [x] Submit all 186 traits (indices 2-187)
- [x] **Workflow ID**: `gapit3-gwas-parallel-h5nzl`
- [x] **Started**: January 4, 2026, 09:12 PST
- [x] Template: `gapit3-single-trait-template-highmem` (96Gi RAM, 12 CPU)

### 4.2 Monitor Progress (Updated January 5, 09:25 PST)
| Status | Count | Percentage |
|--------|-------|------------|
| Succeeded | 78 | 42% |
| Failed (OOMKilled) | 76 | 41% |
| Running | 11 | 6% |
| Pending | 22 | 12% |

### 4.3 Handle Failures ⚠️ ACTION REQUIRED
- [x] Identified failed traits: **76 traits OOMKilled**
- [x] Root cause: 96Gi insufficient for 2.64M SNPs, need 160Gi
- [x] Documented in `add-ultra-highmem-template` proposal
- [ ] **Wait for current workflow to finish** (running + pending tasks)
- [ ] Create ultra-highmem template (160Gi RAM, 16 CPU)
- [ ] Apply template to cluster
- [ ] Retry failed traits with ultra-highmem template

### 4.4 Resource Impact Analysis
- **Memory requirement**: ~129 GB peak (formula: samples × SNPs × 8 × 5 / 1024³ × 1.5)
- **Per job**: 160 GB RAM + 16 CPU cores
- **Jobs per node**: 2 (CPU is limiting factor)
- **GPU blocking**: 10 parallel jobs → 5 nodes → 20 GPUs blocked (31% of cluster)

See [add-ultra-highmem-template](../add-ultra-highmem-template/proposal.md) for full analysis.

## Phase 5: Retry Failed Traits ⏳ PENDING

### 5.1 Create Ultra-Highmem Template
- [ ] Create `gapit3-single-trait-template-ultrahighmem.yaml`
- [ ] Memory: 160Gi request, 180Gi limit
- [ ] CPU: 16 request, 24 limit
- [ ] Apply to cluster

### 5.2 Submit Retry Workflow
- [ ] Use `/manage-workflow` to identify incomplete traits
- [ ] Generate retry workflow with ultra-highmem template
- [ ] Submit retry workflow
- [ ] Monitor for completion (~12-16 hours estimated)

### 5.3 Validate Retry Results
- [ ] All retried traits complete successfully
- [ ] No OOMKilled failures with 160Gi

## Phase 6: Results Aggregation ⏳ PENDING

### 6.1 Run Aggregation
- [ ] Wait for all trait jobs to complete (original + retry)
- [ ] Run aggregation script
- [ ] Generate combined results

### 6.2 Validate Aggregated Results
- [ ] All 186 traits represented
- [ ] No duplicate results
- [ ] Summary statistics reasonable

## Phase 7: Final Validation ⏳ PENDING

### 7.1 Quality Checks
- [ ] Spot-check several trait results
- [ ] Compare with previous runs (if available)
- [ ] Verify metadata completeness

### 7.2 Documentation
- [x] Record issues encountered (OOMKilled, memory escalation)
- [x] Document in status report: `docs/20260104_iron_gwas_normalized_status.md`
- [x] Document in session review: `docs/session_review_20260104.md`
- [x] GitHub issue created: #12
- [ ] Document final output location
- [ ] Notify colleague of completion

## File Locations

### Input Data (Cluster Paths)
```
/hpi/hpi_dev/users/eberrigan/20260104_Elohim_Bello_iron_deficiency_GAPIT_GWAS_normalized/data/
├── genotype/acc_snps_filtered_mac.recode_edited_diploid.hmp.txt
├── metadata/ids_gwas.txt
└── phenotype/iron_traits_edited_normal.txt
```

### Output Location
```
/hpi/hpi_dev/users/eberrigan/20260104_Elohim_Bello_iron_deficiency_GAPIT_GWAS_normalized/outputs/
├── trait_2_<name>/
├── trait_3_<name>/
...
├── trait_187_<name>/
└── aggregated/
```

## GAPIT Parameters Reference

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| MODEL | BLINK,FarmCPU,MLM | Three models for comparison |
| PCA_TOTAL | 3 | Population structure correction |
| SNP_MAF | 0.0073 | Equivalent to MAC >= 8 (8/546/2) |
| SNP_FDR | 0.05 | 5% FDR threshold |
| MULTIPLE_ANALYSIS | TRUE | Run all traits automatically |
| KINSHIP_ALGORITHM | Zhang | GAPIT default |
| SNP_EFFECT | Add | Additive model |
| SNP_IMPUTE | Middle | Mean imputation |
