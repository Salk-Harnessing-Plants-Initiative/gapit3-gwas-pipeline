# Spec: Docker Workflow User Experience

## ADDED Requirements

### Requirement: CI Build Summary Push Status

CI build summaries MUST clearly indicate whether Docker images are pushed to the registry, preventing users from copying image tags that don't exist in the registry (which causes mass job failures with ImagePullBackOff errors).

#### Scenario: PR build shows prominent NOT PUSHED warning

- **WHEN** a pull request Docker build workflow completes
- **THEN** the CI summary SHALL display a prominent warning "⚠️ Image NOT Pushed to Registry (PR Build)"
- **AND** provide an explanation that the image is not available in the container registry
- **AND** include instructions for testing feature branch changes via workflow_dispatch
- **AND** collapse generated tags in a `<details>` section to de-emphasize them

#### Scenario: Pushed build shows success confirmation

- **WHEN** a Docker build that pushes images completes (main branch, git tag, or workflow_dispatch)
- **THEN** the CI summary SHALL display a success indicator "✅ Image Pushed to Registry"
- **AND** show the available image tags prominently
- **AND** provide a ready-to-copy pull command for the primary tag

---

### Requirement: PR Comment Automation for Testing Instructions

Pull requests MUST receive automated comments with step-by-step instructions for testing feature branch changes, providing proactive guidance exactly when users need it.

#### Scenario: PR receives initial testing instructions comment

- **WHEN** a pull request's Docker build workflow completes for the first time
- **THEN** a comment SHALL be posted to the PR that includes:
  - Explanation that PR builds don't push images (security measure)
  - Step-by-step workflow_dispatch instructions specific to the PR's branch
  - The PR's branch name, commit SHA, and PR number in code examples
  - Two testing options: workflow_dispatch (recommended) or merge-first

#### Scenario: PR comment updates on subsequent commits

- **WHEN** a new commit is pushed to a PR that already has a Docker build comment
- **AND** the Docker build workflow completes
- **THEN** the existing comment SHALL be updated with the new commit SHA
- **AND** no duplicate comments SHALL be created

---

### Requirement: Docker Image Validation Before Job Submission

The RunAI job submission script MUST validate that Docker images exist in the registry before submitting batch jobs, preventing incidents where 186 jobs fail with ImagePullBackOff due to non-existent image tags.

#### Scenario: Validation succeeds with existing image

- **WHEN** the IMAGE environment variable points to an existing registry image
- **AND** the user runs `submit-all-traits-runai.sh`
- **THEN** the script SHALL check if the image exists using docker manifest inspect or gh CLI
- **AND** display "✓ Image found: <tag>"
- **AND** proceed to job submission without prompting the user

#### Scenario: Validation warns for non-existent image

- **WHEN** the IMAGE environment variable points to a non-existent tag (e.g., from PR build)
- **AND** the user runs `submit-all-traits-runai.sh`
- **THEN** the script SHALL display "✗ WARNING: Image tag not found in GitHub registry"
- **AND** explain common causes (PR build tag, typo, build not complete)
- **AND** show the number of jobs that would fail
- **AND** provide a link to check available tags
- **AND** prompt the user to confirm or abort submission

#### Scenario: Validation can be skipped by advanced users

- **WHEN** the SKIP_IMAGE_VALIDATION environment variable is set to "true"
- **AND** the user runs `submit-all-traits-runai.sh`
- **THEN** the script SHALL display "⚠ Skipping image validation"
- **AND** proceed to job submission without checking the image

#### Scenario: Validation handles missing tools gracefully

- **WHEN** neither Docker CLI nor gh CLI are available in PATH
- **AND** the user runs `submit-all-traits-runai.sh`
- **THEN** the script SHALL display "⚠ Cannot verify image (docker/gh CLI not available)"
- **AND** warn that ImagePullBackOff may occur if image doesn't exist
- **AND** proceed to job submission without validation

---

### Requirement: Feature Branch Testing Documentation

Documentation MUST provide a comprehensive step-by-step guide for testing feature branch changes before merging, filling the critical gap where users have no clear path to test Docker image changes.

#### Scenario: User successfully tests feature branch via documentation

- **WHEN** a user consults `docs/DOCKER_WORKFLOW.md#testing-feature-branch-changes`
- **THEN** the documentation SHALL include:
  - Problem statement explaining the feature branch testing use case
  - Step-by-step workflow_dispatch instructions (numbered steps 1-9)
  - How to find the resulting image tag from the build summary
  - How to update .env or scripts with the correct tag
  - How to verify the image is available in the registry

