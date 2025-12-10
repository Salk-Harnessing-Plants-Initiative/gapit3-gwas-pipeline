# execution-metadata Specification

## Purpose
TBD - created by archiving change improve-metadata-traceability. Update Purpose after archive.
## Requirements
### Requirement: Per-trait metadata must include Argo workflow provenance

The `metadata.json` file created for each trait MUST include an `argo` section containing workflow and pod identifiers that enable tracing results back to the specific Argo Workflow execution.

#### Scenario: Metadata includes workflow identification

- **GIVEN** a GWAS analysis running within an Argo Workflow named `gapit3-gwas-parallel-abc123`
- **AND** the workflow has UID `550e8400-e29b-41d4-a716-446655440000`
- **AND** the pod running the analysis is named `gapit3-gwas-parallel-abc123-run-all-traits-xyz789`
- **WHEN** the trait analysis completes and writes `metadata.json`
- **THEN** the file MUST include:
```json
{
  "argo": {
    "workflow_name": "gapit3-gwas-parallel-abc123",
    "workflow_uid": "550e8400-e29b-41d4-a716-446655440000",
    "namespace": "runai-talmo-lab",
    "pod_name": "gapit3-gwas-parallel-abc123-run-all-traits-xyz789",
    "node_name": "gpu-node-01"
  }
}
```

#### Scenario: Metadata captures retry attempt information

- **GIVEN** a trait analysis that failed and was retried by Argo's retry strategy
- **AND** the current execution is retry attempt 2 (third total attempt)
- **WHEN** the trait analysis writes `metadata.json`
- **THEN** the file MUST include:
```json
{
  "argo": {
    "retry_attempt": 2,
    "max_retries": 5
  }
}
```

#### Scenario: Metadata falls back gracefully outside Argo

- **GIVEN** a GWAS analysis running locally (not in Argo)
- **AND** Argo environment variables are not set
- **WHEN** the trait analysis writes `metadata.json`
- **THEN** the `argo` section MUST contain null values:
```json
{
  "argo": {
    "workflow_name": null,
    "workflow_uid": null,
    "namespace": null,
    "pod_name": null,
    "node_name": null,
    "retry_attempt": null
  }
}
```

---

### Requirement: Per-trait metadata must include container image reference

The `metadata.json` file MUST include the exact container image reference used for execution to ensure reproducibility.

#### Scenario: Metadata captures image with SHA digest

- **GIVEN** a GWAS analysis running in container `ghcr.io/salk-harnessing-plants-initiative/gapit3-gwas-pipeline:sha-bc10fc8`
- **WHEN** the trait analysis writes `metadata.json`
- **THEN** the file MUST include:
```json
{
  "container": {
    "image": "ghcr.io/salk-harnessing-plants-initiative/gapit3-gwas-pipeline:sha-bc10fc8"
  }
}
```

---

### Requirement: Per-trait metadata must include input file checksums

The `metadata.json` file MUST include MD5 checksums for input files to verify data integrity and enable reproducibility audits.

#### Scenario: Metadata captures genotype and phenotype file checksums

- **GIVEN** a GWAS analysis using:
  - Genotype file with MD5: `a1b2c3d4e5f6...`
  - Phenotype file with MD5: `f6e5d4c3b2a1...`
- **WHEN** the trait analysis writes `metadata.json`
- **THEN** the file MUST include:
```json
{
  "inputs": {
    "genotype_file": "/data/genotype/snps.hmp.txt",
    "genotype_md5": "a1b2c3d4e5f6...",
    "phenotype_file": "/data/phenotype/traits.txt",
    "phenotype_md5": "f6e5d4c3b2a1...",
    "ids_file": "/data/metadata/ids.txt",
    "ids_md5": "1234567890ab..."
  }
}
```

#### Scenario: Checksum computation is optional and configurable

- **GIVEN** a large genotype file (>2GB) that would be slow to checksum
- **AND** the `SKIP_INPUT_CHECKSUMS` environment variable is set to `"true"`
- **WHEN** the trait analysis writes `metadata.json`
- **THEN** the checksum fields MUST be null:
```json
{
  "inputs": {
    "genotype_file": "/data/genotype/snps.hmp.txt",
    "genotype_md5": null,
    "phenotype_file": "/data/phenotype/traits.txt",
    "phenotype_md5": null
  }
}
```

---

