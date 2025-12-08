## ADDED Requirements

### Requirement: FDR-Controlled Significance Threshold

The system SHALL support False Discovery Rate (FDR) controlled significance thresholds for GWAS analysis via the `SNP_FDR` environment variable.

#### Scenario: FDR threshold specified
- **WHEN** `SNP_FDR` environment variable is set to a value (e.g., 0.05)
- **THEN** the GAPIT() call includes `SNP.FDR` parameter with the specified value
- **AND** runtime configuration logs display the FDR threshold
- **AND** GAPIT applies Benjamini-Hochberg correction at the specified threshold

#### Scenario: FDR threshold not specified
- **WHEN** `SNP_FDR` environment variable is empty or not set
- **THEN** the GAPIT() call does not include `SNP.FDR` parameter
- **AND** GAPIT uses default behavior (no FDR filtering)
- **AND** backward compatibility is maintained with existing pipelines

#### Scenario: FDR parameter validation
- **WHEN** `SNP_FDR` is set to a numeric value
- **THEN** value is validated to be between 0.0 and 1.0
- **AND** non-numeric values result in validation error with clear message

### Requirement: FDR Configuration Documentation

The system SHALL document the `SNP_FDR` configuration option in `.env.example`.

#### Scenario: Environment variable documentation
- **WHEN** user views `.env.example`
- **THEN** `SNP_FDR` is documented with usage examples
- **AND** relationship to `SNP_THRESHOLD` is explained
- **AND** recommended values (0.05, 0.1) are listed
