## ADDED Requirements

### Requirement: Standalone Aggregation Workflow Capability

The system SHALL provide a standalone Argo workflow for running results aggregation independently of the main GWAS pipeline. This enables aggregating results after retry workflows complete or re-aggregating with different parameters without re-running GWAS analyses.

#### Scenario: Submit standalone aggregation workflow

- **GIVEN** an output directory containing completed trait analyses
- **WHEN** the user submits `gapit3-aggregation-standalone.yaml` with:
  - `output-hostpath`: Path to outputs directory containing `trait_NNN_*` directories
  - `batch-id`: Optional identifier for the aggregation run
  - `image`: Docker image tag
- **THEN** the workflow runs the `gapit3-results-collector` WorkflowTemplate
- **AND** aggregates all trait results into `aggregated_results/` directory
- **AND** produces the same output as in-pipeline aggregation

#### Scenario: Aggregation after retry workflow completes

- **GIVEN** a retry workflow that completed without aggregation (no `--aggregate` flag)
- **AND** all traits now have Filter files indicating completion
- **WHEN** the user runs standalone aggregation with the same `output-hostpath`
- **THEN** the aggregation includes results from both original and retry runs
- **AND** the deduplication logic selects the best directory for each trait

#### Scenario: Standalone workflow uses existing WorkflowTemplate

- **GIVEN** the `gapit3-results-collector` WorkflowTemplate is installed on the cluster
- **WHEN** the standalone aggregation workflow is submitted
- **THEN** it references the template via `templateRef`
- **AND** does NOT duplicate the aggregation container definition
- **AND** inherits resource limits from the template (8Gi request, 16Gi limit)

#### Scenario: Workflow submission command pattern

- **GIVEN** a user wants to run standalone aggregation
- **WHEN** they follow the documentation
- **THEN** they can submit using:
  ```bash
  argo submit cluster/argo/workflows/gapit3-aggregation-standalone.yaml \
    -p output-hostpath="/hpi/hpi_dev/users/USERNAME/PROJECT/outputs" \
    -p batch-id="gapit3-gwas-parallel-XXXXX" \
    -n runai-talmo-lab
  ```
- **AND** the workflow generates a unique name like `gapit3-aggregate-XXXXX`

---

### Requirement: Aggregation Method Documentation

The system SHALL document when to use each aggregation method to help users choose the appropriate approach for their scenario.

#### Scenario: Method comparison documentation exists

- **GIVEN** a user needs to aggregate GWAS results
- **WHEN** they consult the Argo README documentation
- **THEN** they find a comparison table showing:
  | Scenario | Method | Command/File |
  |----------|--------|--------------|
  | Main pipeline with traits | In-DAG | `gapit3-parallel-pipeline.yaml` (automatic) |
  | Retry after OOM | In-DAG retry | `retry-argo-traits.sh --aggregate` |
  | After workflow stops | Standalone | `gapit3-aggregation-standalone.yaml` |
  | Local re-aggregation | R script | `Rscript scripts/collect_results.R` |
- **AND** they understand which method to use for their scenario