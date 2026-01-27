## ADDED Requirements

### Requirement: Multi-workflow aggregation detection and reporting

The aggregation script MUST detect when results come from multiple source workflows and report this clearly in the output.

#### Scenario: Detecting multi-workflow aggregation

- **GIVEN** trait directories where:
  - `trait_001/metadata.json` has `argo.workflow_uid = "uid-workflow-a"`
  - `trait_002/metadata.json` has `argo.workflow_uid = "uid-workflow-b"`
- **WHEN** the aggregation script processes these traits
- **THEN** the script MUST:
  - Set `is_multi_workflow = TRUE` in stats
  - Print console notice: "Note: Aggregating results from 2 source workflows"
  - Include per-workflow statistics in output

#### Scenario: Single workflow aggregation (no change)

- **GIVEN** all trait directories have the same `argo.workflow_uid`
- **WHEN** the aggregation script processes these traits
- **THEN** the script MUST:
  - Set `is_multi_workflow = FALSE` in stats
  - NOT print multi-workflow notice
  - Report as single workflow in summary

---

### Requirement: Per-workflow statistics collection

The aggregation script MUST collect and report statistics broken down by source workflow.

#### Scenario: Collecting per-workflow trait counts

- **GIVEN** 100 traits from workflow A and 86 traits from workflow B
- **WHEN** aggregation completes
- **THEN** `summary_stats.json` MUST include:
  ```json
  {
    "workflow_stats": {
      "uid-workflow-a": {
        "workflow_name": "gapit3-gwas-parallel-abc123",
        "trait_count": 100,
        "total_duration_hours": 50.5
      },
      "uid-workflow-b": {
        "workflow_name": "gapit3-gwas-retry-xyz789",
        "trait_count": 86,
        "total_duration_hours": 35.2
      }
    }
  }
  ```

#### Scenario: Handling traits without workflow metadata

- **GIVEN** some traits have `metadata.json` without `argo.workflow_uid`
- **WHEN** aggregation processes these traits
- **THEN** the script MUST:
  - Group such traits under `"unknown"` workflow key
  - Still count them in total trait count
  - Report `"workflow_name": "unknown"` for these

---

## MODIFIED Requirements

### Requirement: Markdown report must include provenance information

The markdown report MUST include provenance information for FAIR compliance and reproducibility.

#### Scenario: Reproducibility block with full provenance

- **GIVEN** aggregation run with Argo workflow metadata available
- **WHEN** markdown report is generated
- **THEN** the reproducibility section MUST include:
  ```markdown
  ## Reproducibility

  | Field | Value |
  |-------|-------|
  | Workflow ID | gapit3-gwas-parallel-6hjx8 |
  | Workflow UID | abc123-def456-... |
  | Container Image | ghcr.io/talmo-lab/gapit3-gwas-pipeline:sha-xyz |
  | Collection Time | 2025-12-09 21:25:24 |
  | Aggregation Host | collector-pod-xyz |
  | R Version | R version 4.4.1 (2024-06-14) |
  | GAPIT Version | 3.5.0 |
  ```

#### Scenario: Reproducibility block with missing provenance

- **GIVEN** aggregation run outside Argo (local execution)
- **AND** workflow metadata not available
- **WHEN** markdown report is generated
- **THEN** the reproducibility section MUST:
  - Show "N/A" for unavailable fields
  - Still include available fields (collection time, R version)
  - NOT fail or omit the section entirely

#### Scenario: Reproducibility block with multiple source workflows

- **GIVEN** aggregation of traits from 2+ different Argo workflows
- **WHEN** markdown report is generated
- **THEN** the reproducibility section MUST include:
  ```markdown
  ## Reproducibility

  | Field | Value |
  |-------|-------|
  | Aggregation Workflow | gapit3-aggregate-j47s8 |
  | Source Workflows | 2 (see below) |
  | Collection Time | 2026-01-26 15:18:20 |
  | R Version | R version 4.4.1 (2024-06-14) |
  | GAPIT Version | 3.5.0 |

  ### Source Workflows

  | Workflow Name | UID | Traits | Compute Hours |
  |---------------|-----|--------|---------------|
  | gapit3-gwas-parallel-abc123 | uid-workflow-a | 100 | 50.5 |
  | gapit3-gwas-retry-xyz789 | uid-workflow-b | 86 | 35.2 |
  ```
- **AND** the Executive Summary MUST show:
  - `Source Workflows | 2` instead of single Workflow ID
