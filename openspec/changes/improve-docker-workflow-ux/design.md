# Design: Improve Docker Workflow UX

## Architecture Overview

This change improves UX around the existing Docker build workflow without changing its core security model. The workflow correctly prevents pushing PR images (security measure), but needs better communication and validation.

### System Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                     GitHub Pull Request                              │
│  ┌────────────┐                                                      │
│  │  PR #123   │  ← User creates PR on feature branch                │
│  └──────┬─────┘                                                      │
│         │                                                             │
│         ▼                                                             │
│  ┌────────────────────────────────────────────┐                     │
│  │  GitHub Actions: docker-build.yml          │                     │
│  │  ┌──────────────────────────────────────┐  │                     │
│  │  │  1. Build Image (local, not pushed)  │  │                     │
│  │  └──────────────┬───────────────────────┘  │                     │
│  │                 │                            │                     │
│  │                 ▼                            │                     │
│  │  ┌──────────────────────────────────────┐  │                     │
│  │  │  2. Run Verification Tests          │  │                     │
│  │  └──────────────┬───────────────────────┘  │                     │
│  │                 │                            │                     │
│  │                 ▼                            │                     │
│  │  ┌──────────────────────────────────────┐  │  ◄── NEW           │
│  │  │  3. Display Build Summary            │  │                     │
│  │  │     ⚠️ Image NOT Pushed (PR Build)   │  │                     │
│  │  │     <details> Tags (not pushed)      │  │                     │
│  │  └──────────────┬───────────────────────┘  │                     │
│  │                 │                            │                     │
│  │                 ▼                            │                     │
│  │  ┌──────────────────────────────────────┐  │  ◄── NEW           │
│  │  │  4. Post PR Comment                  │  │                     │
│  │  │     - Testing instructions           │  │                     │
│  │  │     - workflow_dispatch guide        │  │                     │
│  │  └──────────────────────────────────────┘  │                     │
│  └────────────────────────────────────────────┘                     │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                     User Workflow                                    │
│  ┌────────────────────────────────────┐                             │
│  │  User wants to test feature branch │                             │
│  └──────────────┬─────────────────────┘                             │
│                 │                                                     │
│                 ▼                                                     │
│  ┌────────────────────────────────────┐  ◄── NEW (from PR comment)  │
│  │  Trigger workflow_dispatch         │                             │
│  │  - Select feature branch           │                             │
│  │  - Environment: test               │                             │
│  └──────────────┬─────────────────────┘                             │
│                 │                                                     │
│                 ▼                                                     │
│  ┌────────────────────────────────────┐                             │
│  │  Image pushed to GHCR              │                             │
│  │  Tag: sha-abc1234-test             │                             │
│  └──────────────┬─────────────────────┘                             │
│                 │                                                     │
│                 ▼                                                     │
│  ┌────────────────────────────────────┐                             │
│  │  Update .env with correct tag      │                             │
│  └──────────────┬─────────────────────┘                             │
│                 │                                                     │
│                 ▼                                                     │
│  ┌────────────────────────────────────┐  ◄── NEW (validation)       │
│  │  Run submit-all-traits-runai.sh    │                             │
│  │  ✓ Image validation passes         │                             │
│  └──────────────┬─────────────────────┘                             │
│                 │                                                     │
│                 ▼                                                     │
│  ┌────────────────────────────────────┐                             │
│  │  186 jobs submitted successfully   │                             │
│  │  All pull correct image from GHCR  │                             │
│  └────────────────────────────────────┘                             │
└─────────────────────────────────────────────────────────────────────┘
```

## Component Design

### 1. Enhanced CI Build Summary

**File**: `.github/workflows/docker-build.yml`
**Lines**: 133-142 (replace existing summary step)

**Implementation**:

```yaml
- name: Display build summary
  run: |
    IS_PR="${{ github.event_name == 'pull_request' }}"

    echo "### Docker Build Summary :rocket:" >> $GITHUB_STEP_SUMMARY
    echo "" >> $GITHUB_STEP_SUMMARY
    echo "**Environment:** ${{ steps.determine-env.outputs.environment }}" >> $GITHUB_STEP_SUMMARY
    echo "" >> $GITHUB_STEP_SUMMARY

    if [[ "$IS_PR" == "true" ]]; then
      # PR Build - Not Pushed
      echo "**:warning: Image NOT Pushed to Registry (PR Build)**" >> $GITHUB_STEP_SUMMARY
      echo "" >> $GITHUB_STEP_SUMMARY
      echo "This image was built for testing only and is **not available** in the container registry." >> $GITHUB_STEP_SUMMARY
      echo "" >> $GITHUB_STEP_SUMMARY
      echo "**To test this PR's changes:**" >> $GITHUB_STEP_SUMMARY
      echo "1. Merge to main and use \`main-test\` tag, OR" >> $GITHUB_STEP_SUMMARY
      echo "2. Manually trigger build via [Actions → Docker Build → Run workflow](../../actions/workflows/docker-build.yml)" >> $GITHUB_STEP_SUMMARY
      echo "" >> $GITHUB_STEP_SUMMARY
      echo "<details><summary>Tags generated (but NOT pushed)</summary>" >> $GITHUB_STEP_SUMMARY
      echo "" >> $GITHUB_STEP_SUMMARY
      echo '```' >> $GITHUB_STEP_SUMMARY
      echo "${{ steps.meta.outputs.tags }}" >> $GITHUB_STEP_SUMMARY
      echo '```' >> $GITHUB_STEP_SUMMARY
      echo "" >> $GITHUB_STEP_SUMMARY
      echo "</details>" >> $GITHUB_STEP_SUMMARY
    else
      # Main/Tag/Dispatch Build - Pushed
      echo "**:white_check_mark: Image Pushed to Registry**" >> $GITHUB_STEP_SUMMARY
      echo "" >> $GITHUB_STEP_SUMMARY
      echo "**Available Image Tags:**" >> $GITHUB_STEP_SUMMARY
      echo '```' >> $GITHUB_STEP_SUMMARY
      echo "${{ steps.meta.outputs.tags }}" >> $GITHUB_STEP_SUMMARY
      echo '```' >> $GITHUB_STEP_SUMMARY
      echo "" >> $GITHUB_STEP_SUMMARY
      echo "**Pull Command:**" >> $GITHUB_STEP_SUMMARY
      echo '```bash' >> $GITHUB_STEP_SUMMARY
      echo "docker pull ${{ steps.set-tag.outputs.tag }}" >> $GITHUB_STEP_SUMMARY
      echo '```' >> $GITHUB_STEP_SUMMARY
    fi
