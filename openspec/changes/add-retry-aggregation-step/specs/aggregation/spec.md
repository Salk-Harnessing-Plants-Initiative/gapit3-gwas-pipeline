## ADDED Requirements

### Requirement: Retry Workflow Aggregation

The retry workflow SHALL optionally include an aggregation step that runs in-cluster after all retry traits complete.

#### Scenario: Generate retry workflow with aggregation
- **GIVEN** a retry workflow being generated with `--aggregate` flag
- **WHEN** the workflow YAML is created
- **THEN** it includes a `collect-results` task
- **AND** the task depends on all `retry-trait-*` tasks
- **AND** the task references the `gapit3-results-collector` template
- **AND** the task passes the workflow image and name as parameters

#### Scenario: Aggregation runs after retries complete
- **GIVEN** a retry workflow submitted with `--aggregate` flag
- **WHEN** all retry-trait-* tasks complete (success or failure)
- **THEN** the collect-results task executes
- **AND** it aggregates all trait results (not just retried ones)
- **AND** it creates summary files in `aggregated_results/` directory

### Requirement: Duplicate Trait Directory Handling

The aggregation script SHALL handle multiple output directories for the same trait index by selecting the most complete one.

#### Scenario: Select most complete directory
- **GIVEN** multiple directories exist for trait index 5:
  - `trait_005_Zn_ICP_20251112_200000/` with 2/3 models (BLINK, FarmCPU)
  - `trait_005_Zn_ICP_20251123_120000/` with 3/3 models (all)
- **WHEN** the aggregation script runs
- **THEN** it selects `trait_005_Zn_ICP_20251123_120000/` (more complete)
- **AND** it ignores the partial directory
- **AND** it logs which directory was selected

#### Scenario: Tie-break by timestamp
- **GIVEN** multiple directories exist for trait index 10:
  - `trait_010_Fe_ICP_20251112_200000/` with 3/3 models
  - `trait_010_Fe_ICP_20251123_120000/` with 3/3 models
- **WHEN** the aggregation script runs
- **THEN** it selects `trait_010_Fe_ICP_20251123_120000/` (newest)
- **AND** it logs the tie-break decision

#### Scenario: Prefer partial old over less complete new
- **GIVEN** multiple directories exist for trait index 15:
  - `trait_015_Mn_ICP_20251112_200000/` with 2/3 models (retry failed early)
  - `trait_015_Mn_ICP_20251123_120000/` with 1/3 models (only BLINK)
- **WHEN** the aggregation script runs
- **THEN** it selects `trait_015_Mn_ICP_20251112_200000/` (more complete)
- **AND** it logs the selection reason

#### Scenario: Log duplicate detection
- **GIVEN** multiple directories exist for some trait indices
- **WHEN** the aggregation script runs
- **THEN** it logs the number of traits with duplicates
- **AND** it logs which directory was selected for each
- **AND** aggregation continues with selected directories

### Requirement: SNP FDR Parameter Propagation

The retry workflow generation SHALL propagate the `snp-fdr` parameter from the original workflow.

#### Scenario: Extract snp-fdr from original workflow
- **GIVEN** an original workflow was submitted with `snp-fdr=0.05`
- **WHEN** a retry workflow is generated from that workflow
- **THEN** the retry workflow includes `snp-fdr` in its workflow parameters
- **AND** the value matches the original workflow (0.05)
- **AND** each retry-trait-* task passes snp-fdr to the templateRef

#### Scenario: Original workflow has no snp-fdr
- **GIVEN** an original workflow was submitted without `snp-fdr` parameter
- **WHEN** a retry workflow is generated from that workflow
- **THEN** the retry workflow omits snp-fdr (or uses empty default)
- **AND** backward compatibility is maintained

#### Scenario: SNP FDR in generated YAML
- **GIVEN** a retry workflow is being generated
- **WHEN** the original workflow has `snp-fdr=0.05`
- **THEN** the generated YAML includes:
  - `snp-fdr` in arguments.parameters section
  - `snp-fdr` parameter passed to each trait task's templateRef arguments
- **AND** the workflow can be validated with `argo lint`

## MODIFIED Requirements

### Requirement: Retry Script Aggregation Flag

The `--aggregate` flag behavior SHALL change from local execution to in-cluster execution.

#### Scenario: Aggregate flag generates in-cluster task (CHANGED)
- **GIVEN** a user runs `retry-argo-traits.sh --aggregate --submit`
- **WHEN** the workflow is generated and submitted
- **THEN** aggregation runs as part of the Argo workflow (in-cluster)
- **AND** no local R script or RunAI CLI is required
- **AND** the script logs that aggregation will run after retries complete
