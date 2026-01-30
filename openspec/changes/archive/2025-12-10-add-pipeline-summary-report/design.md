## Context

The GAPIT3 GWAS pipeline processes hundreds of traits and generates detailed output files. Scientific collaborators need to quickly assess results without parsing JSON/CSV files. The pipeline already has comprehensive metadata; this feature formats it for human consumption.

**Stakeholders:**
- Scientific programmers (primary users generating reports)
- Research collaborators (consumers of reports, may not be technical)
- Lab PIs (need executive summaries for grant reports)

**Constraints:**
- Must work with base R (no additional dependencies)
- Must be idempotent (regenerate from existing data)
- Must handle edge cases (no significant SNPs, missing metadata)

## Goals / Non-Goals

**Goals:**
- Generate human-readable markdown summary alongside JSON outputs
- Provide at-a-glance statistics for quick assessment
- Include reproducibility information for FAIR compliance
- Support regeneration from existing aggregated data

**Non-Goals:**
- Interactive HTML dashboards (future work)
- PDF generation (use pandoc externally if needed)
- Real-time streaming updates
- Custom theming or branding

## Decisions

### Decision 1: Markdown as primary format
**What:** Use GitHub-Flavored Markdown (GFM) for the summary report.
**Why:**
- Renders directly in GitHub/GitLab without additional tools
- Text-based, version control friendly (meaningful diffs)
- Can be converted to HTML/PDF with pandoc
- Widely supported in scientific workflows

**Alternatives considered:**
- HTML: Requires browser, harder to diff, more complex to generate
- PDF: Requires pandoc or LaTeX, not easily editable
- Jupyter notebook: Requires Python, overkill for static summary

### Decision 2: Single consolidated file
**What:** Generate one `pipeline_summary.md` file per aggregation run.
**Why:**
- Simple to share (single attachment)
- Contains all essential information
- Links to detailed CSVs for deeper analysis

**Alternatives considered:**
- Multiple files (per-trait reports): More complex, harder to share
- Nested structure: Harder to navigate

### Decision 3: Top-N truncation for tables
**What:** Show top 20 SNPs by significance, top 15 traits by hit count.
**Why:**
- Keeps report scannable (< 5 min read)
- Full data available in CSVs
- Most important hits are shown

**Alternatives considered:**
- Full tables: Too long for 1886 SNPs
- Dynamic based on count: Inconsistent formatting

### Decision 4: Integrate into collect_results.R
**What:** Add markdown generation to existing aggregation script.
**Why:**
- Single entry point for all outputs
- Ensures markdown is always in sync with JSON/CSV
- Leverages existing data structures

**Alternatives considered:**
- Separate script: Risk of divergence, extra step for users
- Post-processing hook: More complex setup

## Report Structure

```markdown
# GWAS Pipeline Summary Report

## Executive Summary
- Dataset, date, workflow ID
- Total traits, success rate
- Total significant SNPs
- Top finding (lowest p-value)

## Configuration
- Models used
- Parameters (PCA, MAF, FDR threshold)
- Input files

## Results Overview

### Top Significant SNPs
| SNP | Chr | Pos | P-value | MAF | Model | Trait |
(Top 20 by p-value)

### Traits with Most Hits
| Trait | Total SNPs | BLINK | FarmCPU | MLM |
(Top 15 by total hits)

### Model Performance
- SNPs by model
- Overlap analysis
- Model agreement rate

### Chromosome Distribution
| Chr | SNP Count | % of Total |
(All chromosomes)

## Quality Metrics
- Completion rate
- Runtime distribution
- Missing data summary

## Reproducibility
- Workflow UID
- Container image
- Collection timestamp
- Source workflow UIDs (for retries)

---
Generated: [timestamp]
```

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| Large tables slow to render | Truncate to top-N, link to full CSV |
| Missing metadata fields | Graceful degradation with "N/A" |
| Encoding issues in trait names | Escape special characters |
| Stale markdown if CSV edited | Document regeneration command |

## Migration Plan

1. Add functions to collect_results.R (backward compatible)
2. Generate markdown by default (opt-out with --no-markdown)
3. Document in README
4. No breaking changes to existing outputs

## Open Questions

1. Should we include plot thumbnails? (Markdown doesn't support embedded images well)
   - **Decision:** No, link to PDF plots instead

2. Should markdown be in aggregated_results/ or separate?
   - **Decision:** Same directory as summary_stats.json for consistency