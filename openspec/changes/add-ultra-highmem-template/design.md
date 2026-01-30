# Design: Memory Requirements for GAPIT3 GWAS

## Key Finding: FarmCPU is the Primary Memory Bottleneck

Analysis of failed jobs from the `20260104_Elohim_normalized` workflow revealed:
- **~80% of OOMKilled failures occur during FarmCPU** (BLINK outputs present, no FarmCPU)
- ~20% fail during MLM (BLINK + FarmCPU outputs present, no MLM)

This contradicts the initial assumption that MLM was the primary failure point.

## FarmCPU Memory Model

### Algorithm Overview

FarmCPU (Fixed and random model Circulating Probability Unification) alternates between:
1. **FEM (Fixed Effect Model)**: Tests all SNPs with pseudo-QTN covariates
2. **REM (Random Effect Model)**: Optimizes pseudo-QTN kinship

```
Iteration 1: FEM tests all SNPs → identifies pseudo QTNs → REM optimizes
Iteration 2: FEM with pseudo QTN covariates → refines → REM optimizes
...
Iteration N: Converges when no new pseudo QTNs added
```

### The 8× Memory Problem

**Critical insight from research**: Original FarmCPU publications (Liu et al., 2016) reported memory requirements based on 1-byte character storage. However, when handling missing/imputed data (common in real datasets), R uses 8-byte doubles.

This means **actual memory usage is 8× higher than originally reported**.

