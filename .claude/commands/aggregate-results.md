# Aggregate GWAS Results

Aggregate results from all completed GWAS analyses into summary tables and reports.

## Command Options

### Option 1: Argo Standalone Workflow (Recommended for Cluster)

Run aggregation as an Argo workflow on the cluster:

```bash
# Submit standalone aggregation workflow
argo submit cluster/argo/workflows/gapit3-aggregation-standalone.yaml \
  -p output-hostpath="/hpi/hpi_dev/users/YOUR_USERNAME/outputs" \
  -p batch-id="gapit3-gwas-parallel-XXXXX" \
  -n runai-talmo-lab
```

**When to use**: After a workflow stopped before aggregation or when retrying without `--aggregate` flag.

### Option 2: RunAI Aggregation Script

```bash
# Aggregate all results from RunAI jobs
./scripts/aggregate-runai-results.sh

# Or specify custom paths
./scripts/aggregate-runai-results.sh /path/to/outputs
```

### Option 3: R Script Directly

```bash
Rscript scripts/collect_results.R \
  --output-dir /hpi/hpi_dev/users/$USER/gapit3-gwas/outputs \
  --aggregated-dir /hpi/hpi_dev/users/$USER/gapit3-gwas/outputs/aggregated_results
```

**When to use**: Local re-aggregation, custom thresholds, or debugging.

## Description

This command:
1. Scans all trait result directories (`trait_NNN_*/`)
2. Extracts significant SNPs (p < 5e-8)
3. Compiles summary statistics
4. Generates aggregated reports

## Expected Output Structure

```
outputs/aggregated_results/
├── summary_table.csv          # Overview: trait, samples, runtime, status
├── significant_snps.csv       # All SNPs below threshold
├── significant_snps_blink.csv # BLINK model results
├── significant_snps_farmcpu.csv # FarmCPU model results
└── summary_stats.json         # Metadata and statistics
```

## Summary Table Contents

`summary_table.csv` includes:
- Trait index and name
- Number of samples analyzed
- Number of significant SNPs found (per model)
- Analysis runtime
- Completion status
- Output file paths

Example:
```csv
trait_index,trait_name,n_samples,sig_snps_blink,sig_snps_farmcpu,runtime_min,status,output_dir
2,Iron_Conc_Root,546,12,8,14.3,completed,trait_002_Iron_Conc_Root
3,Iron_Conc_Shoot,546,5,3,15.1,completed,trait_003_Iron_Conc_Shoot
```

## Significant SNPs Table

`significant_snps.csv` includes:
- SNP identifier
- Chromosome
- Position
- P-value
- Effect size
- MAF (minor allele frequency)
- Trait name
- Model used (BLINK/FarmCPU)

Example:
```csv
snp_id,chr,pos,pvalue,effect,maf,trait,model
rs123456,1,1234567,2.3e-09,0.45,0.12,Iron_Conc_Root,BLINK
rs789012,2,3456789,4.1e-08,0.32,0.08,Iron_Conc_Root,FarmCPU
```

## Summary Statistics JSON

`summary_stats.json` includes:
- Total traits analyzed
- Total significant SNPs
- Analysis completion date
- Input file checksums
- GAPIT version
- Runtime statistics

## Verify Aggregation

```bash
# Check aggregated files exist
ls outputs/aggregated_results/

# Count significant SNPs
wc -l outputs/aggregated_results/significant_snps.csv

# View summary
head outputs/aggregated_results/summary_table.csv
```

## Incremental Aggregation

Aggregate only new results:

```bash
# Aggregate results modified in last 24 hours
find outputs -name "GAPIT.*.GWAS.Results.csv" -mtime -1 | \
  xargs Rscript scripts/collect_results.R --incremental
```

## Filter by Model

```bash
# Aggregate only BLINK results
Rscript scripts/collect_results.R \
  --output-dir outputs \
  --model BLINK

# Aggregate only FarmCPU results
Rscript scripts/collect_results.R \
  --output-dir outputs \
  --model FarmCPU
```

## Custom Significance Threshold

```bash
# Use stricter threshold (p < 1e-8)
Rscript scripts/collect_results.R \
  --output-dir outputs \
  --threshold 1e-8

# Use lenient threshold (p < 1e-6)
Rscript scripts/collect_results.R \
  --output-dir outputs \
  --threshold 1e-6
```

## Generate Report

```bash
# Create markdown report
Rscript -e "
library(data.table)
summary <- fread('outputs/aggregated_results/summary_table.csv')
snps <- fread('outputs/aggregated_results/significant_snps.csv')

cat('# GWAS Results Summary\n\n')
cat('Total traits analyzed:', nrow(summary), '\n')
cat('Total significant SNPs:', nrow(snps), '\n\n')
cat('## Top 10 Traits by Significant SNPs\n\n')
print(head(summary[order(-sig_snps_blink)], 10))
" > outputs/aggregated_results/REPORT.md
```

## Troubleshooting

### No results found
```bash
# Check if trait directories exist
ls outputs/trait_*/

# Verify GWAS results files exist
find outputs -name "GAPIT.*.GWAS.Results.csv"
```

### Aggregation fails
```bash
# Check for corrupted CSV files
for csv in outputs/trait_*/GAPIT.*.GWAS.Results.csv; do
  Rscript -e "tryCatch(fread('$csv'), error=function(e) cat('Error in $csv\n'))"
done
```

### Missing traits in summary
```bash
# Compare expected vs actual
EXPECTED=184
ACTUAL=$(ls -d outputs/trait_*/ | wc -l)
echo "Expected: $EXPECTED, Found: $ACTUAL, Missing: $((EXPECTED - ACTUAL))"
```

## Export for Analysis

```bash
# Copy aggregated results to local machine
scp -r username@cluster:/path/to/outputs/aggregated_results ./local_results/

# Or use rsync
rsync -avz username@cluster:/path/to/outputs/aggregated_results ./local_results/
```

## Related Commands

- `/monitor-jobs` - Check completion status before aggregating
- `/cleanup-jobs` - Clean up after aggregation complete
