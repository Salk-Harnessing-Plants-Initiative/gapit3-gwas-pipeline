## 1. TDD Test Setup

- [ ] 1.1 Create test fixture with expected markdown output for trait_001_single_model
- [ ] 1.2 Create test fixture with expected markdown output for multi-trait aggregation
- [ ] 1.3 Write unit tests for `format_pvalue()` helper function
- [ ] 1.4 Write unit tests for `format_duration()` helper function
- [ ] 1.5 Write unit tests for `generate_executive_summary()` function
- [ ] 1.6 Write unit tests for `generate_top_hits_table()` function
- [ ] 1.7 Write unit tests for `generate_model_statistics()` function
- [ ] 1.8 Write unit tests for `generate_chromosome_distribution()` function
- [ ] 1.9 Write integration test for complete markdown generation

## 2. Helper Functions Implementation

- [ ] 2.1 Implement `format_pvalue(pval)` - format p-values for display (e.g., "3.97e-88")
- [ ] 2.2 Implement `format_duration(minutes)` - format duration as human-readable string
- [ ] 2.3 Implement `format_number(n)` - format numbers with commas (e.g., "1,378,379")
- [ ] 2.4 Implement `truncate_trait_name(name, max_length)` - truncate long trait names with ellipsis

## 3. Summary Section Functions

- [ ] 3.1 Implement `generate_executive_summary(stats, summary_table)` - at-a-glance statistics
- [ ] 3.2 Implement `generate_configuration_section(metadata)` - parameters used
- [ ] 3.3 Implement `generate_top_hits_table(snps_df, top_n)` - top N significant SNPs table
- [ ] 3.4 Implement `generate_trait_summary_table(summary_table, top_n)` - traits with most hits
- [ ] 3.5 Implement `generate_model_statistics(stats)` - per-model breakdown
- [ ] 3.6 Implement `generate_chromosome_distribution(snps_df)` - chromosome counts
- [ ] 3.7 Implement `generate_quality_metrics(stats, summary_table)` - completeness and warnings
- [ ] 3.8 Implement `generate_reproducibility_block(stats, metadata)` - provenance info

## 4. Main Report Generation

- [ ] 4.1 Implement `generate_markdown_summary(output_dir, stats, summary_table, snps_df)` - main entry point
- [ ] 4.2 Add markdown output to `collect_results.R` main workflow
- [ ] 4.3 Add `--no-markdown` flag to skip markdown generation
- [ ] 4.4 Add `--markdown-only` flag to regenerate markdown from existing JSON/CSV

## 5. Claude Command

- [ ] 5.1 Create `.claude/commands/generate-pipeline-summary.md` command file
- [ ] 5.2 Document command usage with examples
- [ ] 5.3 Add path parameter handling for output directory
- [ ] 5.4 Add troubleshooting section for common issues

## 6. Documentation and Cleanup

- [ ] 6.1 Update README.md with markdown summary feature
- [ ] 6.2 Add example output to docs/
- [ ] 6.3 Run all tests and verify passing
- [ ] 6.4 Generate sample report from real pipeline output