Reference: [FarmCPUpp: Efficient large-scale GWAS (Kusmec et al., 2018)](https://pmc.ncbi.nlm.nih.gov/articles/PMC6508500/)

### FarmCPU Memory Components

| Component | Size | Notes |
|-----------|------|-------|
| Genotype matrix | n × m × 8 bytes | Base storage (double precision) |
| Numeric conversion | 2× base | R creates copy during type conversion |
| FEM iteration copies | 1-3× base | Temporary matrices per iteration |
| Pseudo QTN kinship | n × t × 8 bytes | t = pseudo QTNs (typically 10-50) |
| Correlation matrices | Variable | LD-based, depends on significant regions |
| R overhead | ~20-30% | Garbage collection timing |

### FarmCPU Memory Formula

```
FarmCPU Memory (GB) = Base × 3.25 × Safety

Where:
  Base = (Samples × SNPs × 8) / 1024³
  Safety = 1.3 for simple traits, 1.6 for complex traits
```

**Example** (546 samples × 2.64M SNPs):
- Base = 10.7 GB
- Simple trait: 10.7 × 3.25 × 1.3 = 45 GB
- Complex trait: 10.7 × 3.25 × 1.6 = **56 GB typical, 100+ GB peak**

### Trait-Specific Variation

FarmCPU memory usage varies significantly by trait due to:
1. **Number of pseudo QTNs**: Complex genetic architecture → more QTNs → more memory
2. **Iterations to convergence**: Simple traits (3-4 iter) vs complex traits (10+ iter)
3. **LD structure**: Dense LD blocks → larger correlation matrices

**Empirical observation** (546 samples × 2.64M SNPs, 186 traits):
- ~52% of traits completed with 96 GB (highmem template)
- ~48% of traits failed at FarmCPU, requiring 160 GB (ultrahighmem template)

## MLM Memory Model (Secondary Concern)

### Theoretical Formula
Peak memory usage for GAPIT3 MLM:

```
Peak Memory (GB) ≈ (samples × SNPs × 8 bytes × k) / (1024³)
```

Where:
- `samples`: Number of accessions after genotype/phenotype overlap
- `SNPs`: Number of markers in genotype file
- `8 bytes`: Size of R numeric (double precision)
- `k`: Overhead factor (typically 5-7× for MLM)

### MLM Overhead Factor Components
- **1.0x**: Base genotype matrix
- **0.5x**: Numeric conversion copy
- **0.5x**: Kinship matrix computation intermediates
- **0.3x**: EMMA/REML variance components
- **0.2x**: R garbage collection fragmentation

Total: ~2.5x base matrix size, plus kinship matrix O(n²)

### Worked Examples

| Dataset | Samples | SNPs | Base (GB) | Peak (GB) | Recommended |
|---------|---------|------|-----------|-----------|-------------|
| Small Arabidopsis | 200 | 200,000 | 0.3 | 0.8 | 2Gi |
| Medium panel | 400 | 500,000 | 1.5 | 3.8 | 8Gi |
| Elohim (original) | 546 | 1,378,379 | 5.5 | 14 | 32Gi |
| Elohim (normalized) | 546 | 2,641,151 | 11.5 | 29 | 64Gi |

### Observed vs Predicted

For Elohim normalized dataset:
- **Predicted peak**: 29 GB (base formula)
- **Observed OOM at**: 104 GB
- **Actual peak estimated**: 75-100 GB

The discrepancy is due to:
1. GAPIT creates multiple intermediate objects not freed immediately
2. MLM iterative optimization allocates per-iteration buffers
3. Three models (BLINK, FarmCPU, MLM) may have overlapping allocations
4. R's copy-on-modify semantics for large vectors

### Empirical Formula (Conservative)
Based on observations:

```
Safe Memory (GB) ≈ (samples × SNPs × 8 × 5) / (1024³) × 1.5
```

For Elohim normalized:
```
(546 × 2,641,151 × 8 × 5) / (1024³) × 1.5 = 86 GB × 1.5 = 129 GB
```

This aligns with needing >104 GB but <160 GB.

## Template Selection Decision Tree

```
Calculate: base_size = samples × SNPs × 8 / (1024³)

if base_size < 2 GB:
    use standard template (64Gi)
elif base_size < 6 GB:
    use highmem template (96Gi)
else:
    use ultrahighmem template (160Gi)
```

## Cluster Resource Impact

### Manticore Cluster Specifications
- **Nodes**: 16 total
- **Per node**: 512 GB RAM, 32 CPU cores, 4× NVIDIA A40 GPUs
- **Total GPUs**: 64

### Current Highmem (96Gi + 12 CPUs)
- Memory constraint: 512 GB ÷ 96 GB = 5.3 jobs → **5 jobs per node**
- CPU constraint: 32 cores ÷ 12 cores = 2.7 jobs → **2 jobs per node**
- Limiting factor: CPU
- With parallelism=10: 5 nodes utilized, 20 GPUs blocked

### Ultra-Highmem (160Gi + 16 CPUs)
- Memory constraint: 512 GB ÷ 160 GB = 3.2 jobs → **3 jobs per node**
- CPU constraint: 32 cores ÷ 16 cores = 2 jobs → **2 jobs per node**
- Limiting factor: CPU
- With parallelism=10: 5 nodes utilized, 20 GPUs blocked

### GPU Blocking Analysis

| Parallelism | Nodes Used | GPUs Blocked | % of Cluster GPUs |
|-------------|------------|--------------|-------------------|
| 4 jobs | 2 nodes | 8 GPUs | 12.5% |
| 6 jobs | 3 nodes | 12 GPUs | 18.8% |
| 10 jobs | 5 nodes | 20 GPUs | **31.3%** |

**Key insight**: Even though GWAS jobs don't use GPUs, they block GPU access for other users by consuming CPU cores on GPU-equipped nodes.

### Sustainability Concern

Memory requirements have doubled twice in 3 months:
- November 2025: 64 GB
- December 2025: 96 GB
- January 2026: 160 GB (proposed)

This trajectory is not sustainable. Future mitigations:
1. Pre-submission memory estimation based on SNP count
2. Off-cluster processing for very large datasets
3. Investigation of memory-efficient R alternatives

## Alternative Approaches Considered

### 1. Memory-Mapped Files (bigmemory R package)
- **Pros**: Near-unlimited dataset size
- **Cons**: GAPIT not designed for this; major code changes required
- **Decision**: Deferred to future work

### 2. Chunked SNP Processing
- **Pros**: Constant memory regardless of SNP count
- **Cons**: Kinship matrix requires all SNPs; MLM is inherently whole-genome
- **Decision**: Not feasible for MLM

### 3. Reduce Models (BLINK only)
- **Pros**: Lower memory, faster execution
- **Cons**: Loses MLM results which are often preferred for complex traits
- **Decision**: Not acceptable per user requirements

### 4. Reduce PCA Components
- **Pros**: Slight memory reduction
- **Cons**: Minimal impact; 3 PCAs is scientifically justified
- **Decision**: Not acceptable per user requirements

## Conclusion

The ultra-highmem template (160Gi) is the appropriate solution for datasets with >1.5M SNPs. This provides:
- Sufficient headroom for FarmCPU peak memory (the primary bottleneck)
- Support for complex traits with many pseudo-QTNs
- Efficient cluster utilization (2 jobs/node, CPU-limited)
- No changes to analysis parameters
- Clear selection criteria for future datasets

### References

- [FarmCPU Algorithm (Liu et al., 2016)](https://journals.plos.org/plosgenetics/article?id=10.1371/journal.pgen.1005767)
- [FarmCPUpp Memory Improvements (Kusmec et al., 2018)](https://pmc.ncbi.nlm.nih.gov/articles/PMC6508500/)
- [GAPIT3 Implementation (GitHub)](https://github.com/jiabowang/GAPIT/blob/master/R/GAPIT.FarmCPU.R)
