# Metadata Schema Reference

This document describes the metadata schema (v2.0.0) used for tracking execution provenance and ensuring reproducibility.

## Overview

The GAPIT3 pipeline generates metadata at two levels:
1. **Per-trait metadata** (`metadata.json`) - Created for each trait analysis
2. **Pipeline summary** (`summary_stats.json`) - Created during aggregation

## Per-Trait Metadata (metadata.json)

Each trait analysis creates a `metadata.json` file in its output directory (`trait_XXX_YYYYMMDD_HHMMSS/`).

### Schema Version

```json
{
  "schema_version": "2.0.0"
}
```

The `schema_version` field enables forward-compatible parsing. Version follows semantic versioning.

### Execution Section

```json
{
  "execution": {
    "trait_index": 2,
    "start_time": "2025-01-15T10:30:00Z",
    "end_time": "2025-01-15T10:45:30Z",
    "duration_minutes": 15.5,
    "status": "success",
    "hostname": "gpu-node-01",
    "r_version": "R version 4.4.1 (2024-06-14)",
    "gapit_version": "3.0",
    "error": null
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `trait_index` | integer | Phenotype column index (2-187) |
| `start_time` | ISO8601 | Analysis start timestamp |
| `end_time` | ISO8601 | Analysis end timestamp |
| `duration_minutes` | numeric | Total execution time |
| `status` | string | "success" or "failed" |
| `hostname` | string | Machine hostname |
| `r_version` | string | R version string |
| `gapit_version` | string | GAPIT package version |
| `error` | string/null | Error message if failed |

### Argo Section (Provenance)

```json
{
  "argo": {
    "workflow_name": "gapit3-gwas-parallel-abc123",
    "workflow_uid": "550e8400-e29b-41d4-a716-446655440000",
    "namespace": "runai-talmo-lab",
    "pod_name": "gapit3-gwas-parallel-abc123-run-all-traits-xyz789",
    "node_name": "gpu-node-01",
    "retry_attempt": 0,
    "max_retries": 5
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `workflow_name` | string/null | Argo workflow name (with unique suffix) |
| `workflow_uid` | string/null | Unique workflow identifier (UUID) |
| `namespace` | string/null | Kubernetes namespace |
| `pod_name` | string/null | Kubernetes pod name |
| `node_name` | string/null | Kubernetes node running the pod |
| `retry_attempt` | integer/null | Current retry attempt (0 = first attempt) |
| `max_retries` | integer | Maximum retry attempts configured |

**Note:** All argo fields are `null` when running outside Argo (e.g., local execution).

### Container Section

```json
{
  "container": {
    "image": "ghcr.io/salk-harnessing-plants-initiative/gapit3-gwas-pipeline:sha-bc10fc8"
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `image` | string/null | Full container image reference with tag/digest |

### Inputs Section

```json
{
  "inputs": {
    "genotype_file": "/data/genotype/snps.hmp.txt",
    "genotype_md5": "a1b2c3d4e5f6789...",
    "phenotype_file": "/data/phenotype/traits.txt",
    "phenotype_md5": "f6e5d4c3b2a1987...",
    "ids_file": "/data/metadata/ids.txt",
    "ids_md5": "123456789abcdef..."
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `genotype_file` | string | Path to genotype HapMap file |
| `genotype_md5` | string/null | MD5 checksum (null if disabled) |
| `phenotype_file` | string | Path to phenotype file |
| `phenotype_md5` | string/null | MD5 checksum |
| `ids_file` | string/null | Path to accession IDs file |
| `ids_md5` | string/null | MD5 checksum |

**Disabling checksums:** Set `SKIP_INPUT_CHECKSUMS=true` to skip checksum computation (useful for large files or repeated runs).

### Parameters Section

```json
{
  "parameters": {
    "models": ["BLINK", "FarmCPU", "MLM"],
    "pca_components": 3,
    "multiple_analysis": true,
    "maf_filter": 0.05,
    "snp_fdr": 0.05,
    "openblas_threads": 12,
    "omp_threads": 12
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `models` | array | GAPIT models used |
| `pca_components` | integer | Number of PCA components |
| `multiple_analysis` | boolean | Run multiple analysis mode |
| `maf_filter` | numeric | Minor allele frequency filter |
| `snp_fdr` | numeric/null | FDR threshold (null if disabled) |
| `openblas_threads` | integer | OpenBLAS thread count |
| `omp_threads` | integer | OpenMP thread count |

### Trait Section

```json
{
  "trait": {
    "name": "root_length",
    "column_index": 2,
    "n_total": 546,
    "n_valid": 520,
    "n_missing": 26
  }
}
```

### Genotype Section

```json
{
  "genotype": {
    "n_snps": 1400000,
    "n_accessions": 546,
    "load_time_seconds": 45.2
  }
}
```

## Pipeline Summary (summary_stats.json)

Created during aggregation in `aggregated_results/summary_stats.json`.

### Provenance Section

```json
{
  "provenance": {
    "workflow_name": "gapit3-gwas-parallel-abc123",
    "workflow_uid": "550e8400-e29b-41d4-a716-446655440000",
    "aggregation_timestamp": "2025-01-15T14:30:00Z",
    "aggregation_hostname": "aggregation-pod-xyz",
    "aggregation_pod": "gapit3-gwas-parallel-abc123-collect-results-pod",
    "aggregation_node": "cpu-node-01",
    "container_image": "ghcr.io/.../gapit3-gwas-pipeline:sha-bc10fc8",
    "source_workflow_uids": ["550e8400-e29b-41d4-a716-446655440000"]
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `workflow_name` | string/null | Aggregation workflow name |
| `workflow_uid` | string/null | Aggregation workflow UID |
| `aggregation_timestamp` | ISO8601 | When aggregation ran |
| `aggregation_hostname` | string | Host running aggregation |
| `aggregation_pod` | string/null | Pod running aggregation |
| `aggregation_node` | string/null | Node running aggregation |
| `container_image` | string/null | Aggregation container image |
| `source_workflow_uids` | array/null | UIDs of source trait workflows |

### Metadata Coverage Section

```json
{
  "metadata_coverage": {
    "traits_with_metadata": 184,
    "traits_missing_metadata": 2,
    "traits_with_provenance": 184
  }
}
```

Tracks how many traits have complete metadata and provenance information.

## Aggregated Results (all_traits_significant_snps.csv)

The aggregated SNP output includes a `trait_dir` column for provenance:

```csv
SNP,Chr,Pos,P.value,MAF,nobs,effect,H&B.P.Value,trait,model,trait_dir
SNP_123,1,12345,1.2e-9,0.15,500,0.05,2.3e-8,root_length,BLINK,trait_042_20251209_103045
```

This enables tracing each SNP back to its source execution directory.

## Environment Variables

The following environment variables are injected by Argo workflow templates:

| Variable | Source | Description |
|----------|--------|-------------|
| `WORKFLOW_NAME` | `{{workflow.name}}` | Argo workflow name |
| `WORKFLOW_UID` | `{{workflow.uid}}` | Unique workflow identifier |
| `WORKFLOW_NAMESPACE` | `fieldRef: metadata.namespace` | Kubernetes namespace |
| `POD_NAME` | `fieldRef: metadata.name` | Pod name |
| `NODE_NAME` | `fieldRef: spec.nodeName` | Kubernetes node |
| `CONTAINER_IMAGE` | `{{inputs.parameters.image}}` | Container image reference |
| `RETRY_ATTEMPT` | `{{retries}}` | Current retry attempt |
| `SKIP_INPUT_CHECKSUMS` | User-configurable | Set to "true" to skip MD5 checksums |

## Backward Compatibility

- **Schema v1.x** (pre-provenance): Missing `schema_version`, `argo`, `container`, and checksum fields
- **Schema v2.0.0**: Full provenance support

The aggregation script handles both schema versions gracefully:
- Missing fields default to `null`
- Old metadata is still processed correctly
- Provenance tracking counts which traits have complete metadata

## Use Cases

### Debugging Failed Jobs

```bash
# Find which node ran a failed trait
jq '.argo.node_name' trait_042_*/metadata.json

# Check if it was a retry
jq '.argo.retry_attempt' trait_042_*/metadata.json
```

### Reproducibility Verification

```bash
# Verify input files haven't changed
jq '.inputs.genotype_md5' metadata.json
md5sum /data/genotype/snps.hmp.txt

# Check exact container version
jq '.container.image' metadata.json
```

### Lineage Tracking

```bash
# Find all traits from a specific workflow
grep -l "workflow_uid.*abc123" trait_*/metadata.json

# Trace SNP back to source execution
grep "SNP_12345" aggregated_results/all_traits_significant_snps.csv | cut -d, -f11
```