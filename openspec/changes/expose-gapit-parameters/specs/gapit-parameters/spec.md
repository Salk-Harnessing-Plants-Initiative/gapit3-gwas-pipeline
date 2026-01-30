# gapit-parameters Specification

## Purpose

Define the complete set of GAPIT parameters exposed by the pipeline, their validation rules, and behavior. All parameter names match GAPIT's native naming convention (with `.` replaced by `_` for environment variables).

## ADDED Requirements

### Requirement: Pipeline SHALL use GAPIT-consistent parameter naming

All environment variables and CLI options SHALL use names derived from GAPIT's native parameter names to eliminate confusion and ensure reproducibility.

#### Scenario: Environment variable naming matches GAPIT
- **GIVEN** GAPIT parameter `SNP.MAF`
- **WHEN** exposing as environment variable
- **THEN** the variable SHALL be named `SNP_MAF`
- **AND** the CLI option SHALL be named `--snp-maf`

#### Scenario: Model parameter uses GAPIT naming
- **GIVEN** GAPIT parameter `model`
- **WHEN** exposing as environment variable
- **THEN** the variable SHALL be named `MODEL` (not `MODELS`)
- **AND** accepts comma-separated values for multiple models

#### Scenario: PCA parameter uses GAPIT naming
- **GIVEN** GAPIT parameter `PCA.total`
- **WHEN** exposing as environment variable
- **THEN** the variable SHALL be named `PCA_TOTAL` (not `PCA_COMPONENTS`)

### Requirement: Pipeline SHALL expose core GAPIT model parameters

The following core parameters SHALL be configurable via environment variables.

#### Scenario: MODEL parameter configures GWAS method
- **GIVEN** `MODEL` environment variable
- **WHEN** set to valid value(s) (e.g., `BLINK,FarmCPU,MLM`)
- **THEN** GAPIT runs specified model(s)
- **AND** results include output from each model
- **AND** metadata records the model(s) used

#### Scenario: MODEL parameter validation
- **GIVEN** `MODEL=INVALID`
- **WHEN** container starts
- **THEN** exit with code 1
- **AND** display valid options: GLM, MLM, CMLM, MLMM, SUPER, FarmCPU, BLINK

#### Scenario: PCA_TOTAL parameter configures population structure correction
- **GIVEN** `PCA_TOTAL=5`
- **WHEN** container runs
- **THEN** GAPIT uses 5 principal components
- **AND** metadata records `PCA.total: 5`

#### Scenario: PCA_TOTAL validation
- **GIVEN** `PCA_TOTAL=100`
- **WHEN** container starts
- **THEN** exit with code 1
- **AND** indicate valid range is 0-20

#### Scenario: MULTIPLE_ANALYSIS parameter
- **GIVEN** `MULTIPLE_ANALYSIS=TRUE`
- **WHEN** container runs with multiple traits
- **THEN** GAPIT processes all traits automatically

### Requirement: Pipeline SHALL expose SNP filtering parameters

SNP quality control parameters SHALL be configurable.

#### Scenario: SNP_MAF filters by minor allele frequency
- **GIVEN** `SNP_MAF=0.05`
- **WHEN** GAPIT runs
- **THEN** SNPs with MAF < 0.05 are excluded
- **AND** filtering is logged: "Applying MAF threshold: 0.05"
- **AND** metadata records `SNP.MAF: 0.05`

#### Scenario: SNP_MAF=0 disables MAF filtering
- **GIVEN** `SNP_MAF=0` or not set
- **WHEN** GAPIT runs
- **THEN** no MAF filtering is applied
- **AND** all SNPs are included regardless of MAF

#### Scenario: SNP_MAF validation
- **GIVEN** `SNP_MAF=0.6`
- **WHEN** container starts
- **THEN** exit with code 1
- **AND** indicate valid range is 0.0-0.5

#### Scenario: SNP_FDR controls FDR threshold
- **GIVEN** `SNP_FDR=0.05`
- **WHEN** GAPIT runs
- **THEN** Benjamini-Hochberg correction applied at 5% FDR
- **AND** Filter results file contains only SNPs meeting threshold
- **AND** metadata records `SNP.FDR: 0.05`

#### Scenario: SNP_FDR=1 disables FDR filtering
- **GIVEN** `SNP_FDR=1` or not set
- **WHEN** GAPIT runs
- **THEN** all SNPs included in output (no FDR filtering)

#### Scenario: CUTOFF parameter for significance
- **GIVEN** `CUTOFF=0.01`
- **WHEN** GAPIT runs
- **THEN** significance threshold set to 0.01
- **AND** affects which SNPs are reported as significant

### Requirement: Pipeline SHALL expose kinship parameters

Kinship matrix calculation parameters SHALL be configurable.

#### Scenario: KINSHIP_ALGORITHM selects calculation method
- **GIVEN** `KINSHIP_ALGORITHM=VanRaden`
- **WHEN** GAPIT runs
- **THEN** VanRaden method used for kinship calculation
- **AND** metadata records `kinship.algorithm: VanRaden`

#### Scenario: KINSHIP_ALGORITHM validation
- **GIVEN** `KINSHIP_ALGORITHM=Invalid`
- **WHEN** container starts
- **THEN** exit with code 1
- **AND** display valid options: VanRaden, Zhang, Loiselle, EMMA

