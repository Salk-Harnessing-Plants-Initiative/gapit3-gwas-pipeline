# Data Directory

This directory contains the input data for GWAS analysis. **Do not commit data files to git!**

## Required Structure

```
data/
├── genotype/
│   └── acc_snps_filtered_maf_perl_edited_diploid.hmp.txt
│       (~2.3 GB HapMap format genotype file)
│       Contains ~1,378,379 SNPs across 546 accessions
│
├── phenotype/
│   └── iron_traits_edited.txt
│       Tab-delimited file with:
│       - Column 1: Taxa (accession IDs)
│       - Columns 2-187: 186 iron-related traits
│
└── metadata/
    └── ids_gwas.txt
        List of accession IDs to include in analysis
```

## Data Sources

Original data provided by Elohim Bello Bello (Salk Institute).

Box link: https://salkinstitute.box.com/s/ej7rcxb2img4ekcc1g6ai3m3tum9c43m

## Notes

- These files are stored on NFS in production: `/hpi/hpi_dev/users/YOUR_USERNAME/gapit3-gwas/data`
- Files are excluded from git via `.gitignore`
- Total size: ~2.3 GB (too large for GitHub)
