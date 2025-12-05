# Tasks: Improve Docker Workflow UX

## Overview

This document breaks down the implementation into concrete, verifiable tasks. Tasks are ordered for incremental delivery and can be partially parallelized.

**Total Estimated Time**: 3-4 hours

---

## Phase 1: GitHub Workflow Improvements (1.5 hours)

### Task 1.1: Update CI Build Summary for PR Builds (30 min)

**File**: `.github/workflows/docker-build.yml`
**Lines**: 133-142 (replace existing `Display build summary` step)

**Steps**:
1. [ ] Add conditional logic to detect PR vs pushed builds
2. [ ] Implement PR-specific summary with warning
3. [ ] Add collapsed `<details>` section for PR tags
4. [ ] Add testing instructions with workflow_dispatch link
5. [ ] Test with actual PR build

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

**Acceptance Criteria**:
- [ ] PR builds show "⚠️ Image NOT Pushed" warning prominently
- [ ] Tags are collapsed in `<details>` section for PRs
- [ ] Pushed builds show "✅ Image Pushed" with pull command
- [ ] Links to workflow_dispatch work correctly
- [ ] Emoji render correctly in GitHub UI

---

### Task 1.2: Add PR Comment Automation (45 min)

**File**: `.github/workflows/docker-build.yml`
**Location**: New step after `Display build summary` (after line 142)

**Steps**:
1. [ ] Add new step using `actions/github-script@v7`
2. [ ] Implement comment template with testing instructions
3. [ ] Add logic to update existing comment vs create new
4. [ ] Include PR-specific metadata (branch, SHA, PR number)
5. [ ] Test comment creation on PR
6. [ ] Test comment update on new commit to PR

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

