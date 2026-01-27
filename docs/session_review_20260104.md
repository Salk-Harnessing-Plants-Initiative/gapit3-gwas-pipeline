# Session Review: GWAS Pipeline Improvements

**Date**: January 4, 2026
**Session Duration**: ~12 hours (across context resets)

---

## Obstacles Encountered

### 1. Memory Estimation Gap
**Problem**: No tooling to estimate memory requirements before workflow submission.
**Impact**: 45% of traits failed with OOMKilled, requiring manual diagnosis and retry.
**Solution Needed**: Add memory estimation to `/validate-data` skill.

### 2. Dataset Size Detection
**Problem**: The change from MAF to MAC filtering doubled SNP count, but this wasn't flagged during validation.
**Impact**: Used wrong template size (96Gi instead of needed 160Gi).
**Solution Needed**: Add SNP count extraction and memory recommendation to validation.

### 3. Template Selection Complexity
**Problem**: Three templates (standard, highmem, ultrahighmem) with no clear selection criteria.
**Impact**: Manual guesswork for template selection.
**Solution Needed**: Decision tree or automated recommendation based on dataset.

### 4. Retry Workflow Parameter Mismatch
**Problem**: `retry-argo-traits.sh` extracts `models` parameter but v3.0.0 uses `model`.
**Impact**: Would fail to propagate model parameter to retry workflow.
**Solution Needed**: Update script to handle both naming conventions.

### 5. Missing Genotype/Phenotype File Path Parameters
**Problem**: Retry script doesn't extract `genotype-file`, `phenotype-file`, `accession-ids-file` parameters.
**Impact**: Retry workflow would use template defaults, potentially wrong files.
**Solution Needed**: Update script to extract and propagate all file path parameters.

### 6. No Pre-flight Validation for Large Datasets
**Problem**: No check that dataset size matches template capacity before submission.
**Impact**: Wasted compute time on doomed jobs.
**Solution Needed**: Add dataset size × template capacity validation.

---

## Code Improvements Needed

### High Priority

1. **Update `retry-argo-traits.sh`**
   - Add `--ultrahighmem` flag
   - Fix parameter extraction for v3.0.0 naming (`model` not `models`)
   - Extract and propagate file path parameters
   - Add memory estimation output

2. **Create `gapit3-single-trait-template-ultrahighmem.yaml`**
   - 160Gi memory request, 180Gi limit
   - 16 CPU request, 24 limit
   - Document use case in header

3. **Update `/validate-data` skill**
   - Add SNP count extraction
   - Add memory estimation
   - Recommend template based on dataset size

### Medium Priority

4. **Update `/manage-workflow` skill**
   - Add ultra-highmem to resource table
   - Improve failure categorization output
   - Add memory analysis for OOMKilled failures

5. **Create memory estimation utility**
   - Script to calculate: `samples × SNPs × 8 × 5 / 1024³ × 1.5`
   - Output recommended template
   - Integrate with validation workflow

6. **Update `cluster/argo/README.md`**
   - Add template selection guide
   - Document memory requirements per dataset type
   - Add troubleshooting for OOMKilled

### Low Priority

7. **Add pre-submission checks to workflows**
   - Validate genotype file size
   - Check SNP count against template capacity
   - Warn if mismatch detected

8. **Improve retry workflow generation**
   - Include validation step before retries
   - Add optional memory profiling

---

## Documentation Improvements

1. **Template Selection Guide** (NEW)
   - When to use each template
   - Memory estimation formula
   - Dataset size thresholds

2. **GAPIT_PARAMETERS.md**
   - Add memory impact notes
   - Document MLM memory requirements

3. **DATA_REQUIREMENTS.md**
   - Add SNP count recommendations
   - Document MAC vs MAF filtering impact

4. **CONTRIBUTING_DOCS.md**
   - Add memory consideration guidelines
   - Template documentation requirements

---

## CI/CD Improvements

1. **Add template validation workflow**
   - Lint all YAML files
   - Check parameter consistency across templates
   - Validate resource requests are reasonable

2. **Add integration test for large datasets**
   - Use synthetic data with known memory requirements
   - Verify template selection works correctly

3. **Add retry script tests**
   - Test parameter extraction
   - Test workflow generation
   - Test v3.0.0 compatibility

---

## Claude Skills Improvements

1. **`/validate-data`**
   - Add memory estimation output
   - Recommend template based on dataset

2. **`/submit-test-workflow`**
   - Add template selection parameter
   - Validate dataset size before submission

3. **`/manage-workflow`**
   - Improve OOMKilled diagnosis
   - Add memory analysis step
   - Recommend appropriate template for retry

4. **NEW: `/estimate-memory`**
   - Calculate memory requirements
   - Recommend template
   - Show comparison with cluster capacity

---

## Lessons Learned

1. **Dataset changes require memory re-evaluation**: Moving from MAF to MAC filtering nearly doubled memory needs.

2. **R memory overhead is significant**: Actual peak is 2.5-3x theoretical minimum due to garbage collection and copy-on-modify.

3. **Template tier system is necessary**: One-size-fits-all templates don't work for varying dataset sizes.

4. **Validation should include resource estimation**: Catching size mismatches before submission saves significant compute time.

5. **Parameter naming changes need migration**: v3.0.0 naming change (`models` → `model`) affected retry scripts.
