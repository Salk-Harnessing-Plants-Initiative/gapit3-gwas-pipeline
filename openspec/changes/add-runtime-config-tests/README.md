# Add Tests for Runtime Configuration

## Summary

Add comprehensive test coverage for the runtime configuration feature (environment variables, entrypoint validation, and bash scripts) to ensure reliability before production deployment.

## Status

**Phase**: Proposal
**Created**: 2025-11-10
**Author**: Claude Code (via user request)
**Priority**: High (blocking production deployment)

## Quick Links

- [Proposal](proposal.md) - Problem statement and solution
- [Design](design.md) - Technical implementation details
- [Tasks](tasks.md) - Step-by-step implementation guide

## Problem

The runtime configuration feature (PR: feat/add-ci-testing-workflows) currently has **no automated test coverage**:

- ❌ R scripts no longer use config.yaml, but tests still expect it
- ❌ Environment variable parsing is untested
- ❌ entrypoint.sh validation logic is untested
- ❌ Bash scripts (submit, monitor, cleanup) have no automated tests
- ❌ CI workflow still installs `yaml` package (removed dependency)
- ❌ Integration tests for env var passing are missing

**Risk**: Could deploy broken runtime configuration to production and not discover issues until jobs fail.

## Solution

Add three layers of test coverage:

1. **Unit Tests** - Test individual components (env var parsing, validation functions)
2. **Integration Tests** - Test end-to-end workflows (env vars → entrypoint → R script)
3. **CI Updates** - Update workflows to test new configuration pattern

## Scope

**In Scope:**
- R script tests for environment variable parsing
- Bash unit tests for entrypoint.sh validation
- Integration tests for env var passing pipeline
- Update CI workflow to remove yaml dependency
- Bash script tests for RunAI helpers
- Docker image tests for entrypoint behavior

**Out of Scope:**
- Full cluster integration tests (tested manually on RunAI)
- Performance testing
- Load testing with 186 parallel jobs

## Timeline

**Estimated**: 3-4 hours

1. Update existing R tests: 1 hour
2. Add entrypoint.sh tests: 1 hour
3. Add integration tests: 1 hour
4. Update CI workflows: 30 minutes

## Dependencies

- `bats-core` - Bash Automated Testing System (for bash tests)
- Existing `testthat` infrastructure (already installed)
- Docker for integration tests

## Success Criteria

- [ ] All existing tests pass with new runtime configuration
- [ ] Environment variable parsing tested for all parameters
- [ ] Entrypoint validation catches invalid inputs
- [ ] CI passes without yaml package
- [ ] Integration test verifies env vars reach R script
- [ ] 100% coverage of validation logic

## Related Changes

- Implements tests for [add-dotenv-configuration](../add-dotenv-configuration/)
- Blocks production deployment until tests pass
- Required before merging feat/add-ci-testing-workflows to main

## Notes

- Tests should cover both happy path and error cases
- Validation tests critical - prevent bad config from reaching cluster
- CI must fail fast on configuration errors