**Acceptance Criteria**:
- [ ] Comment appears on PR after build completes
- [ ] Comment includes correct branch name from PR
- [ ] Comment includes correct SHA (first 7 chars)
- [ ] Comment includes correct PR number
- [ ] Subsequent commits update existing comment (don't duplicate)
- [ ] Links in comment are clickable and work
- [ ] Comment renders correctly (markdown formatting)

---

### Task 1.3: Update Workflow Input Descriptions (15 min)

**File**: `.github/workflows/docker-build.yml`
**Lines**: 24-37 (workflow_dispatch inputs)

**Steps**:
1. [ ] Improve `environment` input description
2. [ ] Clarify `version` input usage (prod only)
3. [ ] Add examples in descriptions

**Implementation**:
```yaml
workflow_dispatch:
  inputs:
    environment:
      description: 'Environment: test (adds -test suffix) or prod (for releases)'
      required: true
      type: choice
      options:
        - test
        - prod
      default: 'test'
    version:
      description: 'Version tag for prod builds ONLY (e.g., 1.0.0). Leave empty for test builds.'
      required: false
      type: string
```

**Acceptance Criteria**:
- [ ] Descriptions are clear and concise
- [ ] Examples help users understand expected format
- [ ] No ambiguity about when to use version input

---

## Phase 2: Script Validation (1 hour)

### Task 2.1: Add Image Validation Function (30 min)

**File**: `scripts/submit-all-traits-runai.sh`
**Location**: After configuration loading, before job submission confirmation

**Steps**:
1. [ ] Create `validate_image()` function
2. [ ] Implement Method 1: Docker manifest inspect
3. [ ] Implement Method 2: gh CLI API check
4. [ ] Implement Method 3: Graceful skip
5. [ ] Add `SKIP_IMAGE_VALIDATION` environment variable support
6. [ ] Add user confirmation prompt for invalid images

**Implementation**:
```bash
# ===========================================================================
# Image Validation
# ===========================================================================

validate_image() {
    local image="$1"
    local skip_validation="${SKIP_IMAGE_VALIDATION:-false}"

    if [[ "$skip_validation" == "true" ]]; then
        echo -e "${YELLOW}⚠ Skipping image validation (SKIP_IMAGE_VALIDATION=true)${NC}"
        return 0
    fi

    echo ""
    echo -e "${YELLOW}Validating Docker image availability...${NC}"

    # Method 1: Try docker manifest inspect
    if command -v docker >/dev/null 2>&1; then
        if docker manifest inspect "$image" >/dev/null 2>&1; then
            echo -e "${GREEN}✓ Image found: $image${NC}"
            return 0
        fi
    fi

    # Method 2: Try gh CLI
    if command -v gh >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠ Cannot verify with Docker, checking GitHub registry...${NC}"

        TAG="${image##*:}"

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

**Acceptance Criteria**:
- [ ] Function validates image with docker CLI if available
- [ ] Falls back to gh CLI if docker not available
- [ ] Gracefully skips if neither tool available
- [ ] Shows clear warning for non-existent images
- [ ] Provides actionable troubleshooting guidance
- [ ] Allows user to abort or continue
- [ ] Respects SKIP_IMAGE_VALIDATION flag

---

### Task 2.2: Test Validation with Various Scenarios (30 min)

**Test Cases**:

1. [ ] **Valid image (main-test)**:
   ```bash
   IMAGE=ghcr.io/salk-harnessing-plants-initiative/gapit3-gwas-pipeline:main-test
   ./scripts/submit-all-traits-runai.sh --start-trait 2 --end-trait 3
   # Expected: Validation passes, proceeds to submission
   ```

2. [ ] **Invalid image (PR tag)**:
   ```bash
   IMAGE=ghcr.io/salk-harnessing-plants-initiative/gapit3-gwas-pipeline:sha-0f972d4-test
   ./scripts/submit-all-traits-runai.sh --start-trait 2 --end-trait 3
   # Expected: Warning shown, user prompted
   ```

3. [ ] **Skip validation**:
   ```bash
   SKIP_IMAGE_VALIDATION=true IMAGE=ghcr.io/.../nonexistent ./scripts/submit-all-traits-runai.sh --start-trait 2 --end-trait 3
   # Expected: Skips validation, proceeds
   ```

4. [ ] **No docker/gh CLI**:
   ```bash
   PATH=/usr/bin IMAGE=ghcr.io/.../main-test ./scripts/submit-all-traits-runai.sh --start-trait 2 --end-trait 3
   # Expected: Graceful warning, proceeds
   ```

**Acceptance Criteria**:
- [ ] All test cases pass as expected
- [ ] Error messages are clear and actionable
- [ ] Script exits cleanly on validation failure (user chooses N)
- [ ] Script continues correctly on validation success

---

## Phase 3: Documentation Updates (1.5 hours)

### Task 3.1: Add Feature Branch Testing Guide (45 min)

**File**: `docs/DOCKER_WORKFLOW.md`
**Location**: New section after "Workflow Triggers" (after line 98)

**Steps**:
1. [ ] Create "Testing Feature Branch Changes" section
2. [ ] Add step-by-step workflow_dispatch guide
3. [ ] Add "Listing Available Images" subsection
4. [ ] Add "Common Errors and Solutions" subsection
5. [ ] Add quick reference table
6. [ ] Link to GitHub Packages for image browsing

**Content Outline**:
```markdown
## Testing Feature Branch Changes

**Problem:** [Describe scenario]

**Solution:** [workflow_dispatch overview]

### Step-by-Step Guide

[9 numbered steps with code examples]

### Listing Available Images

[3 methods: gh CLI, web UI, docker pull test]

### Common Errors and Solutions

#### Error: ImagePullBackOff
[Symptom, cause, solution, quick fix]
```

**Acceptance Criteria**:
- [ ] Guide is comprehensive (covers all steps)
- [ ] Examples use correct repository URLs
- [ ] Code blocks are properly formatted
- [ ] Links to GitHub Actions/Packages work
- [ ] Quick reference table is accurate
- [ ] Troubleshooting section covers ImagePullBackOff

---

### Task 3.2: Update .env.example with IMAGE Guidance (15 min)

**File**: `.env.example`
**Location**: Before IMAGE variable (line 119)

**Steps**:
1. [ ] Add comprehensive IMAGE configuration comment block
2. [ ] List common tag formats with explanations
3. [ ] Add warning about PR build tags
4. [ ] Include workflow_dispatch instructions
5. [ ] Add link to GitHub Packages

**Implementation**:
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
IMAGE=ghcr.io/salk-harnessing-plants-initiative/gapit3-gwas-pipeline:latest
```

**Acceptance Criteria**:
- [ ] Comment block is comprehensive
- [ ] Tag formats are clearly explained
- [ ] Warning about PR builds is prominent
- [ ] workflow_dispatch instructions are accurate
- [ ] Link to GitHub Packages works

---

### Task 3.3: Update RUNAI_QUICK_REFERENCE.md (15 min)

**File**: `docs/RUNAI_QUICK_REFERENCE.md`
**Location**: Add note to "Docker Image" section

**Steps**:
1. [ ] Add image validation note
2. [ ] Link to DOCKER_WORKFLOW.md testing guide
3. [ ] Add troubleshooting quick link

**Implementation**:
```markdown
## Docker Image

**Verify image exists before submitting jobs:**
```bash
# Method 1: Pull test
docker pull ghcr.io/.../gapit3-gwas-pipeline:sha-abc1234-test

# Method 2: Check GitHub Packages
https://github.com/.../packages/container/gapit3-gwas-pipeline
```

**Testing feature branches:**
See [Docker Workflow Guide - Testing Feature Branches](DOCKER_WORKFLOW.md#testing-feature-branch-changes)

**Troubleshooting ImagePullBackOff:**
See [Docker Workflow Guide - Common Errors](DOCKER_WORKFLOW.md#common-errors-and-solutions)
```

**Acceptance Criteria**:
- [ ] Note added to appropriate section
- [ ] Links work correctly
- [ ] Examples are accurate

---

### Task 3.4: Update README.md (15 min)

**File**: `README.md`
**Location**: Add quick link in "Quick Start" or "Docker" section

**Steps**:
1. [ ] Add prominent link to feature branch testing guide
2. [ ] Add note about image validation
3. [ ] Link to troubleshooting

**Implementation**:
```markdown
### Testing Feature Branches

Need to test code changes before merging? See [Testing Feature Branch Changes](docs/DOCKER_WORKFLOW.md#testing-feature-branch-changes) for step-by-step instructions.

### Troubleshooting

**ImagePullBackOff errors?** See [Common Errors and Solutions](docs/DOCKER_WORKFLOW.md#common-errors-and-solutions)
```

**Acceptance Criteria**:
- [ ] Link is prominent and easy to find
- [ ] Links work correctly
- [ ] Note about validation is clear

---

## Phase 4: Testing and Validation (1 hour)

### Task 4.1: Integration Test - Full PR Workflow (30 min)

**Steps**:
1. [ ] Create test feature branch: `test/docker-workflow-ux-validation`
2. [ ] Modify Dockerfile (add comment)
3. [ ] Push and create PR
4. [ ] Wait for build to complete
5. [ ] Verify CI summary shows "NOT PUSHED" warning
6. [ ] Verify PR comment appears with correct info
7. [ ] Manually trigger workflow_dispatch for test branch
8. [ ] Wait for build to complete
9. [ ] Verify CI summary shows "PUSHED" with tags
10. [ ] Copy image tag from summary
11. [ ] Update .env with tag
12. [ ] Run: `./scripts/submit-all-traits-runai.sh --start-trait 2 --end-trait 3`
13. [ ] Verify image validation passes
14. [ ] Verify 2 jobs submitted successfully
15. [ ] Verify jobs don't fail with ImagePullBackOff

**Acceptance Criteria**:
- [ ] All verification steps pass
- [ ] CI summary is clear and accurate
- [ ] PR comment is helpful and correct
- [ ] Image validation works as expected
- [ ] Jobs submit and run successfully

---

### Task 4.2: Regression Test - Existing Workflows (15 min)

**Test Cases**:

1. [ ] **Push to main**:
   ```bash
   git checkout main
   git pull
   # Modify Dockerfile
   git commit -am "test: Verify main push workflow"
   git push origin main
   # Verify: Image pushed, CI shows "PUSHED"
   ```

2. [ ] **Git tag push**:
   ```bash
   git tag v0.0.1-test
   git push origin v0.0.1-test
   # Verify: Production image created
   ```

3. [ ] **workflow_dispatch (test env)**:
   ```
   # Manually trigger via UI
   # Branch: main
   # Environment: test
   # Verify: Image pushed with -test suffix
   ```

**Acceptance Criteria**:
- [ ] All existing workflows still function correctly
- [ ] No breaking changes introduced
- [ ] CI summaries appropriate for each workflow type

---

### Task 4.3: Documentation Review (15 min)

**Steps**:
1. [ ] Read through all updated documentation
2. [ ] Verify all links work
3. [ ] Verify all code examples are accurate
4. [ ] Check markdown formatting renders correctly
5. [ ] Verify consistency across all docs

**Checklist**:
- [ ] DOCKER_WORKFLOW.md renders correctly
- [ ] All GitHub URLs are correct
- [ ] All code blocks have proper syntax highlighting
- [ ] Examples use correct image paths
- [ ] Quick reference table is accurate
- [ ] .env.example comments are clear
- [ ] RUNAI_QUICK_REFERENCE.md updated

---

## Phase 5: Validation and Cleanup (30 min)

### Task 5.1: OpenSpec Validation (10 min)

**Steps**:
1. [ ] Run: `openspec validate improve-docker-workflow-ux --strict`
2. [ ] Resolve any validation errors
3. [ ] Verify all files are properly formatted

**Acceptance Criteria**:
- [ ] OpenSpec validation passes
- [ ] No errors or warnings

---

### Task 5.2: Commit and Document Changes (10 min)

**Steps**:
1. [ ] Create comprehensive commit message
2. [ ] Update CHANGELOG.md with changes
3. [ ] Tag commit appropriately

**Commit Message Template**:
```
feat: Improve Docker workflow UX to prevent ImagePullBackOff incidents

- Update CI build summaries to prominently show "NOT PUSHED" for PRs
- Add automatic PR comments with feature branch testing instructions
- Add image validation to submit script to prevent bad tag submissions
- Add comprehensive feature branch testing guide to docs
- Update .env.example with IMAGE configuration guidance

Prevents incidents where users copy image tags from PR builds that are
never pushed to the registry, causing mass job failures (186 jobs).

Closes #XXX
```

**Acceptance Criteria**:
- [ ] Commit message follows conventional commits format
- [ ] CHANGELOG.md updated with user-facing changes
- [ ] Changes documented thoroughly

---

### Task 5.3: Create GitHub Issue/PR (10 min)

**Steps**:
1. [ ] Create issue describing the problem and solution
2. [ ] Reference real incident (186-job failure)
3. [ ] Create PR linking to issue
4. [ ] Add checklist to PR description

**PR Checklist**:
```markdown
## Changes

- [x] Enhanced CI build summaries (PR vs pushed)
- [x] Added PR comment automation
- [x] Added image validation to submit script
- [x] Updated DOCKER_WORKFLOW.md with testing guide
- [x] Updated .env.example with IMAGE guidance
- [x] Updated RUNAI_QUICK_REFERENCE.md
- [x] Added README quick links

## Testing

- [x] Created test PR, verified summaries and comments
- [x] Tested image validation with valid/invalid tags
- [x] Verified all documentation links work
- [x] Regression tested existing workflows

## Verification

- [x] OpenSpec validation passes
- [x] No breaking changes to existing workflows
- [x] All test cases pass
```

**Acceptance Criteria**:
- [ ] Issue created with clear problem statement
- [ ] PR created with comprehensive description
- [ ] All checklist items verified

---

## Summary

**Total Tasks**: 18 tasks across 5 phases
**Estimated Time**: 3-4 hours

**Critical Path**:
1. Task 1.1 (CI summaries) → Task 4.1 (integration test)
2. Task 1.2 (PR comments) → Task 4.1 (integration test)
3. Task 2.1 (validation) → Task 2.2 (test validation) → Task 4.1 (integration test)

**Parallelizable**:
- Task 1.3 (workflow inputs) - can be done anytime
- Phase 3 (documentation) - can be done in parallel with Phase 2

**Dependencies**:
- Phase 4 requires Phases 1, 2, 3 to be complete
- Task 2.2 requires Task 2.1
- Task 4.1 requires all previous phases

**Verification Points**:
- After Phase 1: Test PR to verify summaries/comments
- After Phase 2: Test validation with various images
- After Phase 3: Review all documentation links
- After Phase 4: Full integration test
- After Phase 5: OpenSpec validation

---

## Next Steps After Completion

1. Monitor for ImagePullBackOff incidents (should be zero)
2. Gather user feedback on clarity improvements
3. Consider Phase 2 enhancements (image cleanup, notifications)
4. Update onboarding docs to reference new testing guide