### Requirement: Per-trait metadata must include complete parameter fingerprint

The `metadata.json` file MUST include all parameters that affect GWAS execution results for reproducibility verification.

#### Scenario: Metadata captures all GAPIT parameters

- **WHEN** a trait analysis completes
- **THEN** the `parameters` section MUST include:
```json
{
  "parameters": {
    "models": ["BLINK", "FarmCPU"],
    "pca_components": 3,
    "multiple_analysis": true,
    "maf_filter": 0.05,
    "snp_fdr": 0.05,
    "openblas_threads": 12,
    "omp_threads": 12
  }
}
```

---

### Requirement: Pipeline summary must include workflow lineage

The `summary_stats.json` file MUST include workflow lineage information that links aggregated results to source workflow executions.

#### Scenario: Summary includes workflow provenance

- **GIVEN** aggregation collecting results from workflow `gapit3-gwas-parallel-abc123`
- **AND** the batch contains 186 trait results
- **WHEN** aggregation creates `summary_stats.json`
- **THEN** the file MUST include:
```json
{
  "provenance": {
    "workflow_name": "gapit3-gwas-parallel-abc123",
    "workflow_uid": "550e8400-e29b-41d4-a716-446655440000",
    "aggregation_timestamp": "2025-12-09T15:30:45Z",
    "aggregation_hostname": "gapit3-gwas-parallel-abc123-collect-results-pod",
    "container_image": "ghcr.io/salk-harnessing-plants-initiative/gapit3-gwas-pipeline:sha-bc10fc8"
  }
}
```

#### Scenario: Summary tracks trait metadata sources

- **GIVEN** aggregation of 186 traits where each trait has `metadata.json`
- **WHEN** aggregation creates `summary_stats.json`
- **THEN** the file MUST include counts of metadata availability:
```json
{
  "metadata_coverage": {
    "traits_with_metadata": 184,
    "traits_missing_metadata": 2,
    "traits_with_provenance": 184
  }
}
```

---

### Requirement: Aggregated output must include source trait provenance

The `all_traits_significant_snps.csv` file MUST include provenance columns that link each SNP back to its source trait execution.

#### Scenario: SNP rows include trait directory reference

- **GIVEN** a significant SNP from trait analysis in directory `trait_042_20251209_103045`
- **WHEN** the SNP is written to aggregated output
- **THEN** the row MUST include:
```csv
SNP,Chr,Pos,P.value,MAF,nobs,effect,H&B.P.Value,trait,model,trait_dir
SNP_123,1,12345,1.2e-9,0.15,500,0.05,2.3e-8,root_length,BLINK,trait_042_20251209_103045
```

---

### Requirement: Argo workflow templates must inject provenance environment variables

The Argo WorkflowTemplates MUST inject environment variables containing workflow and pod metadata that R scripts can capture.

#### Scenario: Single-trait template injects workflow metadata

- **GIVEN** the `gapit3-gwas-single-trait` WorkflowTemplate
- **WHEN** a pod is created from this template
- **THEN** the container environment MUST include:
```yaml
env:
- name: WORKFLOW_NAME
  value: "{{workflow.name}}"
- name: WORKFLOW_UID
  value: "{{workflow.uid}}"
- name: WORKFLOW_NAMESPACE
  valueFrom:
    fieldRef:
      fieldPath: metadata.namespace
- name: POD_NAME
  valueFrom:
    fieldRef:
      fieldPath: metadata.name
- name: NODE_NAME
  valueFrom:
    fieldRef:
      fieldPath: spec.nodeName
- name: CONTAINER_IMAGE
  value: "{{inputs.parameters.image}}"
- name: RETRY_ATTEMPT
  value: "{{retries}}"
```

---

### Requirement: Metadata schema must be versioned

The `metadata.json` file MUST include a schema version to enable forward-compatible parsing and migration.

#### Scenario: Metadata includes version number

- **WHEN** any metadata.json file is created
- **THEN** the file MUST include at the top level:
```json
{
  "schema_version": "2.0.0",
  ...
}
```

#### Scenario: Version follows semantic versioning

- **GIVEN** the current schema version is `2.0.0`
- **WHEN** new required fields are added (breaking change)
- **THEN** the major version MUST be incremented to `3.0.0`
- **WHEN** new optional fields are added (non-breaking)
- **THEN** the minor version MUST be incremented to `2.1.0`