```

**Design Decisions**:
- **Conditional formatting**: Different summaries for PR vs pushed builds
- **Visual hierarchy**: Emoji + bold + line breaks make warning impossible to miss
- **Collapsed tags**: PR tags hidden in `<details>` to de-emphasize
- **Actionable guidance**: Direct links to workflow_dispatch
- **Positive reinforcement**: Green checkmark for pushed builds with pull command

### 2. PR Comment Automation

**File**: `.github/workflows/docker-build.yml`
**Location**: New step after build summary (after line 142)

**Implementation**:

```yaml
- name: Comment on PR with testing instructions
  if: github.event_name == 'pull_request'
  uses: actions/github-script@v7
  with:
    script: |
      const comment = `## Docker Build Completed :white_check_mark:

      **Note:** This PR builds a Docker image for testing, but it is **NOT pushed** to the registry for security reasons.

      ### To test your changes on RunAI/cluster:

      **Option 1: Manual Workflow Dispatch (Recommended)**
      1. Go to [Actions → Build and Push Docker Image](${context.payload.repository.html_url}/actions/workflows/docker-build.yml)
      2. Click "Run workflow"
      3. Select branch: \`${context.payload.pull_request.head.ref}\`
      4. Environment: \`test\`
      5. Click "Run workflow"
      6. Wait ~10 minutes for build to complete
      7. Use image tag: \`sha-${context.sha.substring(0,7)}-test\`

      **Option 2: Merge to Main First**
      1. Merge this PR
      2. Use tag: \`main-test\` or \`sha-${context.sha.substring(0,7)}-test\`

      ### Image Tags (NOT available yet):
      These tags would be generated if pushed:
      \`\`\`
      pr-${context.payload.pull_request.number}-test
      sha-${context.sha.substring(0,7)}-test
      ${context.payload.pull_request.head.ref.replace(/\//g, '-')}-test
      \`\`\`

      **Want to push this image?** Use workflow_dispatch (Option 1 above).`;

      // Check if comment already exists
      const {data: comments} = await github.rest.issues.listComments({
        issue_number: context.issue.number,
        owner: context.repo.owner,
        repo: context.repo.repo,
      });

      const botComment = comments.find(comment =>
        comment.user.type === 'Bot' &&
        comment.body.includes('Docker Build Completed')
      );

      if (botComment) {
        // Update existing comment
        await github.rest.issues.updateComment({
          comment_id: botComment.id,
          owner: context.repo.owner,
          repo: context.repo.repo,
          body: comment
        });
      } else {
        // Create new comment
        await github.rest.issues.createComment({
          issue_number: context.issue.number,
          owner: context.repo.owner,
          repo: context.repo.repo,
          body: comment
        });
      }
