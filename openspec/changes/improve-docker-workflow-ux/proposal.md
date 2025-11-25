# Proposal: Improve Docker Workflow UX

## Problem Statement

The Docker build workflow has a critical UX issue that causes production incidents: **PR builds display image tags in CI summaries that are never pushed to the registry**, leading users to submit jobs with non-existent images.

### Real-World Impact

**Incident**: User submitted 186 parallel RunAI jobs, all failed with ImagePullBackOff

**Root Cause Analysis**:
1. User created PR on feature branch `feat/add-ci-testing-workflows`
2. GitHub Actions triggered Docker build workflow
3. Workflow generated tags: `pr-123-test`, `sha-0f972d4-test`, `feat-add-ci-testing-workflows-test`
4. CI summary displayed all tags with "Pushed: false" at bottom
5. User copied `sha-0f972d4-test` from CI output (seemed like a valid tag)
6. Updated RunAI scripts to use this image tag
7. Submitted 186 parallel jobs
8. All jobs failed: `ImagePullBackOff: manifest unknown`
9. Cost: Wasted cluster resources, 186 failed jobs, hours of debugging

### Why Current Approach Fails

**Line 124 of `.github/workflows/docker-build.yml`:**
```yaml
push: ${{ github.event_name != 'pull_request' }}
```

This correctly prevents pushing PR images (security measure), but the UX doesn't communicate this clearly.

**Current CI Summary** (lines 133-142):
```markdown
### Docker Build Summary 🚀

**Environment:** test
**Image Tags:**
```
ghcr.io/.../gapit3-gwas-pipeline:pr-123-test
ghcr.io/.../gapit3-gwas-pipeline:sha-0f972d4-test
ghcr.io/.../gapit3-gwas-pipeline:feat-add-ci-testing-workflows-test
```
**Pushed:** false
```

**Problems:**
- Tags appear prominently (users focus here)
- "Pushed: false" is subtle, at the bottom
- No explanation of what this means
- No guidance on how to test feature branches
- Easy to copy tags without noticing the warning

### Documentation Gaps

**DOCKER_WORKFLOW.md** says (lines 55-58):
```markdown
**Result:**
- Builds image locally (not pushed)
- Tags: `pr-<number>-test`
```

**But it omits:**
- That `sha-XXX-test` and `branch-test` tags are also generated
- How to actually test feature branch changes before merging
- Step-by-step workflow_dispatch instructions
- Troubleshooting ImagePullBackOff errors

### Why This is High Priority

**Frequency**: Affects anyone testing feature branches (common workflow)
**Severity**: Can cause mass job failures (186 in this incident)
**Time to Discover**: Hours of debugging before realizing image doesn't exist
**Preventability**: High - simple validation and better UX would prevent entirely

## Proposed Solution

Four-layer defense against this confusion:

### 1. Explicit CI Build Summaries (Critical)

**Replace** subtle "Pushed: false" with prominent warnings.

**For PR builds:**
```markdown
### Docker Build Summary 🚀

**⚠️ Image NOT Pushed to Registry (PR Build)**

This image was built for testing only and is **not available** in the container registry.

**To test this PR's changes:**
1. Merge to main and use `main-test` tag, OR
2. Manually trigger build via [Actions → Docker Build → Run workflow](../../actions/workflows/docker-build.yml)

<details><summary>Tags generated (but NOT pushed)</summary>

```
ghcr.io/.../gapit3-gwas-pipeline:pr-123-test
ghcr.io/.../gapit3-gwas-pipeline:sha-0f972d4-test
```

</details>
```

**For pushed builds:**
```markdown
### Docker Build Summary 🚀

**✅ Image Pushed to Registry**

**Available Image Tags:**
```
ghcr.io/.../gapit3-gwas-pipeline:main-test
ghcr.io/.../gapit3-gwas-pipeline:sha-abc1234-test
```

**Pull Command:**
```bash
docker pull ghcr.io/.../gapit3-gwas-pipeline:sha-abc1234-test
```
```

**Impact**: Impossible to miss that PR images aren't pushed.

### 2. Proactive PR Comments (High Priority)

**Add GitHub Action step** to automatically comment on PRs with testing instructions.

**Comment appears immediately** when PR build completes:

```markdown
## Docker Build Completed ✅

**Note:** This PR builds a Docker image for testing, but it is **NOT pushed** to the registry for security reasons.

### To test your changes on RunAI/cluster:

**Option 1: Manual Workflow Dispatch (Recommended)**
1. Go to [Actions → Build and Push Docker Image](https://github.com/.../actions/workflows/docker-build.yml)
2. Click "Run workflow"
3. Select branch: `feat/add-ci-testing-workflows`
4. Environment: `test`
5. Click "Run workflow"
6. Wait ~10 minutes for build to complete
7. Use image tag: `sha-abc1234-test`

**Option 2: Merge to Main First**
1. Merge this PR
2. Use tag: `main-test` or `sha-abc1234-test`

### Image Tags (NOT available yet):
These tags would be generated if pushed:
- `pr-123-test`
- `sha-abc1234-test`
- `feat-add-ci-testing-workflows-test`

**Want to push this image?** Use workflow_dispatch (Option 1 above).
```

