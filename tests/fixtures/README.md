# Test Fixtures

This directory contains minimal synthetic datasets for testing the GAPIT3 GWAS pipeline.

## Overview

These fixtures provide controlled, reproducible test data to verify:
- Input validation logic
- File format parsing
- Trait extraction
- Configuration handling
- Error detection

**Why synthetic data?**
- **Fast**: Small files (10 SNPs, 5 samples) complete tests in seconds
- **Reproducible**: Consistent results across environments
- **Focused**: Tests specific validation logic without real data complexity
- **Safe**: No privacy/security concerns with production data

## Fixture Files

### `genotype_mini.hmp.txt`
**Format**: HapMap (tab-delimited)
**Size**: 10 SNPs × 5 samples
**Purpose**: Test genotype file parsing and sample ID matching

**Structure**:
```
rs#  alleles  chrom  pos  strand  assembly#  center  protLSID  assayLSID  panelLSID  QCcode  sample_1  sample_2  ...
SNP_1  A/T  1  1000  +  NA  NA  NA  NA  NA  NA  AA  AT  ...
```

**Key Features**:
- Standard HapMap header with 11 metadata columns
- SNPs on chromosome 1 at positions 1000, 2000, ..., 10000
- Genotypes: AA, AT, TT, NN (biallelic A/T SNPs)
- Sample IDs: `sample_1` through `sample_5`

### `phenotype_mini.txt`
**Format**: Tab-delimited with header
**Size**: 5 samples × 3 traits
**Purpose**: Test phenotype parsing and trait extraction

**Structure**:
```
Taxa      trait_1  trait_2  trait_3
sample_1  95.3     102.1    88.7
sample_2  103.7    98.4     105.2
...
```

**Key Features**:
- **Taxa** column (required by GAPIT)
- Sample IDs match genotype file
- Numeric trait values (mean=100, sd=10)
- 3 traits for testing multi-trait analysis

### `phenotype_malformed.txt`
**Format**: Tab-delimited (intentionally incorrect)
**Size**: 5 samples × 3 traits
**Purpose**: Test error detection for malformed input

**Issue**: Uses `SampleID` column instead of `Taxa`

**Expected Behavior**: Validation should detect missing Taxa column and reject file

### `config_test.yaml`
**Format**: YAML configuration
**Purpose**: Test configuration parsing and validation

**Key Settings**:
```yaml
gapit:
  models: [BLINK, FarmCPU]
  pca_components: 3

validation:
  require_minimum_samples: 5  # Note: Production uses 50
```

**Important**: Test config uses 5 samples to match fixtures. Production requirement is 50 samples (see [openspec/project.md:182](../../openspec/project.md)).

### `ids_test.txt`
**Format**: Plain text (one ID per line)
**Size**: 5 sample IDs
**Purpose**: Test accession ID filtering (optional)

**Contents**:
```
sample_1
sample_2
sample_3
sample_4
sample_5
```

## Usage in Tests

### Helper Function
```r
# Access fixtures from any test
pheno_path <- get_fixture_path("phenotype_mini.txt")
```

The `get_fixture_path()` function (in `tests/testthat/helper.R`) handles path resolution across different working directories.

### Example Test
```r
test_that("Phenotype file has Taxa column", {
  pheno_path <- get_fixture_path("phenotype_mini.txt")
  pheno <- read.table(pheno_path, header = TRUE, stringsAsFactors = FALSE)
  expect_true("Taxa" %in% colnames(pheno))
})
```

## Generating New Fixtures

Helper functions in `tests/testthat/helper.R` can create additional fixtures:

```r
# Create genotype fixture
create_mock_genotype("path/to/output.hmp.txt", n_snps = 10, n_samples = 5)

# Create phenotype fixture
create_mock_phenotype("path/to/output.txt", n_samples = 5, n_traits = 3)

# Create config fixture
create_mock_config("path/to/config.yaml")
```

## Production vs Test Data

| Aspect | Test Fixtures | Production Data |
|--------|---------------|-----------------|
| Samples | 5 | 546 accessions |
| SNPs | 10 | ~1.4 million |
| Traits | 3 | 184 |
| File size | ~1 KB | ~500 MB genotype |
| Purpose | Fast validation tests | Real GWAS analysis |

## Maintenance

When updating fixtures:
1. Keep them minimal (current size is ideal)
2. Ensure genotype/phenotype sample IDs match
3. Use valid HapMap format
4. Update this README if adding new fixtures
5. Run tests to verify: `Rscript tests/testthat.R`

## Related Documentation

- [TESTING.md](../../docs/TESTING.md) - Complete testing guide
- [openspec/project.md](../../openspec/project.md) - Production data specs