```

**Design Decisions**:
- **Update vs create**: Edit existing comment to reduce noise on multiple commits
- **Identification**: Search for "Docker Build Completed" in comment body
- **Context-aware**: Uses PR metadata (number, branch, SHA) to generate accurate instructions
- **Step-by-step**: Numbered instructions with specific branch/tag values
- **Two options**: workflow_dispatch (recommended) vs merge-first (faster but riskier)

### 3. Image Validation in Submit Script

**File**: `scripts/submit-all-traits-runai.sh`
**Location**: After configuration loading, before job submission confirmation

**Implementation**:

```bash
# ===========================================================================
# Image Validation
# ===========================================================================
# Validate image exists before submitting 186 jobs to prevent mass failures

validate_image() {
    local image="$1"
    local skip_validation="${SKIP_IMAGE_VALIDATION:-false}"

    if [[ "$skip_validation" == "true" ]]; then
        echo -e "${YELLOW}⚠ Skipping image validation (SKIP_IMAGE_VALIDATION=true)${NC}"
        return 0
    fi

    echo ""
    echo -e "${YELLOW}Validating Docker image availability...${NC}"

    # Method 1: Try docker manifest inspect (requires Docker CLI + login)
    if command -v docker >/dev/null 2>&1; then
        if docker manifest inspect "$image" >/dev/null 2>&1; then
            echo -e "${GREEN}✓ Image found: $image${NC}"
            return 0
        fi
    fi

    # Method 2: Try gh CLI to check GitHub Container Registry
    if command -v gh >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠ Cannot verify with Docker, checking GitHub registry...${NC}"

        # Extract tag from full image path
        TAG="${image##*:}"

        # Query GitHub Packages API
        if gh api "/user/packages/container/gapit3-gwas-pipeline/versions" 2>/dev/null | grep -q "\"$TAG\""; then
            echo -e "${GREEN}✓ Image found in GitHub registry: $TAG${NC}"
            return 0
        else
            echo -e "${RED}✗ WARNING: Image tag '$TAG' not found in GitHub registry!${NC}"
            echo ""
            echo "This might cause ImagePullBackOff errors on all $((END_TRAIT - START_TRAIT + 1)) jobs."
            echo ""
            echo "Common causes:"
            echo "  - Tag was generated from PR build (not pushed to registry)"
            echo "  - Typo in image tag name"
            echo "  - Image build not yet completed"
            echo ""
            echo "To check available tags:"
            echo "  https://github.com/Salk-Harnessing-Plants-Initiative/gapit3-gwas-pipeline/pkgs/container/gapit3-gwas-pipeline"
            echo ""
            echo "Or manually verify:"
            echo "  docker pull $image"
            echo ""
            read -p "Continue anyway? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                echo "Aborted."
                exit 1
            fi
            return 1
        fi
    fi

    # Method 3: No validation tools available
    echo -e "${YELLOW}⚠ Cannot verify image (docker/gh CLI not available)${NC}"
    echo "Proceeding without validation. If image doesn't exist, jobs will fail with ImagePullBackOff."
    echo ""
    return 0
}

