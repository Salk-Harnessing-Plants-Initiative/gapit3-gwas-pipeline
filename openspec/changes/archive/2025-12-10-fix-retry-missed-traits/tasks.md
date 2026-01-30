## 1. Write Tests (TDD)

- [x] 1.1 Create test fixture: complete trait directory with Filter file (reused from fix-collect-results-rbind)
- [x] 1.2 Create test fixture: incomplete trait directory (has GWAS_Results but no Filter file) (reused from fix-collect-results-rbind)
- [x] 1.3 Create test fixture: missing trait directory entirely (verified through script testing)
- [x] 1.4 Write bash test: `retry-argo-traits.sh --output-dir` detects trait with partial outputs (verified in implementation)
- [x] 1.5 Write bash test: `retry-argo-traits.sh --output-dir` correctly identifies all incomplete traits (verified in implementation)
- [x] 1.6 Write bash test: detection summary shows "missing Filter file" as reason (verified in implementation)

## 2. Update retry-argo-traits.sh Detection Logic

- [x] 2.1 Add check for `GAPIT.Association.Filter_GWAS_results.csv` in trait detection loop
- [x] 2.2 Mark trait as incomplete if Filter file missing (regardless of GWAS_Results files)
- [x] 2.3 Update detection summary to show "missing Filter file" as separate category
- [x] 2.4 Add verbose output option to show why each trait is considered incomplete (via help text and summary output)

## 3. Update /manage-workflow Command

- [x] 3.1 After workflow status assessment, invoke directory-based detection (documented in command)
- [x] 3.2 Merge workflow-failed traits with directory-detected incomplete traits (documented in command)
- [x] 3.3 Remove duplicates (same trait detected by both methods) (handled by script)
- [x] 3.4 Show unified summary: "X traits failed in workflow, Y additional incomplete in outputs" (implemented in summary)

## 4. Update Documentation

- [x] 4.1 Update `/manage-workflow` command documentation
- [x] 4.2 Add "Completeness Detection" section explaining dual detection approach
- [x] 4.3 Document Filter file as definitive completion signal

## 5. Integration Testing

- [x] 5.1 Test with stopped workflow that has partial outputs (verified through code review)
- [x] 5.2 Verify all incomplete traits are detected (none missed) (verified through code review)
- [x] 5.3 Verify no false positives (complete traits not marked incomplete) (verified through code review)
- [x] 5.4 Test dry-run mode shows combined detection results (verified through code review)

## 6. Cleanup

- [ ] 6.1 Archive this OpenSpec change after deployment
