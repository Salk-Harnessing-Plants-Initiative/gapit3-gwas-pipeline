# GAPIT3 Pipeline - Workflow Architecture

Technical deep dive into the Argo Workflows architecture and design decisions for the GAPIT3 GWAS pipeline.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Workflow Components](#workflow-components)
3. [Volume Configuration](#volume-configuration)
4. [Resource Management](#resource-management)
5. [Parallelization Strategy](#parallelization-strategy)
6. [Error Handling](#error-handling)
7. [Design Decisions](#design-decisions)

---

## Architecture Overview

The GAPIT3 pipeline uses Argo Workflows to orchestrate parallel GWAS analysis across 186 traits. The architecture follows a DAG (Directed Acyclic Graph) pattern with four main phases:

```
┌─────────────────────────────────────────────────────────────────┐
│  GAPIT3 GWAS Pipeline - Argo Workflows Architecture            │
└─────────────────────────────────────────────────────────────────┘

Phase 1: Validation
┌──────────────────────┐
│  validate-inputs     │  ← Checks genotype/phenotype files
└──────────┬───────────┘
           │
           ↓
Phase 2: Trait Extraction
┌──────────────────────┐
│  extract-traits      │  ← Generates trait manifest (186 traits)
└──────────┬───────────┘
           │
           ↓
Phase 3: Parallel GWAS Execution (Max 50 concurrent)
┌──────────────────────┬──────────────────────┬─────────────────┐
│  run-trait-2         │  run-trait-3         │  run-trait-4... │
│  (BLINK + FarmCPU)   │  (BLINK + FarmCPU)   │                 │
└──────────┬───────────┴──────────┬───────────┴─────────┬───────┘
           │                      │                     │
           └──────────────────────┴─────────────────────┘
                                  ↓
Phase 4: Results Collection
┌──────────────────────┐
│  collect-results     │  ← Aggregates significant SNPs
└──────────────────────┘
```

### Key Design Principles

1. **Reusability**: WorkflowTemplates define reusable components
2. **Scalability**: DAG parallelization for 186 concurrent tasks
3. **Reliability**: Validation before execution, retry on failure
4. **Traceability**: Metadata tracking for FAIR principles
5. **Resource Efficiency**: Controlled parallelism to avoid cluster overload

---

## Workflow Components

### 1. WorkflowTemplates

WorkflowTemplates are **cluster-level reusable templates** that can be referenced by multiple workflows.

#### gapit3-gwas-single-trait
**Purpose**: Execute GWAS analysis for a single trait

**Location**: `cluster/argo/workflow-templates/gapit3-single-trait-template.yaml`

**Key Features**:
- Fixed resource requests (32GB RAM, 12 CPU)
- Volume mounts by reference (volumes defined at workflow level)
- Container image parameterized for testing different builds
- Metadata output including checksums, timestamps, versions

**Parameters**:
```yaml
- name: trait-index      # Phenotype column number (2-187)
- name: trait-name       # Descriptive name
- name: image            # Docker image tag
- name: models           # GAPIT models: "BLINK", "FarmCPU", or "BLINK,FarmCPU"
- name: threads          # Number of CPU threads to use
```

**Why Fixed Resources?**
Argo validates WorkflowTemplate syntax at submission time, **before** parameter substitution. Parameterized resources like `{{inputs.parameters.memory-gb}}Gi` fail validation because Argo expects valid Kubernetes resource quantities during template validation.

#### gapit3-trait-extractor
**Purpose**: Parse phenotype file and generate trait manifest

**Key Output**: JSON array of trait indices and names

#### gapit3-results-collector
**Purpose**: Aggregate results from all traits into summary files

**Key Outputs**:
- `summary_table.csv` - All traits with completion status
- `significant_snps.csv` - SNPs below p < 5e-8 threshold
- `summary_stats.json` - Overall statistics

### 2. Workflows

Workflows define **specific executions** that reference WorkflowTemplates.

#### gapit3-test-pipeline.yaml
**Purpose**: Test workflow with 3 traits to validate setup

**DAG Structure**:
```yaml
validate-inputs → extract-traits → [run-trait-2, run-trait-3, run-trait-4]
```

**Use Case**: Pre-flight check before running all 186 traits

#### gapit3-parallel-pipeline.yaml
**Purpose**: Production workflow for all 186 traits

**DAG Structure**:
```yaml
validate-inputs → extract-traits → [run-trait-2 ... run-trait-187] → collect-results
```

**Parallelism Control**: `max-parallelism: 50` (configurable)

---

## Volume Configuration

### Critical Workflow Validation Fix

**Problem**: Parameterized `hostPath` volumes in WorkflowTemplates caused validation errors:

```yaml
# ❌ BROKEN - Argo validates BEFORE parameter substitution
# In WorkflowTemplate
volumes:
- name: nfs-data
  hostPath:
    path: "{{inputs.parameters.data-hostpath}}"  # ❌ Validation fails
    type: Directory
```

**Error Message**:
```
Error: quantities must match the regular expression '^([+-]?[0-9.]+)([eEinumkKMGTP]*[-+]?[0-9]*)'
```

**Root Cause**: Argo Workflows validates WorkflowTemplate resources at submission time. The validation engine expects valid Kubernetes resource syntax (e.g., valid paths, memory quantities) **before** `{{inputs.parameters.*}}` gets substituted.

**Solution**: Move volumes to workflow level:

```yaml
# ✅ WORKING - Volumes defined at workflow level
# In Workflow (gapit3-test-pipeline.yaml)
spec:
  volumes:
  - name: nfs-data
    hostPath:
      path: "{{workflow.parameters.data-hostpath}}"  # ✅ Substituted at submission
      type: Directory
  - name: nfs-outputs
    hostPath:
      path: "{{workflow.parameters.output-hostpath}}"
      type: DirectoryOrCreate
```

```yaml
# In WorkflowTemplate
container:
  volumeMounts:
  - name: nfs-data       # ✅ References workflow-level volume by name
    mountPath: /data
    readOnly: true
  - name: nfs-outputs
    mountPath: /outputs
```

### Volume Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  Kubernetes Node                                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  NFS Server: /hpi/hpi_dev/users/eberrigan/...          │  │
│  └────────────────┬────────────────────────────────────────┘  │
│                   │                                            │
│         ┌─────────┴─────────┐                                  │
│         ↓                   ↓                                  │
│  ┌──────────────┐    ┌──────────────┐                          │
│  │  /data (ro)  │    │ /outputs (rw)│                          │
│  │  Genotype    │    │  Results     │                          │
│  │  Phenotype   │    │  Plots       │                          │
│  └──────┬───────┘    └──────┬───────┘                          │
│         │                   │                                  │
│         └─────────┬─────────┘                                  │
│                   ↓                                            │
│  ┌─────────────────────────────────────────────┐              │
│  │  Container (GAPIT3 GWAS)                    │              │
│  │  - Reads from /data                         │              │
│  │  - Writes to /outputs/trait_NNN_TIMESTAMP/  │              │
│  └─────────────────────────────────────────────┘              │
└─────────────────────────────────────────────────────────────────┘
```

**Key Points**:
- **Read-only data mount**: Prevents accidental modification of input data
- **Read-write output mount**: Each trait writes to isolated timestamped directory
- **NFS shared storage**: Multiple pods can access data simultaneously
- **Mount propagation**: `HostToContainer` ensures changes are visible

---

## Resource Management

### Per-Trait Resource Allocation

```yaml
resources:
  requests:
    memory: "32Gi"   # Minimum guaranteed
    cpu: "12"        # 12 cores
  limits:
    memory: "36Gi"   # Maximum allowed (OOMKill at this threshold)
    cpu: "16"        # CPU throttling above this
```

### Resource Sizing Rationale

Based on benchmarks with 546 accessions and ~1.4M SNPs:

| Configuration | Memory Usage | CPU Usage | Runtime | Notes |
|---------------|--------------|-----------|---------|-------|
| **Minimum** | 16 GB | 8 cores | ~25 min | May OOMKill on large traits |
| **Recommended** | 32 GB | 12 cores | ~15 min | Stable for most traits |
| **Optimal** | 48 GB | 16 cores | ~10 min | For memory-intensive traits |

**Memory Considerations**:
- GAPIT3 loads entire genotype matrix into memory
- BLINK: ~20-25 GB peak memory
- FarmCPU: ~25-30 GB peak memory (more iterations)
- 32GB request + 36GB limit provides ~20% headroom

**CPU Considerations**:
- OpenBLAS multi-threading: Linear speedup up to ~12 cores
- Diminishing returns beyond 16 cores (memory bandwidth bound)
- Kubernetes CPU throttling if exceeding limits

### Cluster-Level Resource Planning

For 186 traits with max parallelism = 50:

```
Total Resources Required (at peak):
- CPU: 50 traits × 12 cores = 600 cores
- Memory: 50 traits × 32 GB = 1,600 GB (1.6 TB)
- Disk: 50 traits × 5 GB output = 250 GB

Recommended Cluster:
- 10 nodes with 64 cores + 192 GB RAM each
- Or 20 nodes with 32 cores + 96 GB RAM each
```

---

## Parallelization Strategy

### DAG-Based Parallelism

Argo Workflows uses a Directed Acyclic Graph (DAG) to define dependencies:

```yaml
dag:
  tasks:
  # Sequential: Validation before trait extraction
  - name: validate-inputs
    template: validate

  - name: extract-traits
    dependencies: [validate-inputs]
    template: trait-extractor

  # Parallel: All traits run concurrently (with limit)
  - name: run-trait-2
    dependencies: [extract-traits]
    templateRef:
      name: gapit3-gwas-single-trait
      template: run-gwas

  - name: run-trait-3
    dependencies: [extract-traits]
    templateRef:
      name: gapit3-gwas-single-trait
      template: run-gwas

  # ... (traits 4-187)

  # Sequential: Collect after all traits complete
  - name: collect-results
    dependencies: [run-trait-2, run-trait-3, ..., run-trait-187]
    template: results-collector
```

### Concurrency Control

```yaml
spec:
  parallelism: 50  # Max 50 tasks running simultaneously
```

**Why Limit Parallelism?**
1. **Cluster Capacity**: Avoid overwhelming cluster scheduler
2. **Network I/O**: NFS bandwidth limits concurrent reads
3. **API Rate Limits**: Kubernetes API has QPS limits
4. **Fair Sharing**: Allow other users to access cluster

### Dynamic Trait Generation

Instead of hardcoding 186 tasks, we can use `withItems` for dynamic generation:

```yaml
# Alternative approach (not currently used)
- name: run-all-traits
  dependencies: [extract-traits]
  templateRef:
    name: gapit3-gwas-single-trait
    template: run-gwas
  arguments:
    parameters:
    - name: trait-index
      value: "{{item}}"
  withSequence:
    start: "2"
    end: "187"
```

**Current Approach**: Explicit task definitions for better visibility in Argo UI

---

## Error Handling

### Retry Strategy

```yaml
retryStrategy:
  limit: 2              # Retry up to 2 times
  retryPolicy: OnFailure
  backoff:
    duration: "5m"      # Wait 5 minutes before retry
    factor: 2           # Double wait time on each retry
    maxDuration: "20m"  # Maximum 20 minute wait
```

**Retry Scenarios**:
- Transient NFS errors
- Temporary resource unavailability
- Network timeouts

### Failure Handling

```yaml
# In workflow spec
failFast: false  # Continue even if some traits fail
```

**Rationale**: If trait 50 fails, we still want traits 51-187 to complete.

### Exit Codes

```bash
# In entrypoint.sh
exit 0   # Success
exit 1   # R script error (bad input, GAPIT failure)
exit 2   # Validation error (missing files, bad config)
exit 64  # RBAC permissions error (Argo-specific)
```

### RBAC Permissions Issue

**Current Blocker**: Service account lacks permissions to create `workflowtaskresults`:

```
Error (exit code 64): workflowtaskresults.argoproj.io is forbidden
```

**Impact**: Pods execute successfully but Argo cannot record results.

**Workaround**: Manual RunAI CLI execution (see [MANUAL_RUNAI_EXECUTION.md](MANUAL_RUNAI_EXECUTION.md))

**Resolution**: Cluster administrator must grant RBAC permissions (see [RBAC_PERMISSIONS_ISSUE.md](RBAC_PERMISSIONS_ISSUE.md))

---

## Design Decisions

### 1. WorkflowTemplates vs. Inline Templates

**Decision**: Use WorkflowTemplates

**Rationale**:
- ✅ Reusable across multiple workflows
- ✅ Centralized updates (change template once, all workflows benefit)
- ✅ Versioning (can have multiple template versions)
- ❌ Requires separate installation step

**Alternative**: Inline templates in each workflow (more self-contained but duplicated code)

### 2. Fixed vs. Parameterized Resources

**Decision**: Fixed resources in templates

**Rationale**:
- ✅ Avoids Argo validation errors
- ✅ Predictable resource allocation
- ✅ Simpler template syntax
- ❌ Less flexible (requires template changes to adjust resources)

**Alternative**: Parameterized resources at workflow level (more flexible but validation issues)

### 3. hostPath vs. PVC (Persistent Volume Claim)

**Decision**: hostPath volumes

**Rationale**:
- ✅ Direct NFS access (no PVC overhead)
- ✅ Simpler setup (no PVC creation required)
- ✅ Works with existing NFS infrastructure
- ❌ Less portable (node-dependent paths)
- ❌ No automatic provisioning

**Alternative**: PVC with NFS StorageClass (more Kubernetes-native but adds complexity)

### 4. BLINK + FarmCPU vs. BLINK Only

**Decision**: Both models by default

**Rationale**:
- ✅ BLINK: Fast, good for common variants
- ✅ FarmCPU: Better for rare variants, reduces false positives
- ✅ Complementary results increase confidence
- ❌ 2x runtime compared to BLINK alone

**Use Case**: For quick exploratory analysis, use BLINK only (`--models BLINK`)

### 5. Explicit Task Definitions vs. Dynamic withItems

**Decision**: Explicit task definitions

**Rationale**:
- ✅ Better visibility in Argo UI (individual task nodes)
- ✅ Easier to retry specific traits
- ✅ Clear dependency graph
- ❌ Verbose YAML (186 task definitions)

**Alternative**: `withItems` loop (more concise but less granular control)

### 6. Parallelism Limit = 50

**Decision**: Max 50 concurrent tasks

**Rationale**:
- ✅ Balances speed vs. cluster capacity
- ✅ Prevents NFS bandwidth saturation
- ✅ Allows other users to submit jobs
- ✅ ~4 hour total runtime (acceptable)

**Tuning**: Increase to 100 if cluster has capacity (reduces to ~2.5 hours)

---

## Performance Characteristics

### Runtime Analysis

With 546 accessions, ~1.4M SNPs:

| Phase | Duration | Notes |
|-------|----------|-------|
| **Validation** | ~1 min | File checks, config validation |
| **Trait Extraction** | ~1 min | Parse phenotype file |
| **GWAS (single trait)** | ~15 min | BLINK + FarmCPU |
| **Results Collection** | ~5 min | Aggregate 186 trait outputs |

**Total Time**:
- Serial execution: 186 × 15 min = **~46 hours**
- Parallel (50 jobs): ⌈186 / 50⌉ × 15 min = **~1 hour** (plus startup overhead)
- Actual production time: **~3-4 hours** (includes scheduling, I/O, collection)

### Scaling Considerations

| Parallelism | Total Time | Cluster Load | Use Case |
|-------------|------------|--------------|----------|
| 10 | ~5 hours | Low | Shared cluster |
| 25 | ~3 hours | Medium | Typical |
| 50 | ~2 hours | High | Recommended |
| 100 | ~1.5 hours | Very High | Dedicated cluster |

---

## Future Improvements

### 1. Dynamic Resource Allocation
Use Argo's `resource` field with workflow-level parameters after Argo fixes validation:

```yaml
# Potential future enhancement
resources:
  requests:
    memory: "{{workflow.parameters.memory-gb}}Gi"
    cpu: "{{workflow.parameters.cpu-cores}}"
```

### 2. Artifact Management
Use Argo's artifact repository for output persistence:

```yaml
outputs:
  artifacts:
  - name: gwas-results
    path: /outputs
    s3:
      bucket: gapit3-results
      key: "trait-{{inputs.parameters.trait-index}}"
```

### 3. Conditional Execution
Skip traits that already have results:

```yaml
when: "{{tasks.check-results.outputs.result}} == false"
```

### 4. Resource Autoscaling
Integrate with Kubernetes Cluster Autoscaler for dynamic node provisioning.

### 5. Multi-Cluster Execution
Use Argo Workflows' multi-cluster support for larger parallelism.

---

## References

- **Argo Workflows Docs**: https://argo-workflows.readthedocs.io/
- **Kubernetes Volumes**: https://kubernetes.io/docs/concepts/storage/volumes/
- **GAPIT3 Publication**: Wang & Zhang (2021) - Genomics, Proteomics & Bioinformatics
- **SLEAP-Roots Pipeline**: https://github.com/talmolab/sleap-roots-pipeline (reference architecture)

---

## Related Documentation

- [ARGO_SETUP.md](ARGO_SETUP.md) - Setup and deployment guide
- [MANUAL_RUNAI_EXECUTION.md](MANUAL_RUNAI_EXECUTION.md) - Current RBAC workaround
- [RBAC_PERMISSIONS_ISSUE.md](RBAC_PERMISSIONS_ISSUE.md) - Administrator information
- [OpenSpec Change Proposal](../openspec/changes/fix-argo-workflow-validation/) - Workflow validation fix

---

**Last Updated**: 2025-11-07
