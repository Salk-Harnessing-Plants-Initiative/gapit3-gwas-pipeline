## Why

When a workflow is stopped mid-execution (`argo stop`), traits that were running at stop time may have partial outputs but are not reliably detected as needing retry. This caused 5 traits (173, 180, 182, 184, 186) to be missed during retry of workflow `gapit3-gwas-parallel-6hjx8`.

**Root Cause Analysis:**
1. The `/manage-workflow` command extracts failed traits only from Argo workflow status (tasks marked ✖)
2. Traits that were "Running" when stopped get terminated mid-execution and create partial outputs
3. The output-directory detection in `retry-argo-traits.sh` checks for `GWAS_Results` files, but partial runs DO create these files for early models (e.g., BLINK)
4. **Missing**: A definitive completeness check using `Filter_GWAS_results.csv` (only exists when ALL models complete)

## What Changes

### 1. Update `retry-argo-traits.sh` Detection Logic
- Add check for `GAPIT.Association.Filter_GWAS_results.csv` as definitive completion signal
- A trait is incomplete if Filter file is missing (regardless of GWAS_Results files present)
- Update the detection summary to show "missing Filter file" as a distinct reason

### 2. Update `/manage-workflow` Command
- After fetching workflow status, ALSO scan output directories for incomplete traits
- Merge both sources: workflow failures + directory-detected incomplete traits
- Show unified summary: "X traits failed in workflow, Y additional incomplete in outputs"

### 3. Update Documentation
- Document that Filter file is the definitive completion signal
- Explain why both detection methods are needed for stopped workflows

## Impact

- Affected specs: `argo-workflow-configuration`, `claude-commands`
- Affected code:
  - `scripts/retry-argo-traits.sh` (add Filter file check)
  - `.claude/commands/manage-workflow.md` (document combined detection approach)
- Risk: Low - adds additional detection, doesn't change existing behavior
- Backward compatible: More traits may be detected as needing retry (conservative/safe)
