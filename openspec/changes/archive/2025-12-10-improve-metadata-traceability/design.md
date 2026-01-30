## Context

The GAPIT3 GWAS pipeline runs trait analyses in parallel on Kubernetes via Argo Workflows. Current metadata tracks execution timing, GAPIT versions, and data statistics, but lacks provenance information needed for:

1. **Debugging**: Tracing failed results back to specific pods/nodes
2. **Reproducibility**: Verifying exact execution conditions
3. **Auditing**: FAIR compliance requires complete lineage documentation
4. **Operations**: Identifying which workflow run produced which outputs

Key stakeholders: Researchers analyzing GWAS results, operations team debugging failures, compliance auditors verifying reproducibility.

## Goals / Non-Goals

**Goals:**
- Enable tracing any result back to its source workflow, pod, and container
- Capture all parameters affecting reproducibility
- Support graceful degradation outside Argo (local execution)
- Maintain backward compatibility with existing metadata consumers
- Keep metadata generation fast (<1 second overhead per trait)

**Non-Goals:**
- Real-time telemetry or metrics collection
- Distributed tracing (OpenTelemetry integration)
- Log aggregation or storage
- Automatic retry correlation across multiple workflow runs

## Decisions

### Decision 1: Add provenance as new top-level section in metadata.json

**What**: Add `argo`, `container`, and modify `inputs` sections rather than nesting under existing sections.

**Why**:
- Clear separation of concerns (execution vs. data vs. environment)
- Easier to query specific metadata categories
- Simpler JSON path queries for consumers

**Alternatives considered**:
- Flat structure with prefixed keys (e.g., `argo_workflow_name`) - Rejected: harder to extend, no grouping
- Nested under `execution` section - Rejected: overloads existing section, harder to distinguish provenance from timing

### Decision 2: Use MD5 for input file checksums

**What**: Compute MD5 checksums for input files.

**Why**:
- Fast computation (important for 2GB+ genotype files)
- Sufficient for integrity verification (not security)
- Widely supported in R (`tools::md5sum`)
- Human-readable 32-character hex string

**Alternatives considered**:
- SHA-256 - Rejected: 2x slower, security overkill for integrity
- CRC32 - Rejected: higher collision probability
- File size + mtime - Rejected: not reliable for integrity

### Decision 3: Make checksums optional via environment variable

**What**: Skip checksum computation when `SKIP_INPUT_CHECKSUMS=true`.

**Why**:
- Large genotype files (2GB+) take 10-30 seconds to checksum
- For repeated runs on same data, checksums add no value
- Production can enable, development can skip

### Decision 4: Inject Argo metadata via environment variables

**What**: Use Argo template variables (`{{workflow.name}}`, `{{workflow.uid}}`, `{{retries}}`) and Kubernetes downward API (`fieldRef`).

**Why**:
- Native Argo feature, no external dependencies
- Available in container at runtime
- Consistent with existing `WORKFLOW_NAME` and `POD_NAME` usage

**Alternatives considered**:
- Kubernetes API queries from container - Rejected: requires service account permissions, adds latency
- Argo artifacts with workflow metadata - Rejected: artifact storage not configured, adds complexity

### Decision 5: Add schema versioning

**What**: Include `schema_version` field following semantic versioning.

**Why**:
- Enables forward-compatible parsing
- Allows aggregation scripts to handle multiple schema versions
- Documents breaking changes clearly

### Decision 6: Add trait_dir column to aggregated output

**What**: Include source directory name as column in `all_traits_significant_snps.csv`.

**Why**:
- Enables tracing individual SNPs back to source execution
- Directory name contains timestamp for temporal context
- Low overhead (single string column)

**Alternatives considered**:
- Include full metadata in aggregated output - Rejected: bloats file, redundant
- Separate provenance lookup table - Rejected: adds complexity, extra file

## Risks / Trade-offs

| Risk | Impact | Mitigation |
|------|--------|------------|
| Checksum computation slows execution | +10-30s per trait | Make optional via `SKIP_INPUT_CHECKSUMS` |
| Missing Argo variables outside cluster | Null values in metadata | Graceful fallback with null values |
| Schema version migration complexity | Parser must handle multiple versions | Start with v2.0.0, clear migration path |
| Larger metadata.json files | ~50% file size increase | Minimal impact (KB-scale files) |

## Migration Plan

### Phase 1: Environment Variable Injection (Non-breaking)
1. Add new env vars to WorkflowTemplates (`WORKFLOW_UID`, `NODE_NAME`, `RETRY_ATTEMPT`, etc.)
2. Deploy updated templates to cluster
3. Existing R scripts ignore new variables (backward compatible)

### Phase 2: R Script Updates (Non-breaking)
1. Update `run_gwas_single_trait.R` to capture new environment variables
2. Add checksum computation (optional, disabled by default initially)
3. Add schema version field
4. New metadata fields are additive (old consumers ignore them)

### Phase 3: Aggregation Updates (Non-breaking)
1. Update `collect_results.R` to read new metadata fields
2. Add `provenance` section to `summary_stats.json`
3. Add `trait_dir` column to aggregated CSV
4. Handle missing fields gracefully (backward compatible with old metadata)

### Rollback
- Environment variables: Remove from templates, redeploy
- R scripts: Revert to previous version
- No data migration needed (additive changes only)

## Open Questions

1. **Should checksums be stored separately?** Could create `checksums.json` to avoid re-computing on retry. Defer to v2.1.0 based on user feedback.

2. **Include GAPIT random seed?** GAPIT doesn't use a fixed seed by default. Document as known limitation, consider adding seed parameter in future.

3. **Track intermediate file checksums?** Could checksum GAPIT output files for integrity verification. Adds significant overhead, defer unless needed.