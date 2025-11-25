# Review GitHub Pull Request

Comprehensively review a GitHub Pull Request with planning mode, ultrathink analysis, and automated feedback posting.

## Command Template

```
Review PR #<NUMBER> using planning mode and ultrathink.

Steps:
1. Fetch PR details and all comments
2. Analyze code changes thoroughly
3. Post comprehensive review via gh CLI
```

## Usage

```bash
# Get PR number
gh pr list

# Review specific PR (replace <PR_NUMBER>)
# Then invoke this command and Claude will:
# - Use planning mode for structured analysis
# - Enable ultrathink for deep reasoning
# - Read all existing PR comments and reviews
# - Analyze code changes for correctness, style, and best practices
# - Post review feedback via gh CLI
```

## What This Command Does

### 1. Fetch PR Information

```bash
# View PR with all comments
gh pr view <PR_NUMBER> --comments

# Get inline code review comments
gh api repos/OWNER/REPO/pulls/<PR_NUMBER>/comments \
  --jq '.[] | {path: .path, line: .line, body: .body}'

# Get review summaries
gh api repos/OWNER/REPO/pulls/<PR_NUMBER>/reviews \
  --jq '.[].body'

# Get PR diff
gh pr diff <PR_NUMBER>
```

### 2. Analysis with Planning Mode & Ultrathink

The review uses:
- **Planning mode**: Structured approach to reviewing code systematically
- **Ultrathink**: Deep analysis of logic, edge cases, and potential issues

Review categories:
- **Correctness**: Logic errors, bugs, edge cases
- **Code quality**: Readability, maintainability, documentation
- **Best practices**: Project conventions, R/bash/YAML patterns
- **Testing**: Test coverage, test quality
- **Security**: Input validation, potential vulnerabilities
- **Performance**: Inefficiencies, optimization opportunities

### 3. Post Review via gh CLI

```bash
# Post review comment
gh pr review <PR_NUMBER> --comment --body "$(cat <<'EOF'
## Code Review

### Summary
[High-level overview of changes and assessment]

### Strengths
- Well-structured implementation
- Comprehensive tests included
- Clear documentation

### Issues Found

#### Critical
- [Issue description with file:line reference]

#### Important
- [Issue description with file:line reference]

#### Minor/Suggestions
- [Suggestion with rationale]

### Recommendations
1. [Action item]
2. [Action item]

### Questions
- [Clarification needed]
EOF
)"

# Or approve PR
gh pr review <PR_NUMBER> --approve --body "LGTM! ..."

# Or request changes
gh pr review <PR_NUMBER> --request-changes --body "Please address: ..."
```

## Example Workflow

### Step 1: List PRs
```bash
gh pr list --author @me
```

Output:
```
#42  feat: Add Claude dev commands   feat/add-ci-testing-workflows
#35  fix: Correct aggregation logic  fix/aggregation-model-tracking
```

### Step 2: Review PR in Claude
Invoke this command and tell Claude:

```
Review PR #42 using planning mode and ultrathink
```

### Step 3: Claude's Analysis Process

Claude will:
1. **Fetch all data**:
   - PR description and metadata
   - All existing comments and reviews
   - Full code diff
   - Related files for context

2. **Plan the review** (planning mode):
   - Identify files to review
   - Prioritize critical vs minor issues
   - Structure feedback categories

3. **Deep analysis** (ultrathink):
   - Trace code logic
   - Identify edge cases
   - Check against project conventions
   - Verify test coverage

4. **Post structured review**:
   - Clear categorization of issues
   - File:line references for each issue
   - Actionable recommendations
   - Overall assessment

## Review Checklist

The command ensures these are checked:

### Code Correctness
- [ ] Logic errors or bugs
- [ ] Edge cases handled
- [ ] Error handling present
- [ ] Input validation

### Code Quality
- [ ] Follows project conventions (snake_case, naming patterns)
- [ ] Clear variable/function names
- [ ] Adequate comments for complex logic
- [ ] No code duplication

### R-Specific
- [ ] Proper use of data.table/dplyr
- [ ] Memory-efficient operations
- [ ] Error messages informative
- [ ] optparse for CLI arguments
- [ ] Logging used appropriately

### Bash-Specific
- [ ] Shellcheck issues addressed
- [ ] Proper quoting
- [ ] set -euo pipefail present
- [ ] Error handling

### YAML-Specific
- [ ] Valid Argo workflow syntax
- [ ] Parameters documented
- [ ] Resource limits appropriate

### Testing
- [ ] Tests added for new functionality
- [ ] Tests cover edge cases
- [ ] Tests are clear and maintainable
- [ ] Fixtures appropriate

### Documentation
- [ ] README updated if needed
- [ ] Code comments for complex logic
- [ ] CHANGELOG entry added
- [ ] Function documentation (for R)

### Project-Specific
- [ ] Follows openspec/project.md conventions
- [ ] OpenSpec change proposal if needed
- [ ] CI workflows pass
- [ ] Docker build succeeds

## Addressing Review Comments

After Claude posts review:

### For PR Author

```bash
# View review comments
gh pr view <PR_NUMBER> --comments

# Make fixes based on feedback
# ... edit files ...

# Commit and push
git add .
git commit -m "fix: Address review feedback"
git push

# Reply to review
gh pr comment <PR_NUMBER> --body "Addressed all feedback:
- Fixed validation logic in scripts/validate_inputs.R:45
- Added tests for edge cases
- Updated documentation
"
```

### For Reviewer (Follow-up)

```bash
# Check if issues addressed
gh pr diff <PR_NUMBER>

# Post follow-up review
gh pr review <PR_NUMBER> --comment --body "Thanks for the fixes! LGTM now."

# Or approve
gh pr review <PR_NUMBER> --approve --body "All feedback addressed. Approving!"
```

## Advanced Options

### Review Specific Files Only

Tell Claude:
```
Review PR #42, focusing only on changes to scripts/*.R files
```

### Review for Specific Concerns

Tell Claude:
```
Review PR #42 for security vulnerabilities and input validation
```

### Compare Against Standards

Tell Claude:
```
Review PR #42 and check compliance with openspec/project.md conventions
```

## gh CLI Setup

Install gh CLI if needed:

```bash
# macOS
brew install gh

# Linux
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update
sudo apt install gh

# Windows
choco install gh

# Authenticate
gh auth login
```

## Related Commands

- `/pr-description` - Generate PR description
- `/update-changelog` - Update CHANGELOG based on PR