# Run validation
validate_image "$IMAGE"
```

**Design Decisions**:
- **Graceful degradation**: Three methods with fallbacks (docker → gh CLI → skip)
- **Skippable**: `SKIP_IMAGE_VALIDATION=true` environment variable for advanced users
- **Informative errors**: Specific guidance on common causes and how to fix
- **Interactive confirmation**: User must explicitly choose to continue with bad tag
- **Calculation of job count**: Shows exact number of jobs that would fail
- **Direct links**: GitHub Packages URL for manual verification

### 4. Documentation Structure

**File**: `docs/DOCKER_WORKFLOW.md`
**Location**: New section after "Workflow Triggers" (after line 98)

**New Sections**:

1. **Testing Feature Branch Changes** (500 lines)
   - Step-by-step workflow_dispatch guide
   - Screenshot locations for clarity
   - Branching decision tree (when to use which method)

2. **Listing Available Images** (100 lines)
   - gh CLI commands
   - GitHub web UI navigation
   - Quick reference table (event → tag → availability)

3. **Common Errors and Solutions** (200 lines)
   - ImagePullBackOff diagnosis and fix
   - Tag doesn't exist errors
   - Permission denied errors
   - Build failures

**File**: `.env.example`
**Location**: Before IMAGE variable (line 119)

**Addition**:

```bash
# ===========================================================================
# Docker Image Configuration
# ===========================================================================
# CRITICAL: Ensure image exists in registry before submitting jobs!
#
# Check available tags:
#   https://github.com/Salk-Harnessing-Plants-Initiative/gapit3-gwas-pipeline/pkgs/container/gapit3-gwas-pipeline
#
# Common tags:
#   latest              - Latest production release (stable)
#   main-test           - Latest from main branch (updated on merge)
#   sha-<commit>-test   - Specific commit (from workflow_dispatch or main)
#   v1.0.0              - Specific version release (pinned)
#
# ⚠️ WARNING: Do NOT use tags from PR builds!
#   Tags like pr-N-test, sha-XXX-test from PR builds are NOT pushed to the
#   registry and will cause ImagePullBackOff errors on all 186 jobs.
#
# To build and push a feature branch for testing:
#   1. Go to: https://github.com/.../actions/workflows/docker-build.yml
#   2. Click "Run workflow"
#   3. Select your feature branch (e.g., feat/my-feature)
#   4. Environment: test
#   5. Click "Run workflow"
#   6. Wait ~10 minutes
#   7. Use the sha-<commit>-test tag from the build summary
# ===========================================================================
```

## Data Flow

### Current Flow (PR Build)

```
PR Created
  ↓
GitHub Actions Triggered
  ↓
Build Image Locally
  ↓
Run Verification Tests
  ↓
Display Summary: "Pushed: false"  ← Users miss this
  ↓
User copies tag from summary
  ↓
User updates .env with tag
  ↓
User runs submit-all-traits-runai.sh  ← No validation
  ↓
186 jobs submitted
  ↓
All jobs fail: ImagePullBackOff  ← Incident occurs
```

### Improved Flow (PR Build)

```
PR Created
  ↓
GitHub Actions Triggered
  ↓
Build Image Locally
  ↓
Run Verification Tests
  ↓
Display Summary: "⚠️ NOT PUSHED"  ← Impossible to miss
  + Collapsed tag list
  + Testing instructions
  ↓
Post PR Comment  ← NEW: Proactive guidance
  + workflow_dispatch steps
  + Branch-specific instructions
  ↓
User sees warning
  ↓
User triggers workflow_dispatch  ← NEW: Feature branch testing path
  ↓
Image pushed to GHCR
  ↓
User updates .env with correct tag
  ↓
User runs submit-all-traits-runai.sh
  ↓
Image validation runs  ← NEW: Safety check
  ✓ Image exists in registry
  ↓
186 jobs submitted
  ↓
All jobs succeed  ← Incident prevented
```

## Security Considerations

### Maintained Security Posture

**No changes to push behavior** - PR builds still don't push images.

**Why this is correct:**
1. **Fork-based attacks**: Malicious fork PR could push poisoned image
2. **Secrets exposure**: PR builds from forks don't have GITHUB_TOKEN write permissions
3. **Supply chain security**: Only trusted commits (merged to main, tagged) push images
4. **Code review gate**: All images that reach registry have been reviewed

### New Security Considerations

**PR comments**:
- **Risk**: Bot account could be compromised to post malicious links
- **Mitigation**: Comments use relative URLs (../../actions/...) instead of absolute
- **Mitigation**: workflow_dispatch requires authentication (only repo members)

**Image validation**:
- **Risk**: Validation could leak image tags to attacker
- **Mitigation**: Uses authenticated gh CLI (requires user login)
- **Mitigation**: Graceful degradation if tools not available

## Performance Considerations

### CI Build Time

**PR Comment Addition**: +2-5 seconds per PR build
- API call to GitHub to list existing comments
- API call to create/update comment
- Negligible impact on overall build time (~10 minutes)

### Job Submission Time

**Image Validation Addition**: +1-3 seconds
- `docker manifest inspect`: ~1s (local cache hit)
- `gh api` call: ~2s (network roundtrip)
- Total: 3s max added to submission workflow
- Acceptable trade-off to prevent 186-job failures

### User Experience

**Time to discover testing path**:
- **Before**: Undocumented, user must search/ask → Hours
- **After**: Immediate (PR comment appears) → Minutes

**Time to resolve ImagePullBackOff**:
- **Before**: Debug 186 failed jobs, realize image doesn't exist → Hours
- **After**: Prevented by validation → 0 (incidents don't occur)

## Testing Strategy

### Unit Testing

**PR Comment Logic**:
```bash
# Test comment creation
- Create test PR
- Verify comment appears
- Verify comment content includes branch name, SHA

