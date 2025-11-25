# GAPIT3 Pipeline - Data Requirements Guide

This document explains what data you need in the `data/` folder to run the GAPIT3 GWAS pipeline.

## Table of Contents

1. [Directory Structure](#directory-structure)
2. [Genotype Data](#genotype-data)
3. [Phenotype Data](#phenotype-data)
4. [Accession IDs (Optional)](#accession-ids-optional)
5. [File Size Expectations](#file-size-expectations)
6. [Validation Checklist](#validation-checklist)
7. [Example Data](#example-data)

---

## Directory Structure

The `data/` folder must contain three subdirectories:

```
data/
├── genotype/
│   └── acc_snps_filtered_maf_perl_edited_diploid.hmp.txt
├── phenotype/
│   └── iron_traits_edited.txt
└── metadata/
    └── ids_gwas.txt  (optional)
```

**Note**: The specific filenames shown above are configured in [config/config.yaml](../config/config.yaml#L10-L12). You can change them in the config file, but the file formats must match the specifications below.

---

## Genotype Data

### Location
`data/genotype/acc_snps_filtered_maf_perl_edited_diploid.hmp.txt`

### Format
**HapMap format** - A tab-delimited text file with SNP markers in rows and samples in columns.

### Required Structure

#### Header Row
The first row must contain these 11 metadata columns followed by sample IDs:

| Column | Name | Description | Example |
|--------|------|-------------|---------|
| 1 | `rs#` | SNP identifier | `SNP_chr1_1234567` |
| 2 | `alleles` | Reference/alternate alleles | `A/T` or `C/G` |
| 3 | `chrom` | Chromosome number | `1`, `2`, ..., `5` |
| 4 | `pos` | Physical position (bp) | `1234567` |
| 5 | `strand` | DNA strand | `+` or `-` or `NA` |
| 6 | `assembly#` | Genome assembly version | `TAIR10` or `NA` |
| 7 | `center` | Sequencing center | `NA` |
| 8 | `protLSID` | Protocol LSID | `NA` |
| 9 | `assayLSID` | Assay LSID | `NA` |
| 10 | `panelLSID` | Panel LSID | `NA` |
| 11 | `QCcode` | Quality control code | `NA` |
| 12+ | Sample IDs | Accession/sample identifiers | `Ler-1`, `Col-0`, `Cvi-0` |

#### Data Rows
Each subsequent row represents one SNP with:
- 11 metadata values (matching header columns 1-11)
- Genotype calls for each sample (columns 12+)

### Genotype Encoding

Genotypes must be in **diploid format** with two alleles:

| Code | Meaning |
|------|---------|
| `AA` | Homozygous reference |
| `AT` | Heterozygous |
| `TT` | Homozygous alternate |
| `NN` | Missing data |
| `CC`, `GG`, `AC`, etc. | Other diploid combinations |

**Important**:
- Both alleles must be present (e.g., `A` is invalid, must be `AA`)
- Missing data should be `NN`, not `-`, `NA`, or blank
- Alleles must match those specified in column 2 (`alleles`)

### Example

```tsv
rs#	alleles	chrom	pos	strand	assembly#	center	protLSID	assayLSID	panelLSID	QCcode	Ler-1	Col-0	Cvi-0	Kyo-1	An-1
SNP_1_1000	A/T	1	1000	+	TAIR10	NA	NA	NA	NA	NA	AA	AT	TT	AA	NN
SNP_1_2000	C/G	1	2000	+	TAIR10	NA	NA	NA	NA	NA	CC	CG	GG	CC	CC
SNP_2_5000	A/G	2	5000	+	TAIR10	NA	NA	NA	NA	NA	AA	AA	AG	GG	AG
```

### Production Example (Arabidopsis)

For our production use case:
- **File**: `acc_snps_filtered_maf_perl_edited_diploid.hmp.txt`
- **Samples**: 546 Arabidopsis accessions
- **SNPs**: ~1.4 million markers
- **Chromosomes**: 1-5 (Arabidopsis has 5 chromosomes)
- **File Size**: ~500 MB (compressed), ~2 GB (uncompressed)
- **MAF Filter**: Minor allele frequency > 0.05 already applied

### Quality Recommendations

1. **MAF Filtering**: Remove rare variants (MAF < 0.05) before analysis
2. **LD Pruning**: Consider pruning SNPs in high linkage disequilibrium
3. **Missing Data**: Keep SNPs with < 20% missing data
4. **Biallelic Only**: GAPIT works best with biallelic SNPs

---

## Phenotype Data

### Location
`data/phenotype/iron_traits_edited.txt`

### Format
**Tab-delimited text file** with samples in rows and traits in columns.

### Required Structure

#### Critical: Taxa Column

**The first column MUST be named `Taxa`** (case-sensitive).

This column contains sample identifiers that **must exactly match** the sample IDs in the genotype file header.

#### Header Row

```
Taxa    trait_1    trait_2    trait_3    ...    trait_184
```

- Column 1: `Taxa` (required name)
- Columns 2+: Trait names (can be any descriptive name)

#### Data Rows

Each row represents one sample/accession:

```
sample_id    phenotype_value_1    phenotype_value_2    ...
```

### Data Types

Trait values should be:
- **Numeric**: Continuous or discrete numbers
- **No missing value codes**: Use `NA` for missing data (not `-`, `.`, `9999`, etc.)
- **No quotes**: Values should be unquoted numbers

### Example

```tsv
Taxa	Shoot_Iron_ppm	Root_Iron_ppm	Chlorophyll_SPAD
Ler-1	125.3	342.1	45.2
Col-0	98.7	298.5	42.8
Cvi-0	NA	315.2	44.1
Kyo-1	142.8	368.9	46.5
An-1	115.2	NA	43.7
```

### Production Example (Arabidopsis Iron Traits)

For our production use case:
- **File**: `iron_traits_edited.txt`
- **Samples**: 546 Arabidopsis accessions (must match genotype file)
- **Traits**: 184 iron-related phenotypes (columns 2-185)
- **File Size**: ~200 KB
- **Trait Types**:
  - Shoot iron concentration (ppm)
  - Root iron concentration (ppm)
  - Chlorophyll content (SPAD)
  - Flowering time (days)
  - Biomass measurements (g)
  - etc.

### Important Requirements

1. **Sample ID Matching**: Every sample in `Taxa` column must appear in genotype file
   ```bash
   # Verify overlap
   # Genotype samples: columns 12+ in header row
   # Phenotype samples: Taxa column (all rows)
   ```

2. **Minimum Sample Size**:
   - Test mode: 5 samples minimum
   - Production: 50 samples minimum (see [config/config.yaml](../config/config.yaml#L72))

3. **Trait Indexing**:
   - Trait index `1` = `Taxa` column (not analyzed)
   - Trait index `2` = First trait column (e.g., `Shoot_Iron_ppm`)
   - Trait index `3` = Second trait column (e.g., `Root_Iron_ppm`)
   - etc.

4. **Column Separator**: Must be TAB character (not spaces)

### Common Errors to Avoid

❌ **Wrong column name**:
```
SampleID    trait_1    trait_2    # WRONG - must be "Taxa"
```

✅ **Correct**:
```
Taxa    trait_1    trait_2
```

❌ **Sample IDs don't match**:
```
# Genotype file header: Ler-1, Col-0, Cvi-0
# Phenotype Taxa column: ler-1, col-0, cvi-0  # WRONG - case must match
```

✅ **Correct** - exact match:
```
# Both files: Ler-1, Col-0, Cvi-0
```

❌ **Missing data with wrong code**:
```
Taxa    trait_1
Ler-1   -999      # WRONG - use NA
Col-0   .         # WRONG - use NA
Cvi-0   NULL      # WRONG - use NA
```

✅ **Correct**:
```
Taxa    trait_1
Ler-1   NA
Col-0   NA
Cvi-0   125.3
```

---

## Accession IDs (Optional)

### Location
`data/metadata/ids_gwas.txt`

### Purpose
**Optional subset filter** - If provided, the pipeline will only analyze the samples listed in this file.

### Format
Plain text file with one sample ID per line.

### Example

```
Ler-1
Col-0
Cvi-0
Kyo-1
An-1
```

### When to Use

1. **Subset Analysis**: You have genotype/phenotype for 1000 samples but only want to analyze 100
2. **Quality Control**: Exclude low-quality samples
3. **Stratified Analysis**: Analyze specific populations separately

### When NOT to Use

If you want to analyze **all samples** in your genotype/phenotype files, simply:
- Delete or don't create `ids_gwas.txt`, OR
- Leave the config path commented out in [config/config.yaml](../config/config.yaml#L12):
  ```yaml
  # accession_ids: /data/metadata/ids_gwas.txt  # Commented = analyze all
  ```

---

## File Size Expectations

### Example Dataset Sizes

| Data Type | Samples | Markers/Traits | File Size | Load Time |
|-----------|---------|----------------|-----------|-----------|
| **Small Test** | 10 | 1,000 SNPs, 5 traits | 500 KB | < 1 sec |
| **Medium** | 100 | 50,000 SNPs, 20 traits | 50 MB | ~10 sec |
| **Large (Our Production)** | 546 | 1.4M SNPs, 184 traits | 2 GB genotype, 200 KB phenotype | ~2 min |
| **Very Large** | 5,000 | 10M SNPs, 500 traits | 50+ GB | ~30 min |

### Storage Requirements

For cluster deployment, ensure sufficient storage:

```bash
# Check available space on data path
df -h /hpi/hpi_dev/users/YOUR_USERNAME/gapit3-gwas/data

# Minimum recommended: 3x your genotype file size
# Example: 2 GB genotype → 6 GB free space
```

### Output Storage

GWAS results can be large:

```
Per-trait output: ~50-200 MB
Total for 184 traits: ~10-30 GB

Breakdown:
- GWAS results CSV: ~10-50 MB per trait
- Manhattan plot PDF: ~1-5 MB per trait
- QQ plot PDF: ~500 KB per trait
- Metadata JSON: ~10 KB per trait
```

---

## Validation Checklist

Before running the pipeline, verify:

### ✅ File Existence
```bash
ls data/genotype/*.hmp.txt
ls data/phenotype/*.txt
ls data/metadata/*.txt  # Optional
```

### ✅ File Formats

**Genotype (HapMap)**:
```bash
# Check header has 11+ columns
head -n 1 data/genotype/*.hmp.txt | awk -F'\t' '{print NF}'
# Should output: 11 + number_of_samples

# Check diploid encoding (should see AA, AT, TT, etc., not A, T)
head -n 5 data/genotype/*.hmp.txt
```

**Phenotype**:
```bash
# Check first column is "Taxa"
head -n 1 data/phenotype/*.txt | cut -f1
# Should output: Taxa

# Count traits (columns - 1)
head -n 1 data/phenotype/*.txt | awk -F'\t' '{print NF-1}'
# Example: 184 traits
```

### ✅ Sample ID Overlap

```bash
# Extract genotype sample IDs (columns 12+)
head -n 1 data/genotype/*.hmp.txt | cut -f12- | tr '\t' '\n' > /tmp/geno_ids.txt

# Extract phenotype sample IDs (Taxa column, skip header)
tail -n +2 data/phenotype/*.txt | cut -f1 > /tmp/pheno_ids.txt

# Find common samples
comm -12 <(sort /tmp/geno_ids.txt) <(sort /tmp/pheno_ids.txt)
# Should show overlapping sample IDs
```

### ✅ Data Quality

```bash
# Count samples
wc -l data/phenotype/*.txt  # Should be > 50 for production

# Count SNPs
wc -l data/genotype/*.hmp.txt  # Should be > 1000 for meaningful GWAS

# Check for missing data
grep -c "NN" data/genotype/*.hmp.txt
grep -c "NA" data/phenotype/*.txt
```

### ✅ Run Built-in Validation

The pipeline includes automatic validation:

```bash
# Docker validation
docker run --rm \
  -v $(pwd)/data:/data:ro \
  ghcr.io/salk-harnessing-plants-initiative/gapit3-gwas-pipeline:latest \
  /scripts/entrypoint.sh validate

# Argo validation (automatic first step in workflows)
# See cluster/argo/workflows/*-pipeline.yaml
```

---

## Example Data

### Minimal Test Dataset

For testing the pipeline, create a small dataset:

**Genotype** (`data/genotype/test.hmp.txt`):
```tsv
rs#	alleles	chrom	pos	strand	assembly#	center	protLSID	assayLSID	panelLSID	QCcode	sample_1	sample_2	sample_3	sample_4	sample_5
SNP_1	A/T	1	1000	+	NA	NA	NA	NA	NA	NA	AA	AT	TT	AA	AT
SNP_2	C/G	1	2000	+	NA	NA	NA	NA	NA	NA	CC	CG	GG	CC	CG
SNP_3	A/G	2	3000	+	NA	NA	NA	NA	NA	NA	AA	AG	GG	AA	GG
SNP_4	T/C	2	4000	+	NA	NA	NA	NA	NA	NA	TT	TC	CC	TT	TT
SNP_5	A/T	3	5000	+	NA	NA	NA	NA	NA	NA	AA	AA	AT	TT	AT
```

**Phenotype** (`data/phenotype/test_traits.txt`):
```tsv
Taxa	height_cm	weight_g	flowering_days
sample_1	25.3	12.5	45
sample_2	28.7	14.2	42
sample_3	22.1	10.8	48
sample_4	30.5	15.9	40
sample_5	26.4	13.1	44
```

**Update config** ([config/config.yaml](../config/config.yaml)):
```yaml
data:
  genotype: /data/genotype/test.hmp.txt
  phenotype: /data/phenotype/test_traits.txt
  # accession_ids: /data/metadata/ids_gwas.txt  # Optional - commented out
```

### Using the Built-in Test Fixtures

The repository includes test fixtures for CI:

```bash
# Test fixtures location
tests/fixtures/
├── genotype_mini.hmp.txt    # 10 SNPs × 5 samples
├── phenotype_mini.txt        # 5 samples × 3 traits
└── config_test.yaml          # Test configuration

# See tests/fixtures/README.md for details
```

These are minimal synthetic datasets for **unit testing only** - not suitable for real GWAS analysis.

---

## Data Sources

### Where to Get GWAS Data

If you don't have your own data:

1. **Arabidopsis 1001 Genomes**: https://1001genomes.org/
   - 1,135 Arabidopsis accessions
   - ~10M SNPs
   - Public phenotype data

2. **GWAS Catalog**: https://www.ebi.ac.uk/gwas/
   - Human GWAS datasets
   - Many organisms

3. **NCBI dbGaP**: https://www.ncbi.nlm.nih.gov/gap/
   - Controlled-access datasets
   - Requires application

4. **Public Repositories**:
   - Dryad: https://datadryad.org/
   - Zenodo: https://zenodo.org/
   - FigShare: https://figshare.com/

### Converting Other Formats

If your data is in a different format:

- **VCF → HapMap**: Use TASSEL or custom scripts
- **PLINK (.bed/.bim/.fam) → HapMap**: Use PLINK `--recode HV` or TASSEL
- **Excel/CSV → Tab-delimited**: Use `sed 's/,/\t/g'` or spreadsheet export

---

## Troubleshooting

### Error: "Taxa column not found"

**Cause**: First column in phenotype file is not named "Taxa"

**Fix**:
```bash
# Check current column name
head -n 1 data/phenotype/*.txt

# Rename to Taxa (example with sed)
sed -i '1s/SampleID/Taxa/' data/phenotype/iron_traits_edited.txt
```

### Error: "Sample mismatch"

**Cause**: Sample IDs in genotype and phenotype files don't match

**Fix**:
```bash
# List genotype samples
head -n 1 data/genotype/*.hmp.txt | cut -f12- | tr '\t' '\n' | sort > geno.txt

# List phenotype samples
tail -n +2 data/phenotype/*.txt | cut -f1 | sort > pheno.txt

# Find mismatches
comm -3 geno.txt pheno.txt
```

### Error: "Invalid genotype encoding"

**Cause**: Genotypes are haploid (A, T) instead of diploid (AA, TT)

**Fix**: Convert to diploid format or use a different genotype file

### Error: "File not found"

**Cause**: Paths in config.yaml don't match actual file locations

**Fix**:
```bash
# Verify paths in config
cat config/config.yaml | grep -A 3 "^data:"

# Update to match your actual files
```

---

## Summary

### Minimum Requirements

1. **Genotype file**: HapMap format, 11 columns + samples, diploid encoding
2. **Phenotype file**: Tab-delimited, first column named "Taxa", numeric trait values
3. **Sample overlap**: At least 50 samples present in both files
4. **Quality**: MAF > 0.05, < 20% missing data recommended

### Quick Verification

```bash
# Run the validation script
Rscript scripts/validate_inputs.R \
  --genotype data/genotype/*.hmp.txt \
  --phenotype data/phenotype/*.txt \
  --config config/config.yaml
```

For more help, see:
- [DEPLOYMENT_TESTING.md](DEPLOYMENT_TESTING.md) - Cluster deployment guide
- [TESTING.md](TESTING.md) - Unit testing guide
- [README.md](../README.md) - Main documentation
