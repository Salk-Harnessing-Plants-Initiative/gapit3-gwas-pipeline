## 1. Audit and Document Hardcoded Values

- [ ] 1.1 Create comprehensive list of all hardcoded values in documentation
  - Trait counts: 184, 186, 187
  - Sample counts: 546
  - SNP counts: 1.4M, 1,400,000
  - Species: Arabidopsis thaliana
  - File names: iron_traits_edited.txt, acc_snps_filtered_maf_perl_edited_diploid.hmp.txt
- [ ] 1.2 Categorize each occurrence as:
  - Example (should be marked as such)
  - Historical (CHANGELOG - keep as-is)
  - Specification (should be parameterized)

## 2. Generalize README.md

- [ ] 2.1 Update Features section - change "Run 184 traits" to "Run N traits"
- [ ] 2.2 Update Architecture diagram - show dynamic trait count from phenotype file
- [ ] 2.3 Update Quick Start - use placeholder paths and trait counts
- [ ] 2.4 Update Requirements section - explain resource sizing methodology
- [ ] 2.5 Update Example Workflow - use generic examples with notes about customization
- [ ] 2.6 Update Performance section - explain benchmarks are for reference dataset
- [ ] 2.7 Add "Pipeline Overview" section after Features:
  - What is GWAS? (brief explanation for newcomers)
  - High-level data flow diagram:
    ```
    Genotype (HapMap) + Phenotype (traits)
           ↓
    GAPIT3 Models (BLINK, FarmCPU, MLM)
           ↓
    Significant SNPs + Manhattan/QQ Plots + Metadata
    ```
  - What you get at the end (outputs summary)
  - Link to docs/WORKFLOW_ARCHITECTURE.md for technical details
  - Link to GAPIT3 documentation for algorithm details

## 3. Create Kubernetes Permissions Documentation

- [ ] 3.1 Create `docs/KUBERNETES_PERMISSIONS.md` with:
  - Required ServiceAccounts and their purposes
  - RBAC roles needed for Argo Workflows
  - Namespace-level permissions
  - Volume access requirements
  - Common permission errors and solutions
- [ ] 3.2 Consolidate info from `docs/argo-service-accounts.md` and `docs/RBAC_PERMISSIONS_ISSUE.md`
- [ ] 3.3 Add verification commands for checking permissions

## 4. Create Resource Sizing Documentation

- [ ] 4.1 Create `docs/RESOURCE_SIZING.md` with:
  - Methodology for determining resource requirements
  - Memory scaling formula (samples x SNPs x bytes)
  - CPU scaling considerations
  - Disk space estimation
  - Examples for small/medium/large datasets
- [ ] 4.2 Document when to use standard vs high-mem templates
- [ ] 4.3 Add troubleshooting for OOMKilled errors

## 5. Update Data Requirements Documentation

- [ ] 5.1 Update `docs/DATA_REQUIREMENTS.md`:
  - Remove hardcoded sample/trait/SNP counts
  - Use format specifications only
  - Add "Example values" sections clearly marked
- [ ] 5.2 Ensure HapMap format is species-agnostic
- [ ] 5.3 Add section on trait count detection from phenotype file

## 6. Create R Scripts Reference Documentation

- [ ] 6.1 Create `docs/SCRIPTS_REFERENCE.md` with comprehensive script documentation:
  - **run_gwas_single_trait.R**: Core GWAS execution script
    - Parameters: TRAIT_INDEX, MODELS, PCA_COMPONENTS, MAF_FILTER, SNP_FDR, MULTIPLE_ANALYSIS
    - Model options: BLINK (fast), FarmCPU (accurate), MLM (comprehensive), MLMM, SUPER, CMLM
    - Output files: Manhattan plots, QQ plots, GWAS results CSV, metadata JSON
  - **collect_results.R**: Results aggregation script
    - Parameters: --output-dir, --threshold, --models, --allow-incomplete, --markdown-only
    - Aggregation logic: reads Filter files, tracks model provenance
    - Output: summary_table.csv, all_traits_significant_snps.csv, summary_stats.json, pipeline_summary.md
  - **validate_inputs.R**: Pre-flight validation
    - Checks: file existence, HapMap format, Taxa column, model validity, PCA range
    - Exit codes and error messages
  - **extract_trait_names.R**: Trait manifest generator
    - Input: phenotype file path
    - Output: traits_manifest.yaml with trait indices and statistics
  - **entrypoint.sh**: Container entrypoint
    - Commands: run-single-trait, validate, extract-traits, collect-results
    - Environment detection: Argo vs RunAI
- [ ] 6.2 Document parameter interactions and dependencies
- [ ] 6.3 Add troubleshooting section for common script errors
- [ ] 6.4 Link from README.md and docs/INDEX.md
- [ ] 6.5 Add GAPIT3 upstream documentation references:
  - Link to official GAPIT User Manual: https://zzlab.net/GAPIT/gapit_help_document.pdf
  - Link to GAPIT3 GitHub: https://github.com/jiabowang/GAPIT
  - Link to GAPIT3 publication: Wang & Zhang (2021) Genomics, Proteomics & Bioinformatics
  - Create model selection decision table with links to GAPIT docs for algorithm details
  - Note which GAPIT parameters are exposed vs require script modification

## 7. Create Documentation Standards Guide (DRY/Agile)

- [ ] 7.1 Create `docs/CONTRIBUTING_DOCS.md` with:
  - **DRY principles**: Single source of truth for each concept
    - Parameters: `.env.example` is authoritative
    - Script behavior: `docs/SCRIPTS_REFERENCE.md` is authoritative
    - Data formats: `docs/DATA_REQUIREMENTS.md` is authoritative
  - **Link, don't duplicate**: Use relative links instead of copying content
  - Guidelines for example values vs specifications
  - Checklist for documentation changes
  - Pattern: "N traits (e.g., 184 in reference dataset)"
  - Required disclaimers for dataset-specific content
- [ ] 7.2 Add documentation review checklist

## 8. Update Project Context Files

- [ ] 8.1 Update `openspec/project.md`:
  - Change "specifically Arabidopsis thaliana" to "plants and other organisms"
  - Mark production use case as example
  - Update domain context to be species-agnostic
- [ ] 8.2 Update `.claude.md`:
  - Remove dataset-specific assumptions
  - Add guidance for species-agnostic responses

## 9. Update Existing Documentation Files

- [ ] 9.1 Update `docs/ARGO_SETUP.md` - generalize examples
- [ ] 9.2 Update `docs/METADATA_SCHEMA.md` - ensure examples are marked as such
- [ ] 9.3 Update `docs/WORKFLOW_ARCHITECTURE.md` - dynamic trait count
- [ ] 9.4 Review and update `QUICKSTART.md` files

## 10. Validation and Testing

- [ ] 10.1 Run documentation link checker
- [ ] 10.2 Grep for remaining hardcoded values
- [ ] 10.3 Review all changes for consistency
- [ ] 10.4 Update `docs/INDEX.md` with new files
