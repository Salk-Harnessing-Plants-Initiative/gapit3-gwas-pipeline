# Resource Sizing Guide

This guide explains how to determine appropriate computational resources for your GWAS dataset.

> **Reference Dataset**: Examples below reference a 546-sample, 2.64M SNP dataset. Scale recommendations according to your data.

---

## Table of Contents

1. [Quick Reference](#quick-reference)
2. [Memory Estimation](#memory-estimation)
3. [Model-Specific Memory Behavior](#model-specific-memory-behavior)
4. [CPU Allocation](#cpu-allocation)
5. [Disk Space](#disk-space)
6. [Choosing Templates](#choosing-templates)
7. [Troubleshooting OOMKilled](#troubleshooting-oomkilled)

---

## Quick Reference

| Dataset Size | Samples | SNPs | Recommended Memory | CPU |
|--------------|---------|------|-------------------|-----|
| Small | < 200 | < 500K | 16-24 GB | 4 |
| Medium | 200-600 | 500K-2M | 32-48 GB | 8-12 |
| Large | 600-1000 | 2M-5M | 64-96 GB | 12-16 |
| Very Large | > 1000 | > 5M | 128+ GB | 16+ |

---

## Memory Estimation

### Base Formula

Memory requirements depend primarily on the genotype matrix size:

```
Base Memory = (Samples × SNPs × 8 bytes) / (1024³) GB
```

**Example**: 546 samples × 1,400,000 SNPs × 8 bytes ≈ 6.1 GB for the raw matrix.

### Overhead Multipliers

GAPIT3 creates multiple copies of data during processing. Apply these multipliers:

| Model | Multiplier | Notes |
|-------|------------|-------|
| BLINK | 3-4× | Efficient, lowest memory |
| FarmCPU | 4-5× | Moderate overhead |
| MLM | 5-7× | Kinship matrix calculation |
| MLMM | 6-8× | Multiple loci tracking |

### Practical Formula

For most use cases:

```
Recommended Memory = (Samples × SNPs × 8 × 5) / (1024³) + 8 GB
```

The `+ 8 GB` accounts for:
- R runtime overhead
- Intermediate results
- Output file generation

### Memory Examples

| Samples | SNPs | Base Matrix | Recommended (BLINK) | Recommended (FarmCPU) | Recommended (MLM) |
|---------|------|-------------|---------------------|----------------------|-------------------|
| 200 | 500,000 | 0.8 GB | 12 GB | 16 GB | 20 GB |
| 500 | 1,000,000 | 4.0 GB | 24 GB | 40 GB | 56 GB |
| 546 | 2,640,000 | 10.7 GB | 48 GB | **96-160 GB** | 96-128 GB |
| 1000 | 2,000,000 | 16.0 GB | 72 GB | 128 GB | 160+ GB |

---

## Model-Specific Memory Behavior

Understanding how each GAPIT model uses memory helps predict resource requirements and troubleshoot failures.

### BLINK (Fastest, Most Memory-Efficient)

BLINK uses a Bayesian-information and Linkage-disequilibrium Iteratively Nested Keyway approach:

- **Memory complexity**: O(n) - linear with samples
- **Key advantage**: Does not build full kinship matrix
- **Typical overhead**: 3-4× base matrix
- **Failure rate**: Very low (almost never OOMKilled)

BLINK is recommended as the baseline model and will almost always complete successfully.

### FarmCPU (Moderate Speed, Variable Memory)

FarmCPU (Fixed and random model Circulating Probability Unification) alternates between Fixed Effect Model (FEM) and Random Effect Model (REM):

#### Algorithm Overview

```
Iteration 1: FEM tests all SNPs → identifies pseudo QTNs → REM optimizes
Iteration 2: FEM with pseudo QTN covariates → refines → REM optimizes
...
Iteration N: Converges when no new pseudo QTNs added
```

#### Memory Components

| Component | Size | Notes |
|-----------|------|-------|
| Genotype matrix | n × m × 8 bytes | Base storage (double precision) |
| Numeric conversion | 2× base | R creates copy during type conversion |
| FEM iteration copies | 1-3× base | Temporary matrices per iteration |
| Pseudo QTN kinship | n × t × 8 bytes | t = number of pseudo QTNs (typically 10-50) |
| Correlation matrices | Variable | LD-based, depends on significant regions |
| R overhead | ~20-30% | Garbage collection timing |

#### The 8× Memory Problem

**Important**: Original FarmCPU publications reported lower memory requirements based on 1-byte storage. However, when handling missing/imputed data (common in real datasets), R uses 8-byte doubles, requiring **8× more memory than originally reported**.

Reference: [FarmCPUpp: Efficient large-scale GWAS (Kusmec et al., 2018)](https://pmc.ncbi.nlm.nih.gov/articles/PMC6508500/)

#### Trait-Specific Variation

FarmCPU memory usage varies significantly by trait due to:

1. **Number of pseudo QTNs**: Traits with complex genetic architecture identify more QTNs
2. **Iterations to convergence**: Simple traits converge in 3-4 iterations; complex traits may need 10+
3. **LD structure**: Dense LD blocks in significant regions require larger correlation matrices

**Empirical observation** (546 samples × 2.64M SNPs, 186 traits):
- ~52% of traits completed with 96 GB (highmem template)
- ~48% of traits failed at FarmCPU, requiring 160 GB (ultrahighmem template)

#### FarmCPU Memory Formula

For conservative estimation:

```
FarmCPU Memory (GB) = Base × 3.25 × Safety

Where:
  Base = (Samples × SNPs × 8) / 1024³
  Safety = 1.3 for simple traits, 1.6 for complex traits
```

**Example** (546 samples × 2.64M SNPs):
- Base = 10.7 GB
- Conservative (complex traits): 10.7 × 3.25 × 1.6 = **56 GB typical, 100+ GB peak**

### MLM (Slowest, Memory-Intensive)

Mixed Linear Model computes a full kinship matrix:

- **Memory complexity**: O(n²) for kinship matrix
- **Key cost**: n × n kinship matrix storage and inversion
- **Typical overhead**: 5-7× base matrix
- **Failure pattern**: Usually fails after BLINK and FarmCPU complete

#### MLM Memory Formula

```
MLM Memory (GB) = Base × 5 + Kinship

Where:
  Base = (Samples × SNPs × 8) / 1024³
  Kinship = (Samples² × 8) / 1024³
```

**Example** (546 samples × 2.64M SNPs):
- Base = 10.7 GB
- Kinship = 0.002 GB (negligible for small sample sizes)
- Total ≈ 10.7 × 5 = **54 GB typical**

For larger sample sizes (>2000), the kinship matrix becomes significant.

### Model Execution Order

GAPIT runs models in this order: **BLINK → FarmCPU → MLM**

When a job is OOMKilled, check which model outputs exist to identify the bottleneck:

```bash
# Check partial outputs for a failed trait
ls outputs/trait_XXX_*/GAPIT.*.GWAS.Results.*.csv | grep -oE "(BLINK|FarmCPU|MLM)" | sort -u
```

| Outputs Present | Failed At | Solution |
|-----------------|-----------|----------|
| None | Data loading or BLINK | Increase memory significantly |
| BLINK only | FarmCPU | Use ultrahighmem (160 GB) |
| BLINK + FarmCPU | MLM | Use ultrahighmem or run MLM separately |
| All three | Post-processing | Check disk space |

### References

- [FarmCPU Algorithm (Liu et al., 2016)](https://journals.plos.org/plosgenetics/article?id=10.1371/journal.pgen.1005767)
- [FarmCPUpp Memory Improvements (Kusmec et al., 2018)](https://pmc.ncbi.nlm.nih.gov/articles/PMC6508500/)
- [GAPIT3 Implementation (GitHub)](https://github.com/jiabowang/GAPIT/blob/master/R/GAPIT.FarmCPU.R)

---

## CPU Allocation

### Thread Settings

The pipeline uses OpenBLAS for linear algebra operations:

```bash
OPENBLAS_NUM_THREADS=12  # Default in .env.example
```

### CPU Recommendations

| Dataset Size | CPUs | Reasoning |
|--------------|------|-----------|
| Small | 4 | Limited parallelization benefit |
| Medium | 8-12 | Good balance of speed and utilization |
| Large | 12-16 | Benefits from parallel matrix operations |

### Diminishing Returns

Adding more CPUs beyond 16 typically shows diminishing returns for GWAS analysis. The bottleneck shifts to memory bandwidth rather than compute.

---

## Disk Space

### Per-Trait Output

Each trait analysis generates approximately:

| File Type | Size | Count per Trait |
|-----------|------|-----------------|
| Manhattan plots | 200-500 KB | 1 per model |
| QQ plots | 100-200 KB | 1 per model |
| GWAS Results CSV | 50-200 MB | 1 per model |
| Filter CSV | 1-50 KB | 1 per model |
| Metadata JSON | 2-5 KB | 1 |

### Total Estimate

```
Disk Space = Traits × Models × 200 MB + 1 GB (aggregated results)
```

**Example**: 184 traits × 2 models × 200 MB = ~74 GB

### Recommendations

| Traits | Models | Recommended Disk |
|--------|--------|-----------------|
| 10-50 | 2 | 25 GB |
| 50-100 | 2-3 | 75 GB |
| 100-200 | 2-3 | 150 GB |
| 200+ | 2-3 | 250+ GB |

---

## Choosing Templates

The pipeline provides three memory tiers. Select based on your dataset characteristics and model requirements.

### Standard Template (64 GB)

Use the standard template when:
- Dataset has < 300 samples
- SNP count < 1.5 million
- Running BLINK only
- Memory requirement < 50 GB

```yaml
# cluster/argo/workflow-templates/gapit3-single-trait-template.yaml
resources:
  requests:
    memory: "64Gi"
    cpu: "12"
  limits:
    memory: "72Gi"
    cpu: "16"
```

### High-Memory Template (96 GB)

Use the highmem template when:
- Dataset has 300-600 samples
- SNP count 1.5-2.5 million
- Running BLINK + FarmCPU
- Some traits may still fail (plan for retry)

```yaml
# cluster/argo/workflow-templates/gapit3-single-trait-template-highmem.yaml
resources:
  requests:
    memory: "96Gi"
    cpu: "16"
  limits:
    memory: "104Gi"
    cpu: "20"
```

### Ultra-High-Memory Template (160 GB)

Use the ultrahighmem template when:
- Dataset has > 500 samples with > 2M SNPs
- Running all three models (BLINK + FarmCPU + MLM)
- Retrying traits that failed with highmem
- Complex traits with many pseudo QTNs

```yaml
# cluster/argo/workflow-templates/gapit3-single-trait-template-ultrahighmem.yaml
resources:
  requests:
    memory: "160Gi"
    cpu: "16"
  limits:
    memory: "180Gi"
    cpu: "20"
```

**Warning**: Ultrahighmem uses significant cluster resources (~2 jobs per node, blocking GPUs).

### Template Selection Flowchart

```
Start
  │
  ├─ SNPs > 2.5M AND Samples > 500? ──Yes──> Ultra-High-Memory (160 GB)
  │        │
  │        No
  │        │
  ├─ SNPs > 1.5M? ──Yes──┬─ Using MLM? ──Yes──> Ultra-High-Memory (160 GB)
  │        │             │        │
  │        │             │        No
  │        │             │        │
  │        │             └─────────────────────> High-Memory (96 GB)
  │        │
  │        No
  │        │
  ├─ Using FarmCPU + MLM? ──Yes──> High-Memory (96 GB)
  │        │
  │        No
  │        │
  └─ Standard Template (64 GB)
```

### Retry Strategy

For large datasets, use a tiered approach:

1. **First run**: Use highmem template for all traits
2. **Identify failures**: Check for OOMKilled exits (code 137)
3. **Retry with ultrahighmem**: Rerun only failed traits

```bash
# Example: Retry failed traits with ultrahighmem
./scripts/submit-failed-traits.sh --template ultrahighmem --traits "5,6,7,12,17,..."
```

This approach optimizes cluster utilization while ensuring all traits complete.

---

## Troubleshooting OOMKilled

### Identifying OOMKilled

When a pod runs out of memory, Kubernetes terminates it with exit code 137:

```bash
# Check workflow status
argo get <workflow-name> -n runai-talmo-lab | grep "OOMKilled"

# Or via kubectl
kubectl get pods -n runai-talmo-lab -l workflows.argoproj.io/workflow=<workflow-name>
kubectl describe pod <pod-name> -n runai-talmo-lab | grep -A5 "Last State"
```

### Diagnose Which Model Failed

Check partial outputs to identify the bottleneck:

```bash
# For a failed trait, check which models completed
ls outputs/trait_XXX_*/*.csv | grep -oE "(BLINK|FarmCPU|MLM)" | sort -u

# Expected output interpretation:
# - Empty: Failed during data loading
# - "BLINK": Failed at FarmCPU
# - "BLINK FarmCPU": Failed at MLM
# - "BLINK FarmCPU MLM": Failed during post-processing
```

### Solutions by Failure Point

#### Failed at Data Loading (no outputs)

Memory insufficient for genotype matrix loading:
- Use ultrahighmem template (160 GB)
- Check genotype file size (should be < 5 GB for highmem)

#### Failed at FarmCPU (BLINK completed)

Most common failure point. FarmCPU's iterative algorithm exceeded memory:

1. **Use ultrahighmem template** (first choice)
2. **Run FarmCPU separately** with more memory
3. **Skip FarmCPU**: Use `MODELS=BLINK,MLM` to bypass

#### Failed at MLM (BLINK + FarmCPU completed)

Kinship matrix calculation or MLM fitting exceeded memory:

1. **Use ultrahighmem template**
2. **Run MLM separately**: Complete BLINK+FarmCPU first, then retry MLM-only
3. **Skip MLM**: Use `MODELS=BLINK,FarmCPU` if MLM not required

### Batch Retry for Failed Traits

After a workflow completes with some OOMKilled failures:

```bash
# 1. List failed traits
argo get <workflow-name> -n runai-talmo-lab | grep "OOMKilled" | \
  grep -oE "run-all-traits\([0-9]+:" | grep -oE "[0-9]+"

# 2. Retry with ultrahighmem (example for Argo)
argo submit workflows/gapit3-parallel-pipeline.yaml \
  --parameter template-ref="gapit3-gwas-single-trait-ultrahighmem" \
  --parameter trait-indices="5,6,7,12,17,20,..."
```

### Memory Monitoring

Monitor memory usage during execution:

```bash
# Real-time pod memory
kubectl top pods -n runai-talmo-lab -l workflows.argoproj.io/workflow=<workflow-name>

# Check resource limits vs usage
kubectl describe pod <pod-name> -n runai-talmo-lab | grep -A10 "Limits:"
```

### When Ultrahighmem Still Fails

If traits fail even with 160 GB:

1. **Check trait data quality**: Missing data patterns may cause excessive memory use
2. **Run models individually**: Split into separate BLINK, FarmCPU, MLM runs
3. **Consider BLINK-only**: BLINK provides comparable power with much lower memory
4. **Request larger node**: Some clusters support 256+ GB nodes

---

## Related Documentation

- [SCRIPTS_REFERENCE.md](SCRIPTS_REFERENCE.md) - Script parameters and model descriptions
- [GAPIT_PARAMETERS.md](GAPIT_PARAMETERS.md) - GAPIT parameter reference
- [WORKFLOW_ARCHITECTURE.md](WORKFLOW_ARCHITECTURE.md) - Argo template configuration
- [cluster/argo/README.md](../cluster/argo/README.md) - Detailed cluster resource guide
- [.env.example](../.env.example) - Thread and resource environment variables

---

*Last updated: 2026-01-05*