**Implementation**: Use `actions/github-script@v7` to post comment.

**Impact**: Users get guidance exactly when they need it, in the PR itself.

### 3. Image Validation in RunAI Scripts (Critical)

**Add validation** to `scripts/submit-all-traits-runai.sh` before submitting 186 jobs.

**Before submitting:**
```bash
echo "Validating Docker image availability..."

# Try to inspect image manifest (lightweight check)
if docker manifest inspect "$IMAGE" >/dev/null 2>&1; then
    echo "✓ Image found: $IMAGE"
elif command -v gh >/dev/null 2>&1; then
    # Check GitHub Container Registry
    TAG="${IMAGE##*:}"
    if gh api "/user/packages/container/gapit3-gwas-pipeline/versions" 2>/dev/null | grep -q "\"$TAG\""; then
        echo "✓ Image found in GitHub registry: $TAG"
    else
        echo "✗ WARNING: Image tag '$TAG' not found in GitHub registry!"
        echo ""
        echo "This might cause ImagePullBackOff errors on all 186 jobs."
        echo ""
        echo "Common causes:"
        echo "  - Tag was generated from PR build (not pushed)"
        echo "  - Typo in tag name"
        echo "  - Image not yet built"
        echo ""
        echo "To check available tags:"
        echo "  https://github.com/.../packages/container/gapit3-gwas-pipeline"
        echo ""
        read -p "Continue anyway? (y/N): " -n 1 -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Aborted."
            exit 1
        fi
    fi
else
    echo "⚠ Cannot verify image (docker/gh CLI not available)"
fi
```

**Impact**: Prevents batch submission of 186 jobs with bad image tag. Saves hours of debugging.

### 4. Comprehensive Documentation (High Priority)

**Add to `docs/DOCKER_WORKFLOW.md`** after line 98:

#### New Section: Testing Feature Branch Changes

```markdown
## Testing Feature Branch Changes

**Problem:** You're working on a feature branch and need to test changes on RunAI/cluster before merging to main.

**Solution:** Use workflow_dispatch to manually build and push your feature branch.

### Step-by-Step Guide

1. **Go to Actions page:**
   https://github.com/.../actions/workflows/docker-build.yml

2. **Click "Run workflow"** button (top right)

3. **Select your feature branch** from the dropdown
   - Example: `feat/add-ci-testing-workflows`

4. **Choose environment:**
   - Select: `test` (adds `-test` suffix to tags)

5. **Click "Run workflow"**

6. **Wait for build to complete** (~10-15 minutes)
   - Monitor: Actions page

7. **Get your image tag** from the build summary:
   - Primary tag: `sha-<commit>-test`
   - Example: `ghcr.io/.../gapit3-gwas-pipeline:sha-0f972d4-test`

8. **Update your RunAI scripts:**
   ```bash
   # In .env file:
   IMAGE=ghcr.io/.../gapit3-gwas-pipeline:sha-0f972d4-test

   # Or in submit command:
   runai workspace submit gapit3-test \
     --image ghcr.io/.../gapit3-gwas-pipeline:sha-0f972d4-test \
     ...
   ```

9. **Run your RunAI jobs** - image will now be available!

### Listing Available Images

**GitHub Container Registry (GHCR):**

```bash
# Method 1: Use gh CLI
gh api "/user/packages/container/gapit3-gwas-pipeline/versions" | jq -r '.[].metadata.container.tags[]' | sort -u

# Method 2: Use GitHub web UI
https://github.com/.../packages/container/gapit3-gwas-pipeline

# Method 3: Try pulling (will fail if doesn't exist)
docker pull ghcr.io/.../gapit3-gwas-pipeline:sha-0f972d4-test
# Error: manifest unknown = image doesn't exist
# Success: Downloaded = image exists
```

### Common Errors and Solutions

#### Error: ImagePullBackOff

**Symptom:**
```bash
runai workspace describe gapit3-trait-2
# Status: ImagePullBackOff
# Error: failed to pull image: manifest unknown
```

**Cause:** Image tag doesn't exist in registry.

**Solution:**
1. Check if tag exists in GitHub Packages
2. If not listed → Use workflow_dispatch to build and push
3. OR use a known-good tag like `main-test` or `latest`

**Quick Fix:**
```bash
# Use main-test (always available after main branch builds)
IMAGE=ghcr.io/.../gapit3-gwas-pipeline:main-test
```
```

**Update `.env.example`** (add before IMAGE line):

