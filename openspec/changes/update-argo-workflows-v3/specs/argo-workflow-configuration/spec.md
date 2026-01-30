# argo-workflow-configuration Delta

## MODIFIED Requirements

### Requirement: Environment Variable Parameter Passing (v3.0.0)

The Argo WorkflowTemplate SHALL pass all runtime parameters to containers exclusively via environment variables using GAPIT v3.0.0 native parameter naming.

#### Scenario: MODEL parameter passed correctly (v3.0.0 naming)
- **WHEN** a workflow is submitted with `model: "BLINK,FarmCPU,MLM"` parameter
- **THEN** the container receives `MODEL=BLINK,FarmCPU,MLM` as an environment variable
- **AND** the entrypoint uses this value for GWAS analysis
- **AND** no CLI argument like `--model` is passed
- **AND** the parameter name is `model` (singular), not `models` (plural)

#### Scenario: PCA_TOTAL parameter passed correctly (v3.0.0 naming)
- **WHEN** a workflow is submitted with `pca-total: "3"` parameter
- **THEN** the container receives `PCA_TOTAL=3` as an environment variable
- **AND** the parameter name is `pca-total`, not `pca-components`

#### Scenario: SNP_MAF parameter passed correctly (v3.0.0 naming)
- **WHEN** a workflow is submitted with `snp-maf: "0.05"` parameter
- **THEN** the container receives `SNP_MAF=0.05` as an environment variable
- **AND** the parameter name is `snp-maf`, not `maf-filter`

#### Scenario: All v3.0.0 parameters visible in pod description
- **WHEN** a user runs `kubectl describe pod <pod-name>`
- **THEN** all configuration parameters are visible in the Environment section
- **AND** parameters use v3.0.0 naming: MODEL, PCA_TOTAL, SNP_MAF, SNP_FDR, KINSHIP_ALGORITHM, SNP_EFFECT, SNP_IMPUTE
- **AND** no deprecated parameter names (MODELS, PCA_COMPONENTS, MAF_FILTER) appear

### Requirement: Workflow Parameter Consistency with WorkflowTemplate

Workflow parameter names passed to WorkflowTemplates SHALL exactly match the parameter names defined in the WorkflowTemplate arguments.

#### Scenario: Test pipeline uses matching parameter names
- **GIVEN** the gapit3-gwas-single-trait WorkflowTemplate defines parameter `model`
- **WHEN** gapit3-test-pipeline.yaml calls the template
- **THEN** it passes `model: "BLINK,FarmCPU,MLM"` (not `models`)
- **AND** the parameter value is received correctly by the template

#### Scenario: Parallel pipeline uses matching parameter names
- **GIVEN** the gapit3-gwas-single-trait WorkflowTemplate defines parameter `model`
- **WHEN** gapit3-parallel-pipeline.yaml calls the template
- **THEN** it passes `model: "{{workflow.parameters.model}}"` (not `models`)
- **AND** workflow-level parameter is also named `model`

### Requirement: Parameterized Data File Paths

Argo Workflows SHALL accept parameterized file paths for genotype, phenotype, and accession ID files rather than hardcoding paths to specific datasets.

#### Scenario: Test pipeline accepts file path parameters
- **GIVEN** the gapit3-test-pipeline.yaml workflow
- **WHEN** a user wants to run with a different dataset
- **THEN** they can specify `genotype-file`, `phenotype-file`, and `accession-ids-file` parameters
- **AND** the workflow passes these paths to container environment variables
- **AND** default values match the original hardcoded paths for backwards compatibility

#### Scenario: Validate template uses parameterized paths
- **GIVEN** the validate template in gapit3-test-pipeline.yaml
- **WHEN** the template is executed
- **THEN** it uses `GENOTYPE_FILE={{workflow.parameters.genotype-file}}`
- **AND** it uses `PHENOTYPE_FILE={{workflow.parameters.phenotype-file}}`
- **AND** paths are not hardcoded in the template definition

#### Scenario: Extract-traits template uses parameterized paths
- **GIVEN** the extract-traits-inline template
- **WHEN** it extracts trait names
- **THEN** it uses the phenotype file path from workflow parameters
- **AND** the args reference `{{workflow.parameters.phenotype-file}}`
