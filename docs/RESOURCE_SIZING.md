# Resource Sizing Guide

This guide explains how to determine appropriate computational resources for your GWAS dataset.

> **Reference Dataset**: Examples below reference a 546-sample, 1.4M SNP dataset. Scale recommendations according to your data.

---

## Table of Contents

1. [Quick Reference](#quick-reference)
2. [Memory Estimation](#memory-estimation)
3. [CPU Allocation](#cpu-allocation)
4. [Disk Space](#disk-space)
5. [Choosing Templates](#choosing-templates)
6. [Troubleshooting OOMKilled](#troubleshooting-oomkilled)

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

| Samples | SNPs | Base Matrix | Recommended (BLINK) | Recommended (MLM) |
|---------|------|-------------|---------------------|-------------------|
| 200 | 500,000 | 0.8 GB | 12 GB | 16 GB |
| 500 | 1,000,000 | 4.0 GB | 24 GB | 40 GB |
| 500 | 1,400,000 | 5.6 GB | 32 GB | 48 GB |
| 1000 | 2,000,000 | 16.0 GB | 72 GB | 120 GB |

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

### Standard Template

Use the standard template when:
- Dataset has < 500 samples
- Running BLINK or FarmCPU only
- SNP count < 2 million
- Memory requirement < 40 GB

```yaml
# cluster/argo/templates/gwas-job-template.yaml
resources:
  requests:
    memory: "30Gi"
    cpu: "8"
  limits:
    memory: "40Gi"
    cpu: "12"
```

### High-Memory Template

Use the high-memory template when:
- Dataset has > 500 samples
- Running MLM, MLMM, or multiple models
- SNP count > 2 million
- Experiencing OOMKilled errors

```yaml
# cluster/argo/templates/gwas-job-template-high-mem.yaml
resources:
  requests:
    memory: "50Gi"
    cpu: "12"
  limits:
    memory: "64Gi"
    cpu: "16"
```

### Template Selection Flowchart

```
Start
  │
  ├─ Samples > 500? ──Yes──> High-Memory
  │        │
  │        No
  │        │
  ├─ SNPs > 2M? ──Yes──> High-Memory
  │        │
  │        No
  │        │
  ├─ Using MLM/MLMM? ──Yes──> High-Memory
  │        │
  │        No
  │        │
  └─ Standard Template
```

---

## Troubleshooting OOMKilled

### Identifying OOMKilled

When a pod runs out of memory, Kubernetes terminates it:

```bash
kubectl get pods -n argo
# STATUS: OOMKilled

kubectl describe pod <pod-name> -n argo
# Last State: Terminated
# Reason: OOMKilled
```

### Solutions

1. **Increase Memory Limits**

   Edit the workflow template to increase memory:
   ```yaml
   limits:
     memory: "64Gi"  # Increase from 40Gi
   ```

2. **Reduce Model Complexity**

   Run fewer models or avoid memory-intensive ones:
   ```bash
   MODELS=BLINK        # Instead of BLINK,FarmCPU,MLM
   ```

3. **Use High-Memory Template**

   Switch to the high-memory template in your workflow submission.

4. **Check for Memory Leaks**

   Monitor memory during execution:
   ```bash
   kubectl top pods -n argo
   ```

### Memory Debugging

Enable R memory profiling for detailed analysis:

```bash
# In container
Rscript -e "gc()" scripts/run_gwas_single_trait.R
```

Check peak memory usage in the metadata.json output file.

---

## Related Documentation

- [SCRIPTS_REFERENCE.md](SCRIPTS_REFERENCE.md) - Script parameters and memory per model
- [WORKFLOW_ARCHITECTURE.md](WORKFLOW_ARCHITECTURE.md) - Argo template configuration
- [.env.example](../.env.example) - Thread and resource environment variables

---

*Last updated: 2025-01-03*
