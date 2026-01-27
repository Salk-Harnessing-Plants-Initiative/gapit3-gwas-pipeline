# Add Ultra High-Memory Template for Large GWAS Datasets

## Change ID
`add-ultra-highmem-template`

## Status
`proposed`

## Summary
Add a new WorkflowTemplate with 160Gi memory allocation for GWAS datasets with >2 million SNPs, addressing OOMKilled failures primarily in FarmCPU computations.

## Problem Statement

### Current Situation
The `gapit3-gwas-single-trait-highmem` template (96Gi request / 104Gi limit) is insufficient for running FarmCPU and MLM models on large datasets. During the `20260104_Elohim_Bello_iron_deficiency_GAPIT_GWAS_normalized` pipeline run, approximately **48% of traits (89/186)** failed with OOMKilled (exit code 137).

### Root Cause Analysis

**Key Finding**: FarmCPU is the primary failure point, not MLM as initially assumed.

Analysis of partial outputs from failed traits shows:
- ~80% failed during FarmCPU (BLINK outputs present, no FarmCPU outputs)
- ~20% failed during MLM (BLINK + FarmCPU outputs present, no MLM outputs)

The normalized dataset has significantly more SNPs than previous runs:

| Dataset | SNP Count | Genotype File | Memory Template | OOM Rate |
|---------|-----------|---------------|-----------------|----------|
| 20251110_Elohim (original) | 1,378,379 | 2.2 GB | 64Gi | ~5% |
| 20251122_Elohim (original) | 1,378,379 | 2.2 GB | 64Gi | ~5% |
| 20251208_Elohim (original) | 1,378,379 | 2.2 GB | 96Gi (highmem) | ~0% |
| **20260104_Elohim (normalized)** | **2,641,151** | **4.2 GB** | 96Gi (highmem) | **~48%** |

The normalized dataset has **1.9x more SNPs** (2.64M vs 1.38M).

### FarmCPU Memory Behavior

FarmCPU's Fixed Effect Model (FEM) + Random Effect Model (REM) iterative algorithm causes highly variable memory usage:

| Component | Size | Notes |
|-----------|------|-------|
| Genotype matrix | n × m × 8 bytes | Base storage (double precision) |
| Numeric conversion | 2× base | R creates copy during type conversion |
| FEM iteration copies | 1-3× base | Temporary matrices per iteration |
| Pseudo QTN kinship | n × t × 8 bytes | t = pseudo QTNs (typically 10-50) |
| Correlation matrices | Variable | LD-based, depends on significant regions |
| R overhead | ~20-30% | Garbage collection timing |

**The 8× Memory Problem**: Original FarmCPU publications reported lower memory requirements based on 1-byte character storage. However, when handling missing/imputed data (common in real datasets), R uses 8-byte doubles, requiring **8× more memory than originally reported**.

