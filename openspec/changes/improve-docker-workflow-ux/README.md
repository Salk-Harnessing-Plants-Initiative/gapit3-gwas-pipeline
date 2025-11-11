# Improve Docker Workflow UX

## Summary

Prevent user confusion about Docker image availability by improving CI summaries, adding validation, and enhancing documentation. This change addresses the critical UX issue where PR builds display image tags that are never pushed to the registry, causing mass job failures when users attempt to use those tags.

## Status

**Phase**: Proposal
**Created**: 2025-11-10
**Author**: Claude Code (via user request)
**Priority**: High (prevents production incidents)

## Quick Links

- [Proposal](proposal.md) - Problem statement and proposed solution
- [Design](design.md) - Architecture and implementation details
- [Tasks](tasks.md) - Step-by-step implementation guide

## Problem

Users experience ImagePullBackOff failures when submitting jobs with Docker image tags copied from CI build summaries.

**Real incident:**
- User saw `sha-0f972d4-test` in PR build CI output
- Submitted 186 parallel RunAI jobs using this tag
- All 186 jobs failed with ImagePullBackOff
- Root cause: PR builds don't push images to registry (security measure)
- CI summary shows "Pushed: false" but it's too subtle to notice

**Why it happens:**
1. PR builds generate image tags (`sha-XXX-test`, `pr-N-test`, `branch-test`)
2. Tags appear prominently in CI build summary
3. "Pushed: false" appears at bottom of summary (easy to miss)
4. Users copy tags from CI, assuming they're available
5. Jobs fail when trying to pull non-existent images

## Solution

Four-pronged approach to prevent confusion:

1. **Explicit CI Summaries** - Big warning "⚠️ Image NOT Pushed (PR Build)" instead of subtle "Pushed: false"
2. **Proactive PR Comments** - Auto-comment on PRs with step-by-step instructions for testing feature branches
3. **Image Validation** - Add validation to RunAI scripts to check if image exists before submitting 186 jobs
4. **Comprehensive Documentation** - Add "Testing Feature Branch Changes" guide with troubleshooting

## Scope

**In Scope:**
- Update GitHub Actions workflow build summary (`.github/workflows/docker-build.yml`)
- Add PR comment automation for testing instructions
- Add image validation to `scripts/submit-all-traits-runai.sh`
- Update `docs/DOCKER_WORKFLOW.md` with feature branch testing guide
- Update `.env.example` with IMAGE tag guidance
- Add troubleshooting section for ImagePullBackOff errors

**Out of Scope:**
- Changing PR image push behavior (correctly blocked for security)
- Automatic workflow_dispatch triggering (wasteful)
- Image cleanup automation (future enhancement)
- Backup/restore functionality

## Timeline

**Estimated**: 3-4 hours

1. Workflow improvements: 1 hour
2. Script validation: 30 minutes
3. Documentation updates: 1.5 hours
4. Testing: 1 hour

## Dependencies

- GitHub Actions `actions/github-script@v7` (for PR comments)
- `gh` CLI or Docker CLI (for image validation)
- Existing workflow infrastructure

## Success Criteria

- [ ] PR build summaries prominently show "NOT PUSHED" warning
- [ ] PR comments appear automatically with testing instructions
- [ ] Image validation catches non-existent tags before job submission
- [ ] DOCKER_WORKFLOW.md includes feature branch testing guide
- [ ] ImagePullBackOff incidents reduced to zero
- [ ] Users can easily discover how to test feature branches

## Related Changes

- [add-dotenv-configuration](../add-dotenv-configuration/) - Established .env usage patterns
- [add-ci-testing-workflows](../add-ci-testing-workflows/) - CI infrastructure this builds upon

## Notes

- The workflow is technically correct (PRs don't push for security)
- This is a UX/documentation fix, not a technical bug fix
- Validation prevents 186-job failures with one bad image tag
- Solution maintains current security posture (no PRs from forks)