```bash
# Docker Image Configuration
# ===========================================================================
# IMPORTANT: Ensure image exists in registry before submitting jobs!
# Check available tags: https://github.com/.../packages/container/gapit3-gwas-pipeline
#
# Common tags:
#   latest              - Latest production release
#   main-test           - Latest from main branch (updated on each merge)
#   sha-<commit>-test   - Specific commit (from workflow_dispatch or main push)
#   v1.0.0              - Specific version release
#
# WARNING: Do NOT use tags from PR builds (pr-N-test, sha-XXX-test from PRs)
#          These are NOT pushed to the registry and will cause ImagePullBackOff!
#
# To build a feature branch for testing:
#   1. Go to: https://github.com/.../actions/workflows/docker-build.yml
#   2. Click "Run workflow"
#   3. Select your branch
#   4. Environment: test
#   5. Run workflow
#   6. Use the sha-<commit>-test tag from build output
# ===========================================================================
IMAGE=ghcr.io/.../gapit3-gwas-pipeline:latest
```

## Alternatives Considered

### Alternative 1: Push PR Images to Separate Registry

**Idea**: Push PR images to `ghcr.io/.../gapit3-pr:pr-123-test`

**Pros**: Images available for testing

**Cons**:
- Security risk (fork PRs could push malicious images)
- Registry clutter (hundreds of PR images)
- Confusion about which images are "approved"

**Verdict**: REJECT - Security risk outweighs benefit

### Alternative 2: Auto-Trigger workflow_dispatch on PR Creation

**Idea**: When PR created, automatically run workflow_dispatch

**Pros**: Image automatically available

**Cons**:
- Doubles CI time (build twice per PR)
- Wastes CI minutes
- Still need workflow_dispatch for later commits

**Verdict**: REJECT - Wasteful, doesn't solve core issue

### Alternative 3: Don't Generate Tags for PR Builds

**Idea**: Remove tag generation from PR builds entirely

**Pros**: Can't copy non-existent tags

**Cons**:
- Lose visibility into what tags would be created
- Verification tests need tags
- Breaking change to workflow

**Verdict**: REJECT - Tags needed for testing

### Selected Approach: Improve UX Around Current Behavior

**Rationale**: The workflow is technically correct (PRs don't push for security). The issue is communication, not functionality. Fix via:
1. Better CI summaries (impossible to miss warnings)
2. Proactive PR comments (guidance when needed)
3. Validation (prevent mistakes)
4. Comprehensive docs (troubleshooting)

This is the safest, most maintainable solution that maintains security posture.

## Dependencies

- GitHub Actions `actions/github-script@v7` (for PR comments)
- `gh` CLI v2.0+ OR Docker CLI v20+ (for image validation)
- Existing `.github/workflows/docker-build.yml` workflow
- Existing `scripts/submit-all-traits-runai.sh` script

## Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| PR comments become noisy | Medium | Low | Use <details> for long content, only show once per PR |
| Image validation slows submission | Low | Low | Validation is fast (~2s), skippable with flag |
| Documentation becomes outdated | Medium | Medium | Link to workflow file for authoritative source |
| validation requires extra tools (gh/docker) | Medium | Low | Graceful degradation if tools not available |

## Success Criteria

1. ✅ PR build summaries prominently show "NOT PUSHED" warning
2. ✅ PR comments appear automatically with step-by-step instructions
3. ✅ Image validation catches non-existent tags before job submission
4. ✅ DOCKER_WORKFLOW.md includes comprehensive feature branch testing guide
5. ✅ .env.example has clear IMAGE tag guidance with warnings
6. ✅ ImagePullBackOff incidents reduced to zero within 6 months
7. ✅ Users report improved clarity in developer feedback surveys

## Timeline Estimate

- Workflow CI summary improvements: 1 hour
- PR comment automation: 30 minutes
- Image validation in submit script: 30 minutes
- Documentation updates: 1.5 hours
- Testing (create test PR, verify): 1 hour
- **Total**: ~4 hours

## Open Questions

1. **Should validation be skippable?**
   - Add `--skip-image-validation` flag?
   - **Decision**: Yes, add flag for advanced users who know what they're doing

2. **Should we validate in other scripts?**
   - Also add to `monitor-runai-jobs.sh`, `cleanup-runai.sh`?
   - **Decision**: No - only submit script needs validation (prevents job creation)

3. **Should PR comments update on new commits?**
   - Edit existing comment vs create new one?
   - **Decision**: Edit existing comment to reduce noise

4. **Should we add a CLI command to list available images?**
   - New script: `scripts/list-docker-images.sh`?
   - **Decision**: Out of scope - gh CLI already provides this

## Next Steps

1. Get approval for proposal
2. Implement changes in order: workflow → validation → docs
3. Test with actual PR on feature branch
4. Validate all scenarios work as expected
5. Deploy to main
6. Monitor for ImagePullBackOff incidents (should drop to zero)
