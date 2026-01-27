# Proposal: Run Elohim Iron Deficiency GWAS Analysis

## Why

Elohim Bello has prepared normalized phenotype data for iron deficiency traits in Arabidopsis. This GWAS analysis will identify genetic variants associated with 186 root traits under iron-deficient conditions. The colleague has provided specific GAPIT parameters optimized for this dataset.

## What Changes

This is an **operational run**, not a code change. We are:
- Validating the input data files for correctness
- Configuring GAPIT parameters per colleague's specifications
- Running a test workflow on a single trait to validate the pipeline
- Running the full pipeline (186 traits) after test validation
- **Retrying failed traits with ultra-highmem template (160Gi)** - ~45% of traits failed with OOMKilled
- Validating outputs for scientific accuracy

**No code changes required** - this uses the existing v3.0.0 pipeline with `expose-gapit-parameters`.

## Status Update (January 5, 2026)

### Initial Run Results
- **Workflow ID**: `gapit3-gwas-parallel-h5nzl`
- **Submitted**: January 4, 2026, 09:12 PST
- **Template**: `gapit3-single-trait-template-highmem` (96Gi RAM, 12 CPU)

### Current Progress
| Status | Count | Percentage |
|--------|-------|------------|
| Succeeded | 78 | 42% |
| Failed (OOMKilled) | 76 | 41% |
| Running | 11 | 6% |
| Pending | 22 | 12% |

### Root Cause of Failures
The normalized dataset uses MAC-based filtering (MAC ≥ 8) instead of MAF-based filtering, retaining **2,641,151 SNPs** (1.9× more than previous datasets). Memory estimation:

```
Peak Memory (GB) ≈ (546 samples × 2,641,151 SNPs × 8 bytes × 5) / (1024³) × 1.5 = ~129 GB
```

The 104 GB limit is insufficient. Traits with zero missing data (`_avg` traits with 571 samples) have higher effective sample sizes, pushing them over the limit.

### Remediation Plan
1. Wait for current workflow to complete (running/pending tasks)
2. Create ultra-highmem template (160Gi RAM, 16 CPU) - see `add-ultra-highmem-template` proposal
3. Retry ~85 failed traits with new template
4. Aggregate results from all 186 traits

### Resource Impact
- **Per job**: 160 GB RAM + 16 CPU cores
- **Jobs per node**: 2 (CPU is limiting factor, not memory)
- **GPU blocking**: 10 parallel jobs occupy 5 nodes, blocking 20 GPUs (31% of cluster)

See [add-ultra-highmem-template](../add-ultra-highmem-template/proposal.md) for full resource analysis.

## Impact

- Affected specs: None (operational run)
- Affected data: New dataset at `/hpi/hpi_dev/users/eberrigan/20260104_Elohim_Bello_iron_deficiency_GAPIT_GWAS_normalized/`
- Resources: ~186 trait jobs on Argo Workflows cluster
- **Estimated completion**: January 6, 2026 afternoon PST

---

## Dataset Details

### Source
- Colleague: Elohim Bello
- Box link: https://salkinstitute.box.com/s/0wsr0a4re7otz5a7d5nk12delzz0bn3w

### Files

| File | Description | Size |
|------|-------------|------|
| `genotype/acc_snps_filtered_mac.recode_edited_diploid.hmp.txt` | 546 accessions x 2,641,151 SNPs (MAC >= 8) | ~4.2 GB |
| `metadata/ids_gwas.txt` | Accession IDs for filtering | 2.7 KB |
| `phenotype/iron_traits_edited_normal.txt` | 186 normalized root traits (rank-based inverse normal) | 1.9 MB |

### Path Mapping

| Context | Path |
|---------|------|
| Windows | `Z:\users\eberrigan\20260104_Elohim_Bello_iron_deficiency_GAPIT_GWAS_normalized\data` |
| WSL | `/mnt/hpi_dev/users/eberrigan/20260104_Elohim_Bello_iron_deficiency_GAPIT_GWAS_normalized/data` |
| Cluster | `/hpi/hpi_dev/users/eberrigan/20260104_Elohim_Bello_iron_deficiency_GAPIT_GWAS_normalized/data` |

## GAPIT Parameters (from colleague)

```bash
# Per Elohim's specifications:
MODEL=BLINK,FarmCPU,MLM           # Three models for comparison
PCA_TOTAL=3                        # 3 principal components
SNP_MAF=0.0073                     # Equivalent to MAC >= 8 (8/546/2 = 0.0073)
SNP_FDR=0.05                       # 5% FDR threshold (BH correction)
MULTIPLE_ANALYSIS=TRUE             # Run all traits automatically
```

**Note**: These differ from GAPIT defaults:
- `PCA_TOTAL=3` (GAPIT default: 0)
- `SNP_MAF=0.0073` (GAPIT default: 0)
- `SNP_FDR=0.05` (GAPIT default: disabled)
- `MODEL=BLINK,FarmCPU,MLM` (GAPIT default: MLM only)

## Validation Checklist

### Pre-Run Validation
- [ ] Genotype file readable and has expected dimensions
- [ ] Phenotype file has correct number of traits (187 columns: ID + 186 traits)
- [ ] Accession IDs match between files
- [ ] SNP_MAF=0.0073 corresponds to MAC >= 8

### Test Run Validation (Single Trait)
- [ ] Job completes without errors
- [ ] Output files generated in expected structure
- [ ] Manhattan plot generated
- [ ] QQ plot generated
- [ ] Significant SNPs file created
- [ ] Metadata JSON has correct parameters

### Full Run Validation
- [ ] All 186 trait jobs complete
- [ ] No failed jobs
- [ ] Aggregation produces combined results
- [ ] Results ready for scientific review

## Success Criteria

1. Test run on trait index 2 completes successfully
2. Output structure matches expected format
3. GAPIT parameters recorded correctly in metadata
4. Full pipeline runs 186 traits without failures
5. Results validated for scientific accuracy
