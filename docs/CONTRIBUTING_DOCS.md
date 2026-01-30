# Documentation Contribution Guide

Guidelines for maintaining species-agnostic, DRY (Don't Repeat Yourself) documentation in the GAPIT3 GWAS Pipeline.

---

## Single Source of Truth

Each type of information has ONE authoritative source. Link to it; don't duplicate.

| Information Type | Authoritative Source |
|-----------------|---------------------|
| Parameter defaults | [.env.example](../.env.example) |
| Script behavior | [SCRIPTS_REFERENCE.md](SCRIPTS_REFERENCE.md) |
| Data formats | [DATA_REQUIREMENTS.md](DATA_REQUIREMENTS.md) |
| Resource sizing | [RESOURCE_SIZING.md](RESOURCE_SIZING.md) |
| Kubernetes permissions | [KUBERNETES_PERMISSIONS.md](KUBERNETES_PERMISSIONS.md) |
| Workflow architecture | [WORKFLOW_ARCHITECTURE.md](WORKFLOW_ARCHITECTURE.md) |

---

## Documentation Checklist

Before submitting documentation changes, verify:

### Species/Dataset Agnostic

- [ ] No hardcoded trait counts (use "N traits" or "your phenotype columns")
- [ ] No hardcoded sample counts (use "N samples" or ranges like "50 to 10,000+")
- [ ] No hardcoded SNP counts (use "M SNPs" or describe scaling behavior)
- [ ] Species mentioned are clearly examples, not limitations
- [ ] Language uses "your organism" or "plants and other organisms"

### DRY Principles

- [ ] Parameter details link to `.env.example`, not duplicated
- [ ] Script behavior links to `SCRIPTS_REFERENCE.md`
- [ ] No copy-pasted content between files
- [ ] Tables reference source documents for details

### Example Values

- [ ] Example values clearly marked with "(e.g., ...)" or "approximately"
- [ ] Specification values (minimums, requirements) clearly distinguished from examples
- [ ] Numeric examples show ranges rather than single values when possible

---

## Patterns for Example Values

### Correct Patterns

**Trait counts**:
```markdown
N traits (trait count detected from phenotype file columns)
```
```markdown
Analyze any number of traits in parallel
```

**Sample counts**:
```markdown
N samples (minimum: 50 for GWAS)
```
```markdown
Supports datasets from 50 to 10,000+ samples
```

**Species**:
```markdown
plants and other organisms
```
```markdown
any species with HapMap-format genotype data
```

**Resources**:
```markdown
Memory requirements scale with dataset size. See [RESOURCE_SIZING.md](RESOURCE_SIZING.md).
```

### Incorrect Patterns (Avoid)

```markdown
184 traits     ❌ (implies fixed limitation)
546 accessions ❌ (dataset-specific, should be marked as example)
1.4M SNPs      ❌ (dataset-specific without context)
Arabidopsis    ❌ (without noting it's an example)
```

---

## Adding New Documentation

### When to Create a New File

Create a new documentation file when:
- The topic is substantial (> 50 lines)
- It serves a distinct audience (users vs. developers vs. operators)
- It needs independent updates

### New File Checklist

1. Add to `docs/INDEX.md` in appropriate section
2. Add to README.md if user-facing
3. Include "Last updated" footer
4. Cross-link from related documents

### File Structure Template

```markdown
# Document Title

Brief description (1-2 sentences).

> **Note**: Any important caveats or context notes.

---

## Table of Contents

1. [Section 1](#section-1)
2. [Section 2](#section-2)

---

## Section 1

Content here...

---

## Related Documentation

- [Related Doc 1](related1.md) - Description
- [Related Doc 2](related2.md) - Description

---

*Last updated: YYYY-MM-DD*
```

---

## Updating Existing Documentation

### Parameter Changes

1. Update `.env.example` first (authoritative source)
2. Update `SCRIPTS_REFERENCE.md` if behavior changes
3. Other docs should link, not duplicate

### Resource Requirement Changes

1. Update `RESOURCE_SIZING.md` with methodology
2. Update workflow templates if defaults change
3. Explain scaling formulas rather than fixed benchmarks

### Format Changes

1. Update `DATA_REQUIREMENTS.md` for input/output formats
2. Update `METADATA_SCHEMA.md` for metadata changes

---

## Exempt Content

Some content is exempt from generalization requirements:

- **CHANGELOG.md**: Historical accuracy preserved
- **Git commit messages**: Specific to actual changes
- **Test fixtures**: Specific synthetic data for testing
- **CI workflow outputs**: Specific test results

---

## Review Checklist for PRs

When reviewing documentation PRs, check:

1. **No hardcoded dataset-specific values** without "e.g." context
2. **Links to authoritative sources** instead of duplicating
3. **Species-agnostic language** throughout
4. **Updated INDEX.md** if new files added
5. **Cross-links** to related documentation
6. **Last updated** footer reflects change date

---

## Related Documentation

- [INDEX.md](INDEX.md) - Documentation index
- [SCRIPTS_REFERENCE.md](SCRIPTS_REFERENCE.md) - Script documentation standards
- [README.md](../README.md) - Main project documentation

---

*Last updated: 2025-01-03*
