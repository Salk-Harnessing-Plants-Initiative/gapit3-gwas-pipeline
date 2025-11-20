# Add Environment Validation and Dry-Run Mode

## Summary

Add comprehensive .env validation and dry-run capability to prevent configuration errors before submitting 186 jobs. Provides both a standalone validation script and a `--dry-run` flag for the submission script to verify all settings, data files, Docker images, and cluster paths before actual job submission.

## Status

**Phase**: Proposal
**Created**: 2025-11-10
**Author**: Claude Code (via user request)
**Priority**: Medium-High (prevents configuration errors)

## Quick Links

- [Proposal](proposal.md) - Problem statement and proposed solution
- [Design](design.md) - Architecture and implementation details
- [Tasks](tasks.md) - Step-by-step implementation guide
- [Spec](specs/env-validation/spec.md) - Formal requirements

## Problem

Users can submit 186 jobs with incorrect configuration (wrong paths, missing files, invalid parameters) and only discover the errors after jobs fail, wasting cluster resources and time.

**Common issues we want to catch BEFORE submission:**
- Invalid Docker image tags (already addressed by image validation)
- Missing or incorrect data file paths on cluster
- Trait index out of bounds (END_TRAIT > number of columns)
- Invalid GAPIT parameters (bad model names, PCA out of range)
- Insufficient cluster resources
- Path mismatches between .env and actual cluster structure

**Current workflow:**
1. User configures .env
2. Runs `submit-all-traits-runai.sh`
3. 186 jobs submitted
4. Jobs fail due to config error (e.g., phenotype file not found)
5. User must cleanup 186 failed jobs
6. Fix config and resubmit

**Desired workflow:**
1. User configures .env
2. Runs `scripts/validate-env.sh` OR `submit-all-traits-runai.sh --dry-run`
3. Validation catches config errors BEFORE submission
4. User fixes issues
5. Revalidate
6. Submit with confidence

## Solution

**Two complementary approaches:**

### 1. Standalone Validation Script (Primary)

Create `scripts/validate-env.sh` that checks:
- ✅ .env file exists and is readable
- ✅ Docker image exists in registry
- ✅ Data files exist on cluster (genotype, phenotype, metadata)
- ✅ Phenotype file has correct structure (Taxa column, trait columns)
- ✅ Trait indices are valid (START_TRAIT=2, END_TRAIT <= column count)
- ✅ GAPIT parameters are valid (models, PCA range, thresholds)
- ✅ RunAI project is accessible
- ✅ Output directory exists or can be created
- ✅ Resource allocation is reasonable (CPU, memory)
- ✅ No conflicting jobs already exist

**Usage:**
```bash
# Validate current .env
./scripts/validate-env.sh

# Validate specific env file
./scripts/validate-env.sh --env-file /path/to/.env

# Verbose mode
./scripts/validate-env.sh --verbose

# Quick mode (skip slow checks like cluster file validation)
./scripts/validate-env.sh --quick
```

### 2. Dry-Run Mode for Submission Script (Secondary)

Add `--dry-run` flag to `submit-all-traits-runai.sh`:

**Usage:**
```bash
# Dry run - validate but don't submit
./scripts/submit-all-traits-runai.sh --dry-run

# Shows exactly what would be submitted
./scripts/submit-all-traits-runai.sh --dry-run --verbose
```

**Output:**
```
Dry-run mode: No jobs will be submitted

✅ Configuration Validation
   Docker image: sha-6b9d193-test (exists)
   Data files: 3/3 found
   Trait range: 2-187 (186 traits, valid)
   GAPIT params: All valid

✅ Job Submission Plan
   Would submit: 186 jobs
   Job names: eberrigan-gapit-gwas-2 to eberrigan-gapit-gwas-187
   Max concurrent: 50
   Resources per job: 12 CPU, 32G memory
   Total resources: 600 CPU, 1600G memory (peak)

✅ Cluster Validation
   Project: talmo-lab (accessible)
   No conflicting jobs found
   Output directory: writable

All validation checks passed ✅
Ready to submit with: ./scripts/submit-all-traits-runai.sh
```

## Scope

**In Scope:**
- Create `scripts/validate-env.sh` standalone validation script
- Add `--dry-run` flag to `scripts/submit-all-traits-runai.sh`
- Validate all configuration parameters
- Check cluster file accessibility
- Verify trait index bounds
- Validate GAPIT parameters
- Check for conflicting job names
- Resource sanity checks
- Clear, actionable error messages

**Out of Scope:**
- Validating data file contents (e.g., genotype format correctness)
- Performance testing cluster capacity
- Automatic configuration fixing (just report errors)
- Integration with CI/CD pipelines
- Email/Slack notifications

## Timeline

**Estimated**: 4-5 hours

1. Validation script implementation: 2-3 hours
2. Dry-run integration: 1 hour
3. Documentation: 1 hour
4. Testing: 1 hour

## Dependencies

- Existing `.env` file structure
- Access to cluster file paths (for file validation)
- `runai` CLI (for project/job validation)
- `gh` CLI or Docker CLI (for image validation - already implemented)

## Success Criteria

- [ ] `validate-env.sh` catches all common configuration errors
- [ ] `--dry-run` mode shows accurate job submission plan
- [ ] Validation completes in <30 seconds (quick mode <5 seconds)
- [ ] Error messages are clear and actionable
- [ ] 100% of pre-submission config errors caught by validation
- [ ] No false positives (valid configs always pass)
- [ ] Documentation includes all validation checks and examples

## Related Changes

- [improve-docker-workflow-ux](../improve-docker-workflow-ux/) - Image validation (already implemented)
- [add-dotenv-configuration](../add-dotenv-configuration/) - Established .env patterns

## Notes

- Validation should be fast enough to run before every submission
- Some checks may require cluster access (SSH or mounted filesystem)
- Graceful degradation if cluster access unavailable
- Exit codes: 0 = valid, 1 = validation failed, 2 = script error
- Can be used in CI/CD for automated config testing
- Should work offline (skip network-dependent checks)
