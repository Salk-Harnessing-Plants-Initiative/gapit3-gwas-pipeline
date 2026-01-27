# claude-skills Delta

## MODIFIED Requirements

### Requirement: RunAI Submission Skill Uses v3.0.0 Parameter Naming

The `/submit-runai-test` skill documentation SHALL use GAPIT v3.0.0 native parameter names in all example commands.

#### Scenario: Skill documents MODEL parameter correctly
- **GIVEN** the submit-runai-test.md skill documentation
- **WHEN** a user reads the example RunAI submit command
- **THEN** they see `--environment MODEL=BLINK,FarmCPU`
- **AND** they do NOT see `--environment MODELS=...` (deprecated)

#### Scenario: Skill documents PCA_TOTAL parameter correctly
- **GIVEN** the submit-runai-test.md skill documentation
- **WHEN** a user reads the example RunAI submit command
- **THEN** they see `--environment PCA_TOTAL=3`
- **AND** they do NOT see `--environment PCA_COMPONENTS=...` (deprecated)

#### Scenario: Skill documents SNP_MAF parameter correctly
- **GIVEN** the submit-runai-test.md skill documentation
- **WHEN** a user reads the example RunAI submit command
- **THEN** they see `--environment SNP_MAF=0.05`
- **AND** they do NOT see `--environment MAF_FILTER=...` (deprecated)

#### Scenario: Skill documents all v3.0.0 parameters
- **GIVEN** the submit-runai-test.md skill documentation
- **WHEN** a user reviews the example commands
- **THEN** they see environment variables for:
  - MODEL (not MODELS)
  - PCA_TOTAL (not PCA_COMPONENTS)
  - SNP_MAF (not MAF_FILTER)
  - SNP_FDR
  - SNP_THRESHOLD
  - KINSHIP_ALGORITHM
  - SNP_EFFECT
  - SNP_IMPUTE

### Requirement: Docker Test Skill Uses v3.0.0 Parameter Naming

The `/docker-test` skill documentation SHALL use GAPIT v3.0.0 native parameter names in all example commands.

#### Scenario: Docker test uses MODEL parameter
- **GIVEN** the docker-test.md skill documentation
- **WHEN** a user reads the environment variable test example
- **THEN** they see `-e MODEL=BLINK` (not `-e MODELS=BLINK`)
- **AND** the grep pattern matches `MODEL|PCA_TOTAL|SNP_MAF`
