## ADDED Requirements

### Requirement: Pipeline Overview for Newcomers

README SHALL provide a high-level pipeline overview that explains what GWAS does and how this pipeline helps.

#### Scenario: Newcomer understands the pipeline
- **WHEN** a user unfamiliar with GWAS reads the README
- **THEN** they find a "Pipeline Overview" section near the top
- **AND** it explains GWAS in 1-2 sentences (identifies genetic variants associated with traits)
- **AND** it shows a simple data flow diagram (Genotype + Phenotype → Models → Results)
- **AND** it lists what outputs they will get (Manhattan plots, QQ plots, significant SNPs)

#### Scenario: User finds technical details
- **WHEN** a user wants to understand the technical implementation
- **THEN** the overview links to `docs/WORKFLOW_ARCHITECTURE.md` for Kubernetes/Argo details
- **AND** links to GAPIT3 documentation for algorithm details

#### Scenario: User understands model choices
- **WHEN** a user reads about GWAS models (BLINK, FarmCPU, MLM)
- **THEN** the overview provides brief descriptions or links to GAPIT3 docs
- **AND** does NOT duplicate algorithm descriptions from GAPIT3

---

### Requirement: Species-Agnostic Language

Documentation SHALL use species-agnostic language that makes the pipeline's generality clear.

#### Scenario: User with non-Arabidopsis dataset
- **WHEN** a user reads documentation with a maize, rice, or human dataset
- **THEN** documentation uses "plants and other organisms" or "your organism"
- **AND** Arabidopsis references are clearly marked as "reference dataset example"
- **AND** no text implies the pipeline only works for Arabidopsis

#### Scenario: README describes pipeline scope
- **WHEN** a user reads the README Features or description
- **THEN** species mentioned are examples, not limitations
- **AND** language emphasizes "any HapMap-compatible genotype data"

---

### Requirement: Dynamic Trait Count Documentation

Documentation SHALL explain that trait count is determined dynamically from the phenotype file.

#### Scenario: User understands trait detection
- **WHEN** a user reads about pipeline configuration
- **THEN** documentation explains traits are columns 2-N in phenotype file
- **AND** "184 traits" or similar counts are marked as "(e.g., 184 in reference dataset)"
- **AND** workflow parameters `start-trait-index` and `end-trait-index` are explained

#### Scenario: Architecture diagram accuracy
- **WHEN** a user views the pipeline architecture diagram
- **THEN** diagram shows "N parallel GWAS jobs" not "184 parallel jobs"
- **AND** a note explains N equals phenotype file columns minus Taxa column

---

### Requirement: Kubernetes Permissions Reference

Documentation SHALL provide a consolidated Kubernetes permissions reference.

#### Scenario: Cluster administrator sets up permissions
- **WHEN** an administrator configures the cluster for the pipeline
- **THEN** `docs/KUBERNETES_PERMISSIONS.md` lists all required permissions
- **AND** ServiceAccount requirements are specified (default SA for workflowtaskresults)
- **AND** RBAC roles and bindings are documented
- **AND** verification commands are provided

#### Scenario: User troubleshoots permission errors
- **WHEN** a user encounters "forbidden" or permission-denied errors
- **THEN** KUBERNETES_PERMISSIONS.md has a troubleshooting section
- **AND** common errors map to specific permission fixes

---

### Requirement: Resource Sizing Methodology

Documentation SHALL explain the methodology for determining computational resource requirements.

#### Scenario: User sizes resources for their dataset
- **WHEN** a user has a dataset of S samples and M SNPs
- **THEN** `docs/RESOURCE_SIZING.md` provides formulas for memory estimation
- **AND** explains: base memory + (S x M x 8 bytes) for numeric matrix
- **AND** provides examples for small (100 samples), medium (500), and large (1000+) datasets

#### Scenario: User chooses between templates
- **WHEN** a user decides between standard and high-mem templates
- **THEN** documentation explains when each is appropriate
- **AND** criteria include: dataset size, model complexity (MLM > FarmCPU > BLINK)
- **AND** OOMKilled error handling is documented

---

### Requirement: Documentation Contribution Standards

Documentation SHALL provide guidelines for maintaining species/dataset agnostic content.

#### Scenario: Contributor adds documentation
- **WHEN** a contributor writes or updates documentation
- **THEN** `docs/CONTRIBUTING_DOCS.md` provides a checklist
- **AND** checklist includes: "Are counts marked as examples?"
- **AND** checklist includes: "Is language species-agnostic?"
- **AND** pattern provided: "N traits (e.g., 184 in reference dataset)"

#### Scenario: Documentation review
- **WHEN** documentation changes are reviewed
- **THEN** reviewers check against contribution standards
- **AND** hardcoded dataset-specific values are flagged

---

### Requirement: Example Value Marking Convention

Documentation SHALL clearly distinguish example values from specifications.

