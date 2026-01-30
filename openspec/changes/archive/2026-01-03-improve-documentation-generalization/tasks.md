## 1. Audit and Document Hardcoded Values

- [x] 1.1 Create comprehensive list of all hardcoded values in documentation
  - Trait counts: 184, 186, 187
  - Sample counts: 546
  - SNP counts: 1.4M, 1,400,000
  - Species: Arabidopsis thaliana
  - File names: iron_traits_edited.txt, acc_snps_filtered_maf_perl_edited_diploid.hmp.txt
- [x] 1.2 Categorize each occurrence as:
  - Example (should be marked as such)
  - Historical (CHANGELOG - keep as-is)
  - Specification (should be parameterized)

## 2. Generalize README.md

- [x] 2.1 Update Features section - change "Run 184 traits" to "Run N traits"
- [x] 2.2 Update Architecture diagram - show dynamic trait count from phenotype file
- [x] 2.3 Update Quick Start - use placeholder paths and trait counts
- [x] 2.4 Update Requirements section - explain resource sizing methodology
- [x] 2.5 Update Example Workflow - use generic examples with notes about customization
- [x] 2.6 Update Performance section - explain benchmarks are for reference dataset
- [x] 2.7 Add "Pipeline Overview" section after Features:
  - What is GWAS? (brief explanation for newcomers)
  - High-level data flow diagram
  - What you get at the end (outputs summary)
  - Link to docs/WORKFLOW_ARCHITECTURE.md for technical details
  - Link to GAPIT3 documentation for algorithm details

## 3. Create Kubernetes Permissions Documentation

- [x] 3.1 Create `docs/KUBERNETES_PERMISSIONS.md` with:
  - Required ServiceAccounts and their purposes
  - RBAC roles needed for Argo Workflows
  - Namespace-level permissions
  - Volume access requirements
  - Common permission errors and solutions
- [x] 3.2 Consolidate info from `docs/argo-service-accounts.md` and `docs/RBAC_PERMISSIONS_ISSUE.md`
- [x] 3.3 Add verification commands for checking permissions

## 4. Create Resource Sizing Documentation

- [x] 4.1 Create `docs/RESOURCE_SIZING.md` with:
  - Methodology for determining resource requirements
  - Memory scaling formula (samples x SNPs x bytes)
  - CPU scaling considerations
  - Disk space estimation
  - Examples for small/medium/large datasets
- [x] 4.2 Document when to use standard vs high-mem templates
- [x] 4.3 Add troubleshooting for OOMKilled errors

## 5. Update Data Requirements Documentation

- [x] 5.1 Update `docs/DATA_REQUIREMENTS.md`:
  - Remove hardcoded sample/trait/SNP counts
  - Use format specifications only
  - Add "Example values" sections clearly marked
- [x] 5.2 Ensure HapMap format is species-agnostic
- [x] 5.3 Add section on trait count detection from phenotype file

## 6. Create R Scripts Reference Documentation

- [x] 6.1 Create `docs/SCRIPTS_REFERENCE.md` with comprehensive script documentation:
  - **run_gwas_single_trait.R**: Core GWAS execution script
  - **collect_results.R**: Results aggregation script
  - **validate_inputs.R**: Pre-flight validation
  - **extract_trait_names.R**: Trait manifest generator
  - **entrypoint.sh**: Container entrypoint
- [x] 6.2 Document parameter interactions and dependencies
- [x] 6.3 Add troubleshooting section for common script errors
- [x] 6.4 Link from README.md and docs/INDEX.md
- [x] 6.5 Add GAPIT3 upstream documentation references:
  - Link to official GAPIT User Manual
  - Link to GAPIT3 GitHub
  - Link to GAPIT3 publication
  - Create model selection decision table
  - Note which GAPIT parameters are exposed vs require script modification
- [x] 6.6 Add Duplicate Handling section documenting phenotype and result deduplication

## 7. Create Documentation Standards Guide (DRY/Agile)

- [x] 7.1 Create `docs/CONTRIBUTING_DOCS.md` with:
  - **DRY principles**: Single source of truth for each concept
  - **Link, don't duplicate**: Use relative links instead of copying content
  - Guidelines for example values vs specifications
  - Checklist for documentation changes
  - Species-agnostic language patterns
- [x] 7.2 Add documentation review checklist

## 8. Update Project Context Files

- [x] 8.1 Update `openspec/project.md`:
  - Change "specifically Arabidopsis thaliana" to "plants and other organisms"
  - Mark production use case as example
  - Update domain context to be species-agnostic
- [x] 8.2 Update `.claude.md`:
  - Remove dataset-specific assumptions
  - Add guidance for species-agnostic responses

## 9. Update Existing Documentation Files

- [x] 9.1 Update `docs/ARGO_SETUP.md` - generalize examples
- [x] 9.2 Update `docs/METADATA_SCHEMA.md` - ensure examples are marked as such (kept as-is, examples are clearly labeled)
- [x] 9.3 Update `docs/WORKFLOW_ARCHITECTURE.md` - dynamic trait count
- [x] 9.4 Review and update `QUICKSTART.md` files (kept as-is, no hardcoded dataset values)

## 10. Validation and Testing

- [x] 10.1 Run documentation link checker (manual review completed)
- [x] 10.2 Grep for remaining hardcoded values (key files updated, some examples preserved in demo/quickref docs)
- [x] 10.3 Review all changes for consistency
- [x] 10.4 Update `docs/INDEX.md` with new files