#### Scenario: User troubleshoots ImagePullBackOff via documentation

- **WHEN** a user encounters an ImagePullBackOff error
- **AND** consults `docs/DOCKER_WORKFLOW.md#common-errors-and-solutions`
- **THEN** the documentation SHALL include:
  - Symptom description with example error message
  - Root cause explanation (image tag doesn't exist)
  - Diagnosis steps (check GitHub Packages, try docker pull)
  - Solution options (use workflow_dispatch to build image, use known-good tag)
  - Quick fix code examples with working tags

---

### Requirement: ENV Example Image Configuration Guidance

The `.env.example` file MUST provide clear, comprehensive guidance on Docker image configuration to prevent users from inadvertently using invalid image tags from PR builds.

#### Scenario: ENV example warns about PR build tags

- **WHEN** a user reviews `.env.example` for IMAGE configuration
- **THEN** the file SHALL include a comment block that:
  - Explains different image tag formats (latest, main-test, sha-XXX-test, vX.Y.Z)
  - Warns prominently about NOT using tags from PR builds
  - Explains that PR build tags cause ImagePullBackOff errors (all 186 jobs fail)
  - Lists safe tag formats with descriptions
  - Provides step-by-step instructions for building feature branch images via workflow_dispatch

#### Scenario: ENV example provides tag discovery methods

- **WHEN** a user is uncertain which image tag to use
- **AND** reviews `.env.example` IMAGE configuration
- **THEN** the file SHALL include:
  - Direct link to GitHub Container Registry package page
  - Example gh CLI command to list available tags
  - Example docker pull command to test if a tag exists

---

## MODIFIED Requirements

### Requirement: Workflow Dispatch Input Descriptions

GitHub Actions workflow_dispatch inputs SHALL have clear, unambiguous descriptions that explain when to use each parameter and provide format examples.

#### Scenario: User understands environment input options

- **WHEN** a user triggers workflow_dispatch via GitHub Actions UI
- **AND** views the environment input field
- **THEN** the description SHALL clearly indicate:
  - That "test" adds `-test` suffix to image tags
  - That "prod" is for creating release images
  - The difference in use cases (testing vs production releases)

#### Scenario: User understands version input usage

- **WHEN** a user triggers workflow_dispatch via GitHub Actions UI
- **AND** views the version input field
- **THEN** the description SHALL clearly indicate:
  - That version is ONLY for prod builds
  - That version should be left empty for test builds
  - Example format for version (e.g., 1.0.0)

---

## Cross-References

**Related Capabilities**:
- `runai-job-submission` - Image validation prevents bad job submissions
- `ci-workflows` - Enhanced build summaries improve CI user experience
- `environment-configuration` - .env.example guidance complements .env usage patterns

**Dependencies**:
- Requires `actions/github-script@v7` for PR comment automation
- Requires gh CLI v2.0+ OR Docker CLI v20+ for image validation (with graceful degradation)
- Requires existing `.github/workflows/docker-build.yml` workflow
- Requires existing `scripts/submit-all-traits-runai.sh` script

**Security Considerations**:
- PR builds continue to NOT push images (security measure preserved - prevents fork-based attacks)
- PR comments use relative URLs (../../actions/...) to prevent phishing
- workflow_dispatch requires GitHub authentication (only repository members can trigger)
- Image validation uses authenticated gh CLI (prevents image tag leakage to unauthorized users)

---

## Implementation Notes

**Backward Compatibility**:
- All changes are additive (no breaking changes to existing functionality)
- Existing workflows (push to main, git tags, workflow_dispatch) continue to function identically
- Image validation is optional and can be skipped via SKIP_IMAGE_VALIDATION flag
- Documentation additions don't affect or replace existing documentation

**Testing Strategy**:
- Create test PR to verify enhanced summaries and automated comments
- Test image validation with valid tags (should pass silently)
- Test image validation with invalid tags (should warn and prompt)
- Test validation skip flag (should bypass validation)
- Verify all documentation links work correctly
- Regression test existing workflows (push, tag, workflow_dispatch)

**Rollback Plan**:
- Revert workflow file changes (single file: `.github/workflows/docker-build.yml`)
- Remove validation function from submit script
- Documentation updates can remain (informational only, non-breaking)
- No data loss risk (changes are purely UX/validation)

**Success Metrics**:
- ImagePullBackOff incidents drop to zero within 6 months
- Increased workflow_dispatch usage for feature branch testing
- Positive user feedback on PR comments (helpful vs noisy)
- Reduced support requests about Docker image availability
