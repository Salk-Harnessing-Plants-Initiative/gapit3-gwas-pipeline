## 1. Argo Workflow Template Updates

- [x] 1.1 Add `WORKFLOW_UID` environment variable to `gapit3-single-trait-template.yaml` using `{{workflow.uid}}`
- [x] 1.2 Add `NODE_NAME` environment variable using `fieldRef: spec.nodeName`
- [x] 1.3 Add `RETRY_ATTEMPT` environment variable using `{{retries}}`
- [x] 1.4 Add `WORKFLOW_NAMESPACE` environment variable using `fieldRef: metadata.namespace`
- [x] 1.5 Apply same changes to `gapit3-single-trait-template-highmem.yaml`
- [x] 1.6 Add `WORKFLOW_UID` to `results-collector-template.yaml`

## 2. R Script Updates - run_gwas_single_trait.R

- [x] 2.1 Add `schema_version` field to metadata (set to "2.0.0")
- [x] 2.2 Add `argo` section with workflow_name, workflow_uid, namespace, pod_name, node_name, retry_attempt
- [x] 2.3 Add `container` section with image reference from `CONTAINER_IMAGE` env var
- [x] 2.4 Add MD5 checksum computation function for input files
- [x] 2.5 Add `genotype_md5`, `phenotype_md5`, `ids_md5` fields to inputs section
- [x] 2.6 Add `SKIP_INPUT_CHECKSUMS` environment variable check to bypass checksums
- [x] 2.7 Add `openblas_threads` and `omp_threads` to parameters section
- [x] 2.8 Handle null values gracefully when running outside Argo

## 3. R Script Updates - collect_results.R

- [x] 3.1 Add `provenance` section to summary_stats.json with workflow lineage
- [x] 3.2 Add `metadata_coverage` tracking (traits with/without metadata, with/without provenance)
- [x] 3.3 Add `aggregation_timestamp` and `aggregation_hostname` to provenance
- [x] 3.4 Add `trait_dir` column to all_traits_significant_snps.csv
- [x] 3.5 Read and aggregate Argo metadata from trait metadata.json files

## 4. Test Fixtures and Unit Tests

- [x] 4.1 Update test fixtures with new metadata schema (add argo, container sections)
- [x] 4.2 Add unit tests for checksum computation function
- [x] 4.3 Add unit tests for metadata schema version parsing
- [x] 4.4 Add unit tests for graceful handling of missing provenance fields
- [x] 4.5 Add integration test for aggregation with new trait_dir column

## 5. Documentation

- [x] 5.1 Document new metadata.json schema in README or separate metadata docs
- [x] 5.2 Document environment variables for provenance injection
- [x] 5.3 Update FAIR compliance documentation with new provenance capabilities

**Documentation created:** `docs/METADATA_SCHEMA.md` - comprehensive reference covering:
- Schema v2.0.0 structure
- All metadata sections (execution, argo, container, inputs, parameters, trait, genotype)
- Pipeline summary provenance
- Environment variables reference
- Backward compatibility notes
- Use cases for debugging, reproducibility, and lineage tracking