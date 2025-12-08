## 1. Infrastructure

- [ ] 1.1 Add Bioconductor packages (GenomicRanges, rtracklayer) to Dockerfile
- [ ] 1.2 Add `data/annotations/GeneInfoFile.csv` to container or document as required input
- [ ] 1.3 Add `GENE_WINDOW_KB` environment variable to entrypoint.sh (default: 5)
- [ ] 1.4 Add `run-candidate-gene-mapping` command to entrypoint.sh

## 2. R Script Implementation

- [ ] 2.1 Create `scripts/map_candidate_genes.R` with optparse CLI
- [ ] 2.2 Implement GWAS results loading and region calculation (±GENE_WINDOW_KB)
- [ ] 2.3 Implement gene annotation loading from GeneInfoFile.csv
- [ ] 2.4 Implement GenomicRanges overlap detection
- [ ] 2.5 Generate output CSV with SNP-gene associations
- [ ] 2.6 Add metadata tracking (input files, parameters, gene counts)

## 3. Documentation

- [ ] 3.1 Update `.env.example` with gene mapping parameters
- [ ] 3.2 Update README with candidate gene mapping workflow
- [ ] 3.3 Document input requirements (aggregated GWAS results file)
- [ ] 3.4 Document output format (candidate_genes.csv schema)

## 4. Testing

- [ ] 4.1 Test with sample GWAS results
- [ ] 4.2 Verify gene annotations load correctly
- [ ] 4.3 Validate output CSV format matches expected schema
- [ ] 4.4 Test configurable window size (5kb, 10kb)
