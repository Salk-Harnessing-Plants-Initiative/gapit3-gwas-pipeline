## Why

After GWAS analysis identifies significant SNPs, researchers need to map those SNPs to nearby candidate genes for biological interpretation. This post-processing step identifies genes within a configurable window (default ±5kb) of significant SNPs using the Araport11 gene annotation database. This is a standard downstream analysis step requested by collaborators for the iron traits project.

## What Changes

- Add new R script `scripts/map_candidate_genes.R` for gene mapping
- Add new entrypoint command `run-candidate-gene-mapping`
- Add `GENE_WINDOW_KB` environment variable (default: 5kb, configurable)
- Include `GeneInfoFile.csv` (Araport11 gene annotations) in container
- Add Bioconductor packages: `GenomicRanges`, `rtracklayer`
- Output `candidate_genes.csv` with SNP-gene associations

## Impact

- Affected specs: New capability (candidate-gene-mapping)
- Affected code:
  - `scripts/map_candidate_genes.R` (new file)
  - `scripts/entrypoint.sh` (add new command)
  - `Dockerfile` (add Bioconductor packages, include gene annotation file)
  - `.env.example` (document new parameters)
- Dependencies: Requires aggregated GWAS results (`GAPIT.Association.Filter_GWAS_results.csv`)
- New R packages: GenomicRanges, rtracklayer (Bioconductor)