#### Scenario: KINSHIP_ALGORITHM default
- **GIVEN** `KINSHIP_ALGORITHM` not set
- **WHEN** container runs
- **THEN** Zhang method used (GAPIT default)

### Requirement: Pipeline SHALL expose SNP effect model parameters

Genetic model parameters SHALL be configurable.

#### Scenario: SNP_EFFECT selects genetic model
- **GIVEN** `SNP_EFFECT=Add`
- **WHEN** GAPIT runs
- **THEN** additive genetic model used
- **AND** genotypes coded as 0, 1, 2

#### Scenario: SNP_EFFECT=Dom for dominance
- **GIVEN** `SNP_EFFECT=Dom`
- **WHEN** GAPIT runs
- **THEN** dominance genetic model used
- **AND** appropriate for traits with dominance effects

#### Scenario: SNP_EFFECT validation
- **GIVEN** `SNP_EFFECT=Invalid`
- **WHEN** container starts
- **THEN** exit with code 1
- **AND** display valid options: Add, Dom

#### Scenario: SNP_IMPUTE selects imputation method
- **GIVEN** `SNP_IMPUTE=Major`
- **WHEN** GAPIT encounters missing genotypes
- **THEN** imputes with major allele
- **AND** metadata records `SNP.impute: Major`

#### Scenario: SNP_IMPUTE validation
- **GIVEN** `SNP_IMPUTE=Invalid`
- **WHEN** container starts
- **THEN** exit with code 1
- **AND** display valid options: Middle, Major, Minor

#### Scenario: SNP_P3D for computational efficiency
- **GIVEN** `SNP_P3D=TRUE`
- **WHEN** GAPIT runs
- **THEN** P3D method used for faster SNP testing
- **AND** variance components estimated once

### Requirement: Pipeline SHALL support deprecated parameter names

For backward compatibility, deprecated names SHALL be accepted with warnings.

#### Scenario: MODELS accepted as deprecated alias
- **GIVEN** `MODELS=BLINK` and `MODEL` not set
- **WHEN** container starts
- **THEN** `MODEL` set to `BLINK`
- **AND** warning logged: "MODELS is deprecated, use MODEL"

#### Scenario: PCA_COMPONENTS accepted as deprecated alias
- **GIVEN** `PCA_COMPONENTS=3` and `PCA_TOTAL` not set
- **WHEN** container starts
- **THEN** `PCA_TOTAL` set to `3`
- **AND** warning logged: "PCA_COMPONENTS is deprecated, use PCA_TOTAL"

#### Scenario: MAF_FILTER accepted as deprecated alias
- **GIVEN** `MAF_FILTER=0.05` and `SNP_MAF` not set
- **WHEN** container starts
- **THEN** `SNP_MAF` set to `0.05`
- **AND** warning logged: "MAF_FILTER is deprecated, use SNP_MAF"

#### Scenario: New name takes precedence over deprecated
- **GIVEN** `MODEL=BLINK` and `MODELS=FarmCPU`
- **WHEN** container starts
- **THEN** `MODEL=BLINK` used (new name wins)
- **AND** no deprecation warning

### Requirement: Metadata SHALL record all GAPIT parameters

All GAPIT parameters SHALL be recorded in metadata using GAPIT's native naming.

#### Scenario: Metadata uses GAPIT parameter names
- **GIVEN** successful GWAS execution
- **WHEN** metadata.json is written
- **THEN** parameters section uses GAPIT names:
  ```json
  {
    "parameters": {
      "gapit": {
        "model": ["BLINK", "FarmCPU"],
        "PCA.total": 3,
        "SNP.MAF": 0.05,
        "SNP.FDR": 0.05,
        "kinship.algorithm": "VanRaden",
        "SNP.effect": "Add",
        "SNP.impute": "Middle"
      }
    }
  }
  ```

#### Scenario: Metadata includes all configured parameters
- **GIVEN** multiple parameters configured
- **WHEN** metadata.json is written
- **THEN** all parameters are recorded
- **AND** default values are recorded when not explicitly set
- **AND** enables exact reproduction of analysis

### Requirement: Configuration display SHALL show all parameters

Runtime configuration output SHALL display all GAPIT parameters.

#### Scenario: Configuration logged at startup
- **GIVEN** container starts with custom parameters
- **WHEN** runtime configuration is displayed
- **THEN** all parameters shown with current values
- **AND** grouped by category (Model, Filtering, Kinship, etc.)
- **AND** indicates which are defaults vs. user-specified

### Requirement: Documentation SHALL provide complete parameter reference

Documentation SHALL describe all parameters with examples.

#### Scenario: GAPIT_PARAMETERS.md exists
- **GIVEN** docs directory
- **THEN** GAPIT_PARAMETERS.md SHALL exist
- **AND** document every exposed parameter
- **AND** include GAPIT default vs. pipeline default
- **AND** provide usage examples
- **AND** explain parameter relationships

#### Scenario: .env.example documents all parameters
- **GIVEN** .env.example file
- **THEN** all GAPIT parameters SHALL be listed
- **AND** grouped by category with comments
- **AND** show default values
- **AND** include valid options for enums

