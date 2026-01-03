## Why

The current documentation is tightly coupled to a specific dataset (Arabidopsis thaliana, 546 accessions, 184/186 iron traits, ~1.4M SNPs). This creates several problems:

1. **Hardcoded trait counts (184, 186, 187)**: Users with different datasets may think the pipeline only works for this exact configuration
2. **Species-specific language**: Documentation assumes Arabidopsis throughout, despite the pipeline being species-agnostic
3. **Missing Kubernetes permissions documentation**: RBAC has been resolved but there's no consolidated reference for required permissions
4. **Resource allocation rationale undocumented**: Memory/CPU requirements exist but lack explanation of how they were determined
5. **Inconsistent output documentation**: Pipeline outputs and metadata schema need clearer explanation

## What Changes

### README.md Generalization
- Replace hardcoded "184 traits" with dynamic language like "N traits (determined by phenotype file)"
- Add species-agnostic language: "plants and other organisms" consistently
- Update architecture diagram to show dynamic trait count
- Fix resource table to explain determination methodology
- **Add "Pipeline Overview" section** explaining:
  - What is GWAS (1-2 sentences for newcomers)
  - High-level data flow: Genotype + Phenotype → GAPIT3 models → Significant SNPs + Plots
  - What you get: Manhattan plots, QQ plots, significant SNPs CSV, metadata
  - Link to WORKFLOW_ARCHITECTURE.md for technical details
  - Link to GAPIT3 documentation for algorithm details

### New Documentation Files
- `docs/KUBERNETES_PERMISSIONS.md` - Consolidated RBAC and permissions reference
- `docs/RESOURCE_SIZING.md` - Resource allocation guide with sizing methodology
- `docs/SCRIPTS_REFERENCE.md` - Comprehensive R script documentation (DRY: single source of truth)

### R Script Documentation (docs/SCRIPTS_REFERENCE.md)
Following DRY principles, create a single authoritative reference for all scripts:

| Script | Purpose | Key Parameters |
|--------|---------|----------------|
| `run_gwas_single_trait.R` | Core GWAS execution | TRAIT_INDEX, MODELS, PCA_COMPONENTS, MAF_FILTER, SNP_FDR |
| `collect_results.R` | Aggregate results | --threshold, --models, --allow-incomplete, --markdown-only |
| `validate_inputs.R` | Pre-flight validation | GENOTYPE_FILE, PHENOTYPE_FILE, MODELS |
| `extract_trait_names.R` | Generate trait manifest | phenotype file path, output manifest path |
| `entrypoint.sh` | Container router | Command routing, environment setup |

Document for each parameter:
- Name (env var and CLI flag)
- Type and valid values
- Default value
- Effect on analysis
- Common use cases

### Updated Documentation Files
- `docs/DATA_REQUIREMENTS.md` - Remove hardcoded counts, add format-only specifications
- `openspec/project.md` - Update to reflect species-agnostic nature
- `.claude.md` - Remove dataset-specific assumptions

### Code Documentation Guardrails (Agile/DRY Principles)
- Add `docs/CONTRIBUTING_DOCS.md` with documentation standards
- **Single source of truth**: `.env.example` for parameters, `docs/SCRIPTS_REFERENCE.md` for script behavior
- **Link, don't duplicate**: README links to detailed docs, doesn't repeat content
- Define checklist for documentation changes
- Establish patterns for example values vs. specifications

## Impact

### Affected specs
- `specs/documentation/spec.md` - Add new requirements for generalization

### Affected code
- `README.md` - 20+ lines with hardcoded values
- `docs/DATA_REQUIREMENTS.md` - Species/count references
- `docs/ARGO_SETUP.md` - Resource examples
- `openspec/project.md` - Production use case description
- `.claude.md` - AI assistant context
- `CHANGELOG.md` - Historical references (keep as-is for accuracy)

### Risk Assessment
- **Low risk**: Documentation-only changes
- **No breaking changes to code**: Pipeline functionality unchanged
- **Backwards compatible**: Existing users not affected
