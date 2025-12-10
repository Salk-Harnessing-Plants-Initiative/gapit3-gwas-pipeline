# documentation Specification

## Purpose

Standards for repository documentation: discoverability, organization, accuracy, and presentation-readiness.
## Requirements
### Requirement: Configuration Discoverability

The documentation SHALL make runtime configuration options easily discoverable within 30 seconds.

#### Scenario: User needs to configure analysis
- **WHEN** a user wants to customize GWAS parameters
- **THEN** README.md links to `.env.example` in a visible "Configuration" section
- **AND** `.env.example` serves as the authoritative parameter reference

#### Scenario: User finds parameter documentation
- **WHEN** a user searches for a specific parameter (e.g., MODELS, PCA_COMPONENTS)
- **THEN** `.env.example` contains the parameter with description, default, and valid values
- **AND** `docs/USAGE.md` provides a quick reference table linking to `.env.example`

---

### Requirement: Succinct Quick Start

The QUICKSTART.md SHALL provide essential setup instructions in under 50 lines.

#### Scenario: New user gets started
- **WHEN** a new user opens QUICKSTART.md
- **THEN** they find prerequisites, clone, configure, and run commands
- **AND** the essential content fits in under 50 lines
- **AND** detailed explanations link to other docs

#### Scenario: Experienced user references quick start
- **WHEN** an experienced user needs a command reminder
- **THEN** QUICKSTART.md provides copy-paste commands without scrolling through explanations

---

### Requirement: Dataset-Agnostic Documentation

Documentation SHALL treat dataset-specific values (trait counts, sample sizes) as examples, not specifications.

#### Scenario: User with different dataset
- **WHEN** a user analyzes a dataset with different trait count
- **THEN** documentation uses phrases like "your traits (e.g., 184 in iron dataset)"
- **AND** documentation explains trait count comes from phenotype file columns

#### Scenario: Documentation audit for hardcoded values
- **WHEN** documentation is searched for trait counts
- **THEN** all occurrences are clearly marked as examples
- **AND** no text implies a fixed pipeline limitation

---

### Requirement: Usage Reference

The documentation SHALL provide a `docs/USAGE.md` that serves as a quick parameter reference.

#### Scenario: User checks parameter options
- **WHEN** a user needs to see available parameters
- **THEN** `docs/USAGE.md` provides a table of key parameters
- **AND** links to `.env.example` for full documentation
- **AND** includes 3-4 common configuration recipes

---

### Requirement: Data Format Reference

The documentation SHALL provide `docs/DATA_REQUIREMENTS.md` describing input/output formats.

#### Scenario: User prepares input data
- **WHEN** a user needs to format input files
- **THEN** `docs/DATA_REQUIREMENTS.md` specifies HapMap and phenotype formats
- **AND** uses example values without hardcoding dataset-specific counts

#### Scenario: User interprets outputs
- **WHEN** a user examines GWAS results
- **THEN** `docs/DATA_REQUIREMENTS.md` describes output file formats
- **AND** explains column meanings in results files

---

### Requirement: Documentation Index

The documentation SHALL provide a navigation index (`docs/INDEX.md`) with one-line descriptions.

#### Scenario: User navigates documentation
- **WHEN** a user opens docs/ folder
- **THEN** INDEX.md lists all documentation files
- **AND** each file has a one-line description
- **AND** suggests reading order by user type

---

### Requirement: Consolidated Demo Guide

The documentation SHALL provide a single `docs/DEMO_GUIDE.md` consolidating demo content.

#### Scenario: Presenter prepares demo
- **WHEN** a user prepares to demonstrate the pipeline
- **THEN** DEMO_GUIDE.md provides copy-paste commands
- **AND** consolidates content from QUICK_DEMO.md and DEMO_COMMANDS.md
- **AND** redundant demo files are archived

---

### Requirement: Documentation Link Integrity

README and documentation files SHALL NOT contain broken internal links.

#### Scenario: User follows documentation link
- **WHEN** a user clicks any link in README.md
- **THEN** the linked file exists (USAGE.md, DATA_REQUIREMENTS.md, etc.)
- **AND** the link resolves to relevant content

---

### Requirement: Current Status Accuracy

Documentation status sections SHALL accurately reflect operational state.

#### Scenario: User checks system status
- **WHEN** a user reads README.md or QUICKSTART.md
- **THEN** status reflects reality (RBAC resolved, Argo operational)
- **AND** no "pending" warnings for resolved issues
- **AND** workarounds presented as alternatives, not primary methods

