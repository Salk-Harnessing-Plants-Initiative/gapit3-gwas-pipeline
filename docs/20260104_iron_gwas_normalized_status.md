# GWAS Pipeline Status Report: Iron Deficiency Normalized Dataset

**Date**: January 5, 2026 (Updated)
**Dataset**: `20260104_Elohim_Bello_iron_deficiency_GAPIT_GWAS_normalized`
**Prepared by**: GAPIT3 Pipeline Team

---

## Executive Summary

The GWAS analysis for the normalized iron deficiency dataset is in progress. Due to the significantly larger genotype file (MAC-based filtering vs MAF-based), approximately **49% of traits** require a retry with increased memory allocation. We estimate **completion by January 6, 2026**.

---

## Current Status (Updated January 5, 09:25 PST)

### Workflow Progress
- **Workflow ID**: `gapit3-gwas-parallel-h5nzl`
- **Started**: January 4, 2026, 09:12 PST
- **Duration**: 24 hours (1 day running)
- **Progress**: 80/166 tasks complete (indices 2-165 attempted)

### Task Breakdown (All 186 Traits)
| Status | Count | Percentage |
|--------|-------|------------|
| Succeeded | 78 | 42% |
| Failed (OOMKilled) | 76 | 41% |
| Running | 11 | 6% |
| Pending | 22 | 12% (traits 166-187) |

### Estimated Completion
- **Phase 1 (current workflow)**: ~4 more hours (finish by Jan 5, ~13:00 PST)
- **Phase 2 (retry ~85 failed traits with 160Gi)**: ~12-16 hours (depends on scheduler queue)
- **Total estimated completion**: **January 6, 2026, afternoon PST**

---

## Root Cause of Memory Failures

### Dataset Comparison
| Dataset | SNP Count | File Size | Memory Used | OOM Rate |
|---------|-----------|-----------|-------------|----------|
| Original (MAF-filtered) | 1,378,379 | 2.2 GB | 96 GB | ~0% |
| **Normalized (MAC-filtered)** | **2,641,151** | **4.2 GB** | **96 GB** | **~45%** |

### Technical Explanation
The normalized dataset uses **MAC-based filtering (MAC ≥ 8)** instead of MAF-based filtering. This retains more rare variants, which is scientifically desirable for detecting associations with low-frequency alleles.

**Memory impact**:
- The genotype matrix is **1.9× larger** (2.64M vs 1.38M SNPs)
- MLM (Mixed Linear Model) requires eigendecomposition of the full genotype matrix
- Peak memory usage exceeds the current 104 GB limit for traits with complete data (zero missing values)

### Why Some Traits Succeed
Traits that succeeded tend to have:
1. More missing phenotype values (smaller effective sample size)
2. Individual timepoint measurements (`_day_1`, `_day_2`) vs averages (`_avg`)
3. Lower heritability (faster MLM convergence, fewer iterations)

The `_avg` traits (averages across all days) have:
- Zero missing data (571 samples vs ~560 for daily measurements)
- Higher heritability (stronger genetic signal)
- More iterations required for MLM variance component estimation

---

## Remediation Plan

### Step 1: Create Ultra High-Memory Template (Ready)
- **Memory**: 160 GB (vs current 96 GB)
- **Justification**: 53% increase provides ~60% headroom over estimated peak
- **Cluster impact**: 3 jobs per node (vs 5), same total throughput

### Step 2: Wait for Current Workflow (In Progress)
- Let successful traits complete
- Failed traits will exhaust retries (3 attempts each)

### Step 3: Submit Retry Workflow
- Use `/manage-workflow` to identify incomplete traits
- Submit retry with ultra-highmem template
- Expected ~80-100 traits to retry

### Step 4: Final Aggregation
- Collect results from all 186 traits
- Generate summary statistics and Manhattan plots

---

## Analysis Parameters (Verified)

| Parameter | Value | Notes |
|-----------|-------|-------|
| Models | BLINK, FarmCPU, MLM | All three as specified |
| PCA Components | 3 | Population structure correction |
| MAF Threshold | 0.0073 | Equivalent to MAC ≥ 8 with 546 samples |
| FDR Threshold | 0.05 | Benjamini-Hochberg correction |
| Kinship Algorithm | Zhang | Default, efficient for large datasets |
| SNP Effect | Additive | Standard genetic model |
| SNP Imputation | Middle | Mean imputation for missing genotypes |

---

## Cluster Resource Impact

### Step 1: Memory Estimation

Peak memory for GAPIT3 MLM scales with dataset size:

```
Peak Memory (GB) ≈ (samples × SNPs × 8 bytes × 5) / (1024³) × 1.5
```

For this dataset:
- Samples: 546
- SNPs: 2,641,151
- Calculation: (546 × 2,641,151 × 8 × 5) / (1024³) × 1.5 = **~129 GB peak**

This exceeds the current 104 GB limit, requiring **160 GB** for safe headroom.

### Step 2: CPU Requirements

GAPIT3 uses OpenBLAS for matrix operations. Optimal performance requires matching CPU threads to memory:
- 160 GB memory → 16 CPU cores (empirically determined ratio)
- Fewer cores = slower computation; more cores = no benefit (memory-bound)

**Per job: 160 GB RAM + 16 CPU cores**

### Step 3: Jobs Per Node

Each Manticore node has:
- 512 GB RAM
- 32 CPU cores
- 4× NVIDIA A40 GPUs

For 160 GB + 16 CPU jobs:
- Memory constraint: 512 GB ÷ 160 GB = 3.2 jobs → **3 jobs per node**
- CPU constraint: 32 cores ÷ 16 cores = 2 jobs → **2 jobs per node**

**CPU is the limiting factor.** Each node can run only 2 jobs before CPUs are exhausted.

### Step 4: GPU Impact

When GWAS jobs consume a node's CPU cores, the attached GPUs become unavailable:

| Parallel Jobs | CPU Cores Used | Nodes Occupied | GPUs Blocked |
|---------------|----------------|----------------|--------------|
| 6 jobs | 96 cores | 3 nodes | **12 GPUs** |
| 10 jobs | 160 cores | 5 nodes | **20 GPUs** |

**Running 10 parallel GWAS jobs blocks 20 of 64 cluster GPUs (31%)** from other users, even though we're not using GPUs at all.

This is a significant concern for a cluster designed primarily for GPU workloads.

---

## Long-Term Sustainability

### Current Approach
Each dataset iteration has required memory increases:
- November 2025: 64 GB
- December 2025: 96 GB
- January 2026: 160 GB (proposed)

### Why This Is Not Sustainable
1. **Resource escalation**: Memory requirements have doubled twice in 3 months
2. **GPU blocking**: High CPU usage prevents other users from accessing GPUs
3. **Scheduler contention**: Large memory requests cause unpredictable queue delays
4. **Cluster purpose mismatch**: Manticore is optimized for GPU workloads, not CPU-intensive GWAS

### Recommendations
1. **Pre-submission memory estimation**: Add validation step to estimate memory needs based on SNP count
2. **Template selection guide**: Document which template to use based on dataset characteristics
3. **Consider alternatives for large GWAS**:
   - Dedicated CPU cluster (no GPU contention)
   - Cloud burst for peak workloads
   - Pre-filter SNPs to reduce dataset size before submission
4. **Future optimization**: Investigate memory-efficient R alternatives (chunked processing, memory-mapped files)

---

## Contact

For questions about this analysis:
- Pipeline issues: GitHub repository issues
- Data questions: Contact original dataset provider

---

*This report was generated as part of the GAPIT3 GWAS Pipeline project.*