#### Scenario: User interprets numeric values
- **WHEN** documentation contains sample counts, trait counts, or SNP counts
- **THEN** example values use format: "N items (e.g., 546 samples in reference dataset)"
- **AND** specification values (minimums, defaults) are clearly labeled as such
- **AND** tables distinguish "Example" vs "Specification" columns

#### Scenario: Historical changelog entries
- **WHEN** CHANGELOG.md contains dataset-specific values
- **THEN** these are preserved for historical accuracy
- **AND** changelog is exempt from generalization requirements

---

### Requirement: Scripts Reference Documentation

Documentation SHALL provide a comprehensive reference for all R scripts and their parameters following DRY principles.

#### Scenario: User needs to understand script parameters
- **WHEN** a user wants to know what parameters a script accepts
- **THEN** `docs/SCRIPTS_REFERENCE.md` documents each script with:
  - Purpose and description
  - All parameters (env var name, CLI flag, type, default, valid values)
  - Effect on analysis
  - Output files produced

#### Scenario: User configures GWAS models
- **WHEN** a user wants to understand model options (BLINK, FarmCPU, MLM, etc.)
- **THEN** SCRIPTS_REFERENCE.md explains each model's characteristics:
  - Speed vs accuracy trade-offs
  - Memory requirements
  - When to use each model
- **AND** links to official GAPIT3 documentation for detailed algorithm descriptions

#### Scenario: User troubleshoots script errors
- **WHEN** a user encounters an error from an R script
- **THEN** SCRIPTS_REFERENCE.md has a troubleshooting section
- **AND** common errors are documented with solutions
- **AND** exit codes are explained

#### Scenario: DRY principle compliance
- **WHEN** parameter information is needed elsewhere in documentation
- **THEN** other docs link to SCRIPTS_REFERENCE.md or .env.example
- **AND** parameter details are not duplicated across multiple files

---

### Requirement: GAPIT3 Upstream Documentation References

Documentation SHALL link to official GAPIT3 documentation for algorithm details and advanced parameters.

#### Scenario: User needs algorithm details
- **WHEN** a user wants to understand how BLINK, FarmCPU, or MLM algorithms work
- **THEN** documentation links to:
  - Official GAPIT User Manual: https://zzlab.net/GAPIT/gapit_help_document.pdf
  - GAPIT3 GitHub repository: https://github.com/jiabowang/GAPIT
  - GAPIT3 publication: Wang & Zhang (2021) Genomics, Proteomics & Bioinformatics
- **AND** pipeline documentation does NOT duplicate algorithm descriptions

#### Scenario: User needs advanced GAPIT parameters
- **WHEN** a user wants to configure advanced GAPIT3 parameters not exposed by the pipeline
- **THEN** SCRIPTS_REFERENCE.md explains which parameters are exposed
- **AND** links to GAPIT documentation for full parameter list
- **AND** notes that advanced parameters require script modification

#### Scenario: Model selection guidance
- **WHEN** a user needs to choose between GWAS models
- **THEN** documentation provides a decision table with:
  - BLINK: Fastest, highest power, recommended default
  - FarmCPU: Good balance of speed and accuracy, controls false positives
  - MLM: Traditional approach, more conservative, higher memory
  - MLMM, SUPER, CMLM: Specialized use cases (link to GAPIT docs)
- **AND** references GAPIT documentation for detailed model comparisons

---

### Requirement: Single Source of Truth for Parameters

Documentation SHALL follow DRY principles with designated authoritative sources.

#### Scenario: User looks up parameter defaults
- **WHEN** a user needs the default value for a parameter
- **THEN** `.env.example` is the single source of truth for parameter defaults
- **AND** other documentation links to .env.example rather than duplicating values

#### Scenario: Contributor updates parameter documentation
- **WHEN** a contributor changes a parameter default or adds a new parameter
- **THEN** they update `.env.example` first (authoritative source)
- **AND** `docs/SCRIPTS_REFERENCE.md` second (behavior documentation)
- **AND** other references are links, not copies

---

## MODIFIED Requirements

### Requirement: Dataset-Agnostic Documentation

Documentation SHALL treat dataset-specific values (trait counts, sample sizes, species) as examples, not specifications.

#### Scenario: User with different dataset
- **WHEN** a user analyzes a dataset with different trait count
- **THEN** documentation uses phrases like "N traits (e.g., 184 in reference dataset)"
- **AND** documentation explains trait count comes from phenotype file columns
- **AND** species names are marked as examples where they appear

#### Scenario: Documentation audit for hardcoded values
- **WHEN** documentation is searched for trait counts, sample counts, or species
- **THEN** all occurrences are clearly marked as examples
- **AND** no text implies a fixed pipeline limitation
- **AND** file names used as examples are noted as customizable

#### Scenario: Resource requirements table
- **WHEN** a user reads computational requirements
- **THEN** the table header includes dataset size reference (e.g., "Based on 546 samples, 1.4M SNPs")
- **AND** scaling guidance is provided for different dataset sizes
- **AND** methodology for determining resources is linked