Reference: [FarmCPUpp: Efficient large-scale GWAS (Kusmec et al., 2018)](https://pmc.ncbi.nlm.nih.gov/articles/PMC6508500/)

### Trait-Specific Variation

FarmCPU memory usage varies significantly by trait due to:
1. **Number of pseudo QTNs**: Traits with complex genetic architecture identify more QTNs
2. **Iterations to convergence**: Simple traits converge in 3-4 iterations; complex traits may need 10+
3. **LD structure**: Dense LD blocks in significant regions require larger correlation matrices

**Empirical observation** (546 samples × 2.64M SNPs, 186 traits):
- ~52% of traits completed with 96 GB (highmem template)
- ~48% of traits failed at FarmCPU, requiring 160 GB (ultrahighmem template)

### Why This Is Not Sustainable
Each dataset iteration has increased SNP count:
- Original filtering (MAF-based): 1.38M SNPs
- New filtering (MAC-based, MAC ≥ 8): 2.64M SNPs

MAC-based filtering retains more rare variants, which is scientifically desirable but computationally expensive. Rather than repeatedly doubling memory, we need:
1. A proper tiered template system based on dataset size
2. Documentation of memory requirements per dataset characteristics
3. Validation tooling to estimate memory needs before submission

## Proposed Solution

### Immediate Fix
Create `gapit3-gwas-single-trait-ultrahighmem` template with:
- Memory request: 160Gi
- Memory limit: 180Gi
- CPU request: 16
- CPU limit: 24
- Threads: 16 (OPENBLAS_NUM_THREADS, OMP_NUM_THREADS)

### Resource Justification

#### Step 1: Memory Estimation

**FarmCPU Memory Formula** (conservative estimation):
```
FarmCPU Memory (GB) = Base × 3.25 × Safety

Where:
  Base = (Samples × SNPs × 8) / 1024³
  Safety = 1.3 for simple traits, 1.6 for complex traits
```

For the normalized dataset:
- Samples: 546
- SNPs: 2,641,151
- Base = (546 × 2,641,151 × 8) / 1024³ = **10.7 GB**
- Conservative (complex traits): 10.7 × 3.25 × 1.6 = **~56 GB typical, 100+ GB peak**

This explains why 104Gi limit fails for ~48% of traits. **160 GB** provides headroom for the most memory-intensive traits.

#### Step 2: CPU Requirements
GAPIT3 uses OpenBLAS for matrix operations. Optimal performance requires matching CPU threads to memory:
- 160 GB memory → 16 CPU cores (empirically determined ratio)
- Fewer cores = slower computation; more cores = no benefit (memory-bound)

**Per job: 160 GB RAM + 16 CPU cores**

#### Step 3: Jobs Per Node
Each Manticore node has:
- 512 GB RAM
- 32 CPU cores
- 4× NVIDIA A40 GPUs

For 160 GB + 16 CPU jobs:
- Memory constraint: 512 GB ÷ 160 GB = 3.2 jobs → **3 jobs per node**
- CPU constraint: 32 cores ÷ 16 cores = 2 jobs → **2 jobs per node**

**CPU is the limiting factor.** Each node can run only 2 jobs before CPUs are exhausted.

#### Step 4: GPU Blocking Impact
When GWAS jobs consume a node's CPU cores, the attached GPUs become unavailable:

| Parallel Jobs | CPU Cores Used | Nodes Occupied | GPUs Blocked |
|---------------|----------------|----------------|--------------|
| 6 jobs | 96 cores | 3 nodes | **12 GPUs** |
| 10 jobs | 160 cores | 5 nodes | **20 GPUs** |

**Running 10 parallel GWAS jobs blocks 20 of 64 cluster GPUs (31%)** from other users, even though we're not using GPUs at all.

This is a significant concern for a cluster designed primarily for GPU workloads.

### Template Tier System
| Template | Memory | Use Case |
|----------|--------|----------|
| `gapit3-gwas-single-trait` | 64Gi | <500K SNPs, <300 samples |
| `gapit3-gwas-single-trait-highmem` | 96Gi | 500K-1.5M SNPs, <600 samples |
| `gapit3-gwas-single-trait-ultrahighmem` | 160Gi | >1.5M SNPs or >600 samples |

## Acceptance Criteria

1. New template file created at `cluster/argo/workflow-templates/gapit3-single-trait-template-ultrahighmem.yaml`
2. Template applied to cluster successfully
3. `retry-argo-traits.sh` updated with `--ultrahighmem` flag
4. `/manage-workflow` skill updated to recognize ultra-highmem option
5. Documentation updated with memory selection guidelines
6. Failed traits from `gapit3-gwas-parallel-h5nzl` successfully complete with new template

## Impact

- **Affected specs**: `argo-workflow-configuration`
- **Affected code**:
  - `cluster/argo/workflow-templates/gapit3-single-trait-template-ultrahighmem.yaml` (new)
  - `scripts/retry-argo-traits.sh` (add --ultrahighmem flag)
  - `.claude/skills/manage-workflow.md` (update guidance)
  - `docs/RESOURCE_SIZING.md` (already updated with FarmCPU research)
  - `cluster/argo/README.md` (template tier table)

## Dependencies
- Requires `update-argo-workflows-v3` change (completed)
- Current workflow `gapit3-gwas-parallel-h5nzl` must complete first

## Risks
- **CPU contention**: Higher memory per job = 16 CPUs per job = only 2 jobs per node (vs 5 with highmem)
- **GPU blocking**: 10 parallel jobs occupy 5 nodes, blocking 20 GPUs (31% of cluster) from other users
- **Scheduling delays**: Large resource requests may wait longer in queue
- **Root cause unaddressed**: R memory inefficiency remains; future datasets may need even more memory

## Future Considerations
- Investigate memory-mapped file support in GAPIT
- Consider chunked processing for very large datasets
- Explore bigmemory R package for out-of-core computation
