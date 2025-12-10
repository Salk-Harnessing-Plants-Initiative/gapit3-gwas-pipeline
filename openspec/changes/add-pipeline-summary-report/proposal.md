## Why

The pipeline currently outputs structured JSON files (`summary_stats.json`, `metadata.json`) that are machine-readable but not easily consumed by scientific collaborators reviewing GWAS results. Researchers need a human-readable summary to quickly assess run completeness, identify top hits, understand quality metrics, and share results with colleagues who may not be comfortable parsing JSON or CSV files.

## What Changes

- **ADDED** Markdown summary report generation (`pipeline_summary.md`) alongside existing JSON outputs
- **ADDED** Executive summary section with at-a-glance statistics
- **ADDED** Results overview table with top significant SNPs per trait
- **ADDED** Per-model statistics breakdown with visual summaries
- **ADDED** Quality metrics section (completeness, warnings, runtime distribution)
- **ADDED** Reproducibility block (workflow ID, container image, git commit, timestamps)
- **ADDED** Chromosome distribution summary
- **ADDED** Claude command `/generate-pipeline-summary` for on-demand report generation
- **MODIFIED** `collect_results.R` to optionally generate markdown report during aggregation

## Impact

- Affected specs: `results-aggregation`, `claude-commands`
- Affected code:
  - `scripts/collect_results.R` (add `generate_markdown_summary()` function)
  - `.claude/commands/generate-pipeline-summary.md` (new command)
  - `tests/testthat/test-pipeline-summary.R` (new test file)
  - `tests/fixtures/aggregation/` (add expected markdown output fixtures)
- Backward compatibility: Fully backward compatible; markdown generation is additive
- Dependencies: None (uses base R markdown formatting)
