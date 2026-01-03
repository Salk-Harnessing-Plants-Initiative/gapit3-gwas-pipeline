# runtime-configuration Specification Delta

## MODIFIED Requirements

### Requirement: Shell scripts MUST load configuration from .env file

All RunAI helper scripts MUST load configuration from `.env` file if present, with proper precedence.

#### Scenario: Script loads .env file
- **GIVEN** a `.env` file exists in project root with `PROJECT=talmo-lab`
- **WHEN** `submit-all-traits-runai.sh` runs
- **THEN** it should read PROJECT value from `.env`
- **AND** use that value for job submission

#### Scenario: Script works without .env file
- **GIVEN** no `.env` file exists
- **WHEN** `submit-all-traits-runai.sh` runs
- **THEN** it should use default values
- **AND** complete successfully

#### Scenario: Environment variables override .env file
- **GIVEN** `.env` file has `MODELS=BLINK`
- **AND** environment variable `MODELS=FarmCPU` is set
- **WHEN** the script runs
- **THEN** it should use `FarmCPU` (env var takes precedence)

#### Scenario: All GAPIT parameters loadable from .env
- **GIVEN** batch submission script
- **WHEN** GAPIT parameters are set in .env file
- **THEN** all parameters SHALL be loadable: `MODEL`, `PCA_TOTAL`, `SNP_MAF`, `SNP_FDR`, `KINSHIP_ALGORITHM`, `SNP_EFFECT`, `SNP_IMPUTE`, `SNP_P3D`, `CUTOFF`
- **AND** passed to each RunAI job submission
- **AND** displayed in submission summary