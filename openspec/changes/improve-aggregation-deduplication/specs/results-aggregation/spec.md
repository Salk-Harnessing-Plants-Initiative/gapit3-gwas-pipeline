## ADDED Requirements

### Requirement: Workflow ID filter for multi-workflow aggregation

The aggregation script MUST support filtering trait directories by workflow ID(s) via the `--workflow-id` parameter. This enables aggregating results from specific workflows (e.g., original workflow plus its retries) while excluding unrelated results.

**Workflow ID extraction (backward compatibility):**
- If `metadata.json` contains `workflow.name`, use that field directly
- Otherwise, extract workflow name from `execution.hostname` using pattern: `<workflow-name>-run-gwas-<hash>` → extract `<workflow-name>`
- The hostname is the Kubernetes pod name, which Argo sets to `<workflow-name>-<template-name>-<hash>`

#### Scenario: Filter by single workflow ID

- **GIVEN** an output directory containing:
  - `trait_005_root_20251208/` with `metadata.json` containing `execution.hostname: "gapit3-gwas-parallel-abc123-run-gwas-123456"`
  - `trait_005_root_20251209/` with `metadata.json` containing `execution.hostname: "gapit3-gwas-parallel-xyz789-run-gwas-789012"`
- **WHEN** aggregation runs with `--workflow-id gapit3-gwas-parallel-abc123`
- **THEN** the script MUST:
  - Extract workflow ID `gapit3-gwas-parallel-abc123` from first directory's hostname
  - Extract workflow ID `gapit3-gwas-parallel-xyz789` from second directory's hostname
  - Include only `trait_005_root_20251208/`
  - Exclude `trait_005_root_20251209/`
  - Log: `"Filtering by workflow ID: gapit3-gwas-parallel-abc123"`

#### Scenario: Filter by multiple workflow IDs (comma-separated)

- **GIVEN** trait directories from three workflows: `workflow-A`, `workflow-B`, `workflow-C`
- **WHEN** aggregation runs with `--workflow-id workflow-A,workflow-B`
- **THEN** the script MUST:
  - Include directories from `workflow-A` and `workflow-B`
  - Exclude directories from `workflow-C`
  - Log: `"Filtering by workflow IDs: workflow-A, workflow-B"`

#### Scenario: No workflow ID filter (default behavior)

- **GIVEN** trait directories from multiple workflows
- **WHEN** aggregation runs WITHOUT `--workflow-id` parameter
- **THEN** the script MUST:
  - Include all trait directories (current behavior preserved)
  - NOT filter by workflow ID
  - Log: `"No workflow ID filter - aggregating all directories"`

#### Scenario: Handle missing metadata.json gracefully

- **GIVEN** a trait directory without `metadata.json`
- **AND** `--workflow-id` filter is specified
- **WHEN** aggregation processes this directory
- **THEN** the script MUST:
  - Exclude the directory (unknown workflow)
  - Emit warning: `"WARNING: trait_XXX has no metadata.json, excluding from workflow-filtered aggregation"`

#### Scenario: Handle missing hostname in metadata.json

- **GIVEN** a trait directory with `metadata.json` that has no `workflow.name` and no `execution.hostname`
- **AND** `--workflow-id` filter is specified
- **WHEN** aggregation processes this directory
- **THEN** the script MUST:
  - Exclude the directory (cannot determine workflow)
  - Emit warning: `"WARNING: trait_XXX has no workflow info in metadata, excluding from workflow-filtered aggregation"`

---

### Requirement: Source manifest for reproducibility

The aggregation script MUST write a manifest file listing all directories that were included in the aggregation, enabling reproducibility and audit trails.

#### Scenario: Source manifest created on successful aggregation

- **GIVEN** aggregation of 186 traits from directories
- **WHEN** aggregation completes successfully
- **THEN** the script MUST create `aggregated_results/source_directories.txt` containing:
  - One directory path per line
  - Sorted by trait index
  - Header comment with aggregation timestamp and workflow IDs (if filtered)

#### Scenario: Source manifest format

- **GIVEN** successful aggregation
- **WHEN** `source_directories.txt` is written
- **THEN** the file MUST have format:
```
# Aggregation source directories
# Generated: 2024-12-09 15:30:00
# Workflow filter: gapit3-gwas-parallel-abc123, gapit3-gwas-retry-abc123-xyz
# Traits: 186
trait_002_root_length_20241208_120000
trait_003_shoot_mass_20241208_120100
...
trait_187_leaf_area_20241208_140000
```

---

## MODIFIED Requirements

### Requirement: Deduplication must prioritize Filter file presence

When multiple directories exist for the same trait index, the deduplication logic MUST prioritize directories that have the Filter file (complete) over those that don't (incomplete), regardless of model count.

#### Scenario: Filter-first deduplication selects complete over incomplete

- **GIVEN** two directories for trait 5:
  - `trait_005_20241208/` with 3 GWAS_Results files but NO Filter file (incomplete)
  - `trait_005_20241209/` with 2 GWAS_Results files AND Filter file (complete)
- **WHEN** deduplication runs
- **THEN** the script MUST:
  - Select `trait_005_20241209/` (has Filter file)
  - Discard `trait_005_20241208/` (no Filter file)
  - Log: `"Trait 5: Selected trait_005_20241209 (complete) over trait_005_20241208 (incomplete)"`

#### Scenario: Deduplication tiebreaker when both have Filter files

- **GIVEN** two directories for trait 5, both with Filter files:
  - `trait_005_20241208/` with Filter file
  - `trait_005_20241209/` with Filter file (newer)
- **WHEN** deduplication runs
- **THEN** the script MUST:
  - Select `trait_005_20241209/` (newer timestamp)
  - Log: `"Trait 5: Selected trait_005_20241209 (newer) over trait_005_20241208"`

#### Scenario: Deduplication tiebreaker when neither has Filter file

- **GIVEN** two directories for trait 5, neither with Filter files:
  - `trait_005_20241208/` with 2 GWAS_Results files
  - `trait_005_20241209/` with 3 GWAS_Results files
- **WHEN** deduplication runs
- **THEN** the script MUST:
  - Select `trait_005_20241209/` (more models)
  - Both will fail completeness check later (expected behavior)
  - Log: `"Trait 5: Selected trait_005_20241209 (3 models) over trait_005_20241208 (2 models) - note: neither has Filter file"`

#### Scenario: Deduplication summary in console output

- **GIVEN** deduplication of 190 directories into 186 unique traits
- **WHEN** deduplication completes
- **THEN** the script MUST output:
```
Deduplication summary:
  - Total directories found: 190
  - Unique traits: 186
  - Duplicates resolved: 4
    - By Filter file presence: 3
    - By timestamp (both complete): 1
```