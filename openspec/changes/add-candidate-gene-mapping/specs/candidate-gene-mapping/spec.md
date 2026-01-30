## ADDED Requirements

### Requirement: Candidate Gene Mapping Script

The system SHALL provide an R script that maps significant GWAS SNPs to nearby candidate genes using genomic coordinates.

#### Scenario: Map SNPs to genes with default window
- **WHEN** `run-candidate-gene-mapping` command is executed
- **AND** aggregated GWAS results file exists at expected path
- **THEN** script loads significant SNPs from `GAPIT.Association.Filter_GWAS_results.csv`
- **AND** calculates genomic regions (SNP position ± 5kb by default)
- **AND** identifies genes overlapping those regions using Araport11 annotations
- **AND** outputs `candidate_genes.csv` with SNP-gene associations

#### Scenario: Configurable genomic window
- **WHEN** `GENE_WINDOW_KB` environment variable is set (e.g., 10)
- **THEN** script uses specified window size (±10kb) for region calculation
- **AND** larger window captures more distant candidate genes

#### Scenario: No significant SNPs
- **WHEN** GWAS results file contains no significant SNPs
- **THEN** script completes successfully
- **AND** outputs empty candidate_genes.csv with headers only
- **AND** logs informative message about zero significant SNPs

### Requirement: Gene Annotation Database

The system SHALL include or accept the Araport11 gene annotation database for Arabidopsis thaliana gene mapping.

#### Scenario: Gene annotation file available
- **WHEN** candidate gene mapping runs
- **THEN** `GeneInfoFile.csv` is available (bundled or mounted)
- **AND** contains columns: chr, agi, start, end, strand, symbol, name, description, summary
- **AND** covers all 5 Arabidopsis chromosomes

#### Scenario: Custom annotation file
- **WHEN** `GENE_ANNOTATION_FILE` environment variable is set
- **THEN** script uses specified annotation file instead of default
- **AND** validates required columns exist

### Requirement: Candidate Gene Output Format

The system SHALL output candidate genes in a standardized CSV format with SNP and gene metadata.

#### Scenario: Output CSV schema
- **WHEN** candidate gene mapping completes
- **THEN** `candidate_genes.csv` contains columns:
  - region, chr, snp, pos, p.value, log10, maf, traits (from GWAS)
  - start, end (genomic window boundaries)
  - agi, strand, symbol, name, description, summary (from gene annotations)
- **AND** one row per SNP-gene pair (SNPs may appear multiple times if near multiple genes)

#### Scenario: Output includes -log10 p-value
- **WHEN** output is generated
- **THEN** `log10` column contains -log10(p.value) for plotting convenience
- **AND** original p.value is preserved

### Requirement: Candidate Gene Mapping Entrypoint Command

The system SHALL provide `run-candidate-gene-mapping` as an entrypoint command.

#### Scenario: Command execution
- **WHEN** container runs with `run-candidate-gene-mapping` command
- **THEN** entrypoint validates required files exist
- **AND** executes `map_candidate_genes.R` script
- **AND** logs configuration and progress

#### Scenario: Missing input file
- **WHEN** aggregated GWAS results file does not exist
- **THEN** container exits with error code 1
- **AND** displays clear error message with expected file path

### Requirement: Candidate Gene Mapping Documentation

The system SHALL document the candidate gene mapping workflow in `.env.example` and README.

#### Scenario: Environment variable documentation
- **WHEN** user views `.env.example`
- **THEN** `GENE_WINDOW_KB` is documented with default value (5)
- **AND** `GENE_ANNOTATION_FILE` is documented as optional override
- **AND** usage examples show how to run candidate gene mapping

#### Scenario: Workflow documentation
- **WHEN** user views README
- **THEN** candidate gene mapping is documented as post-aggregation step
- **AND** required input files are listed
- **AND** output file format is described
