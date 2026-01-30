# Validate GWAS Data Directory

Validate that a data directory contains all required files for GWAS analysis.

## Usage

```
/validate-data <path>
```

Where `<path>` is the Windows path to the data directory (e.g., `Z:\users\eberrigan\20251208_...\data`).

## What It Validates

Based on [docs/DATA_REQUIREMENTS.md](../../docs/DATA_REQUIREMENTS.md):

### 1. Directory Structure
```
data/
├── genotype/
│   └── *.hmp.txt (HapMap format)
├── phenotype/
│   └── *.txt (tab-delimited)
└── metadata/
    └── ids_gwas.txt (optional)
```

### 2. Genotype File (HapMap format)
- First 11 columns: `rs#`, `alleles`, `chrom`, `pos`, `strand`, `assembly#`, `center`, `protLSID`, `assayLSID`, `panelLSID`, `QCcode`
- Remaining columns: Sample IDs
- Diploid encoding: `AA`, `AT`, `TT`, `NN` (not haploid `A`, `T`)

### 3. Phenotype File
- First column MUST be named `Taxa` (case-sensitive)
- Remaining columns: Numeric trait values
- Missing values: `NA` (not `-999`, `.`, or blank)

### 4. Sample ID Overlap
- Sample IDs in genotype header (columns 12+) must match `Taxa` column in phenotype file
- At least 50 samples for production runs

## Validation Commands

Run these checks on the provided path:

```bash
# Check directory structure
ls -la "<path>/genotype/"
ls -la "<path>/phenotype/"
ls -la "<path>/metadata/" 2>/dev/null || echo "No metadata dir (optional)"

# Check genotype file format (first line, column count)
head -n 1 "<path>/genotype/"*.hmp.txt | awk -F'\t' '{print "Columns:", NF, "(expect 11 + samples)"}'

# Check phenotype first column is "Taxa"
head -n 1 "<path>/phenotype/"*.txt | cut -f1
# Should output: Taxa

# Count samples and traits
wc -l "<path>/phenotype/"*.txt
head -n 1 "<path>/phenotype/"*.txt | awk -F'\t' '{print "Traits:", NF-1}'

# Check for diploid encoding (should see AA, TT, etc., not single letters)
head -n 2 "<path>/genotype/"*.hmp.txt | cut -f12-16
```

## Path Mapping

| Context | Format | Example |
|---------|--------|---------|
| Windows | `Z:\users\...` | `Z:\users\eberrigan\20251208_...\data` |
| WSL | `/mnt/hpi_dev/users/...` | `/mnt/hpi_dev/users/eberrigan/20251208_.../data` |
| Cluster | `/hpi/hpi_dev/users/...` | `/hpi/hpi_dev/users/eberrigan/20251208_.../data` |

## Example Output

```
Validating: Z:\users\eberrigan\20251208_Elohim_Bello_iron_deficiency_GAPIT_GWAS

Directory Structure:
  [OK] genotype/ exists
  [OK] phenotype/ exists
  [OK] metadata/ exists (optional)

Genotype File: acc_snps_filtered_maf_perl_edited_diploid.hmp.txt
  [OK] HapMap format (11 metadata + 546 samples = 557 columns)
  [OK] Diploid encoding detected (AA, TT, CC, GG)
  [OK] File size: 2.2 GB

Phenotype File: iron_traits_edited.txt
  [OK] First column is "Taxa"
  [OK] 570 samples, 186 traits
  [OK] Numeric values with NA for missing

Sample Overlap:
  [OK] 546 samples found in both files

Cluster Path: /hpi/hpi_dev/users/eberrigan/20251208_Elohim_Bello_iron_deficiency_GAPIT_GWAS
```

## Related Commands

- `/submit-runai-test` - Submit a test job after validation
- `/submit-test-workflow` - Submit Argo workflow (alternative)