# Generate Pipeline Summary

Generate a human-readable markdown summary report from completed GWAS pipeline outputs.

## Usage

```
/generate-pipeline-summary <output_path>
```

## Parameters

- `output_path`: Path to the pipeline outputs directory containing `aggregated_results/`
  - Windows: `Z:\users\eberrigan\20251208_...\outputs`
  - WSL: `/mnt/hpi_dev/users/eberrigan/20251208_.../outputs`

## Description

This command generates a `pipeline_summary.md` file from existing aggregated results. It reads:
- `summary_stats.json` - Statistics and provenance
- `all_traits_significant_snps.csv` - Significant SNPs data
- `summary_table.csv` - Per-trait summary

The generated report includes:
1. **Executive Summary** - Key metrics at a glance
2. **Configuration** - Models, parameters, input files
3. **Top SNPs Table** - Top 20 significant SNPs by p-value
4. **Traits Table** - Top 10 traits by significant SNP count
5. **Model Statistics** - Per-model breakdown with cross-validation
6. **Chromosome Distribution** - SNP counts by chromosome
7. **Quality Metrics** - Completion status and runtime
8. **Reproducibility** - Workflow ID, versions, timestamps

## Example

```bash
# Generate summary for iron deficiency dataset
/generate-pipeline-summary Z:\users\eberrigan\20251208_Elohim_Bello_iron_deficiency_GAPIT_GWAS\outputs
```

## Implementation

The command will:
1. Verify the aggregated_results directory exists
2. Check for required files (summary_stats.json, all_traits_significant_snps.csv)
3. Run the R script to regenerate the markdown summary
4. Display the generated report location

```bash
# Using WSL for R execution
wsl Rscript /mnt/c/repos/gapit3-gwas-pipeline/scripts/collect_results.R \
  --output-dir "<converted_path>" \
  --markdown-only
```

## Expected Output

```
Generating pipeline summary report...
Pipeline summary saved: <output_path>/aggregated_results/pipeline_summary.md

Preview:
# GWAS Pipeline Summary Report
Generated: 2025-12-09 21:25:24

## Executive Summary
| Metric | Value |
|--------|-------|
| Total Traits Analyzed | 186 |
| Total Significant SNPs | 1,886 |
...
```

## Verify Generation

After running, check that the file exists:
```bash
ls <output_path>/aggregated_results/pipeline_summary.md
```

View the generated report:
```bash
cat <output_path>/aggregated_results/pipeline_summary.md
```

## Troubleshooting

### Missing summary_stats.json
Run the full aggregation first:
```bash
/aggregate-results <output_path>
```

### Path conversion issues
Ensure paths are correctly converted between Windows and WSL:
- `Z:\` becomes `/mnt/hpi_dev/`
- `C:\repos\` becomes `/mnt/c/repos/`

### R package missing
If tidyr or other packages are missing:
```bash
wsl Rscript -e "install.packages('tidyr')"
```

## Related Commands

- `/aggregate-results` - Full aggregation (also generates markdown)
- `/validate-data` - Validate input files before analysis
- `/manage-workflow` - Check workflow status
