## Why

Current metadata captures execution timing, data statistics, and GAPIT parameters but lacks critical provenance information needed for full reproducibility and traceability. Missing: Argo workflow IDs, pod identifiers, container image digests, retry context, and pipeline-level lineage. This makes it difficult to trace results back to specific workflow runs, debug failures, or reproduce exact execution conditions.

## What Changes

- **ADDED** Workflow provenance metadata (workflow ID, UID, namespace, timestamps)
- **ADDED** Pod execution metadata (pod name, node name, retry attempt number)
- **ADDED** Container image metadata (full image reference with digest/SHA)
- **ADDED** Pipeline-level lineage tracking (input file checksums, parameter fingerprints)
- **ADDED** Aggregation provenance in summary outputs (source workflow IDs, aggregation timestamp)
- **MODIFIED** `metadata.json` schema with new `provenance` and `environment` sections
- **MODIFIED** `summary_stats.json` schema with workflow lineage

## Impact

- Affected specs: `execution-metadata` (new), `results-aggregation`
- Affected code:
  - `scripts/run_gwas_single_trait.R` (metadata generation)
  - `scripts/collect_results.R` (aggregation metadata)
  - `cluster/argo/workflow-templates/*.yaml` (environment variable injection)
  - `cluster/argo/workflows/*.yaml` (workflow parameter additions)
- Backward compatibility: Existing metadata fields preserved; new fields are additive