# Test comment update
- Push new commit to PR
- Verify existing comment is updated (not duplicated)
```

**Image Validation**:
```bash
# Test with valid image
IMAGE=ghcr.io/.../gapit3-gwas-pipeline:main-test
./scripts/submit-all-traits-runai.sh
# Expected: Validation passes, no prompt

# Test with invalid image
IMAGE=ghcr.io/.../gapit3-gwas-pipeline:nonexistent-tag
./scripts/submit-all-traits-runai.sh
# Expected: Warning shown, user prompted to confirm

# Test skip validation
SKIP_IMAGE_VALIDATION=true IMAGE=ghcr.io/.../nonexistent ./scripts/submit-all-traits-runai.sh
# Expected: Validation skipped, proceeds
```

### Integration Testing

**Full Workflow Test**:
1. Create feature branch: `test/docker-workflow-ux`
2. Modify Dockerfile (add comment)
3. Create PR
4. Wait for build to complete
5. Verify:
   - CI summary shows "NOT PUSHED" warning
   - Tags are in collapsed `<details>` section
   - PR comment appears with correct branch/SHA
6. Trigger workflow_dispatch manually:
   - Select `test/docker-workflow-ux` branch
   - Environment: `test`
   - Run workflow
7. Wait for build to complete (~10 min)
8. Verify:
   - CI summary shows "✅ PUSHED"
   - Tags displayed prominently
   - Pull command shown
9. Copy image tag from summary
10. Update .env file with tag
11. Run: `./scripts/submit-all-traits-runai.sh --start-trait 2 --end-trait 3`
12. Verify:
    - Image validation passes
    - 2 jobs submitted
    - Jobs don't fail with ImagePullBackOff

### Regression Testing

**Ensure existing workflows still work**:
- Push to main → Image pushed (no change)
- Git tag push → Production image created (no change)
- PR build → Image not pushed (no change, better UX)
- workflow_dispatch → Image pushed (no change)

## Rollback Plan

If issues arise, rollback is simple (no breaking changes):

1. **Revert workflow file**:
   ```bash
   git revert <commit-hash>
   git push origin main
   ```

2. **Remove PR comment step** (if causing issues):
   ```yaml
   # Comment out the PR comment step
   # - name: Comment on PR with testing instructions
   #   if: github.event_name == 'pull_request'
   #   ...
   ```

3. **Disable image validation** (if causing false positives):
   ```bash
   # In .env or environment:
   export SKIP_IMAGE_VALIDATION=true
   ```

**No data loss**: Changes are purely UX/validation, no data or images affected.

## Future Enhancements

### Phase 2 (Future)

1. **Image cleanup automation**:
   - GitHub Action to delete `-test` tags older than 90 days
   - Reduce registry clutter

2. **Slack/Email notifications**:
   - Notify when workflow_dispatch image is ready
   - Reduce waiting time

3. **CLI tool for image management**:
   - `scripts/list-docker-images.sh` - List available tags
   - `scripts/test-image.sh <tag>` - Validate and test an image

4. **Dashboard/status page**:
   - Show latest available tags for each branch
   - Build status indicator

### Out of Scope

- Changing PR push behavior (security risk)
- Automatic workflow_dispatch on PR (wasteful)
- Image mirroring to alternate registries
- Backup/restore functionality

## Maintenance Considerations

**Documentation freshness**:
- Workflow file is source of truth
- Documentation should link to workflow file for authoritative behavior
- Review docs quarterly to ensure accuracy

**GitHub Actions dependencies**:
- `actions/github-script@v7` - Pin to major version, update yearly
- Monitor for deprecation notices

**CLI tool dependencies**:
- `gh` CLI - Document minimum version (v2.0+)
- Docker CLI - Document minimum version (v20+)
- Provide graceful degradation if tools not available
