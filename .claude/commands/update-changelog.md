# Update CHANGELOG

Maintain the project CHANGELOG.md following Keep a Changelog format.

## Command Template

```
Update CHANGELOG.md based on recent changes. Review git commits since last release and categorize changes.
```

## CHANGELOG Format

The project follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) format:

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- New features that have been added

### Changed
- Changes to existing functionality

### Fixed
- Bug fixes

### Deprecated
- Features that will be removed in future versions

### Removed
- Features that have been removed

### Security
- Security fixes and improvements

## [1.0.0] - 2025-01-15

### Added
- Initial release
- Core GWAS pipeline functionality
```

## When to Update CHANGELOG

Update CHANGELOG when:
- Adding new features
- Fixing bugs
- Making breaking changes
- Updating dependencies (if significant)
- Improving documentation (if substantial)
- Refactoring code (if affects users)

## Manual Update Process

### Step 1: Review Recent Changes

```bash
# View commits since last tag
git log --oneline $(git describe --tags --abbrev=0)..HEAD

# Or view commits since specific date
git log --oneline --since="2025-01-01"

# Or view diff since last tag
git diff $(git describe --tags --abbrev=0)..HEAD --stat
```

### Step 2: Categorize Changes

Determine category for each change:

**Added** - New features:
- New scripts or capabilities
- New commands or options
- New documentation sections

**Changed** - Modifications to existing features:
- Updated behavior
- Improved performance
- Enhanced UX

**Fixed** - Bug fixes:
- Corrected errors
- Fixed crashes or failures
- Resolved edge cases

**Deprecated** - Soon to be removed:
- Features marked for future removal
- Old APIs being replaced

**Removed** - Deleted features:
- Removed scripts or functions
- Deleted deprecated code

**Security** - Security improvements:
- Vulnerability fixes
- Input validation improvements
- Access control updates

### Step 3: Write Entry

```markdown
## [Unreleased]

### Added
- Claude development commands for streamlined workflows (`/test-r`, `/docker-build`, etc.)
- Comprehensive PR review command with planning mode and ultrathink
- RunAI job monitoring dashboard script
- Automated result aggregation for GWAS analyses

### Changed
- Improved input validation to handle edge cases with zero-inflated traits
- Enhanced Docker build caching for faster rebuild times
- Updated documentation with detailed troubleshooting guides

### Fixed
- Corrected trait indexing off-by-one error in parallel workflows
- Fixed memory leak in aggregation script for large result sets
- Resolved YAML validation issues in Argo workflow templates

### Security
- Added input sanitization for file path parameters
- Improved error handling to prevent information leakage in logs
```

## Categories Explained

### Added
```markdown
### Added
- OpenSpec workflow for structured development proposals
- Bash validation GitHub workflow with shellcheck
- Coverage analysis support for R tests
- Interactive job monitoring dashboard
```

### Changed
```markdown
### Changed
- Updated R version from 4.3.0 to 4.4.1
- Improved entrypoint.sh to support runtime configuration via env vars
- Enhanced error messages with actionable troubleshooting steps
- Migrated from manual RunAI to Argo Workflows (when RBAC resolved)
```

### Fixed
```markdown
### Fixed
- Fixed aggregation script failing on empty GWAS results
- Corrected Docker build failing on M1 Macs due to platform mismatch
- Resolved workflow validation errors with invalid parameter references
- Fixed cleanup script not excluding running jobs properly
```

## Release Process

When ready to release a version:

### Step 1: Move Unreleased to Versioned

```markdown
## [Unreleased]

(Leave empty or add future planned items)

## [1.1.0] - 2025-01-15

### Added
- (move items from Unreleased here)

### Changed
- (move items from Unreleased here)

### Fixed
- (move items from Unreleased here)
```

### Step 2: Update Version

Follow [Semantic Versioning](https://semver.org/):

- **MAJOR** (1.0.0 -> 2.0.0): Breaking changes
- **MINOR** (1.0.0 -> 1.1.0): New features (backward compatible)
- **PATCH** (1.0.0 -> 1.0.1): Bug fixes (backward compatible)

### Step 3: Create Git Tag

```bash
# Tag the release
git tag -a v1.1.0 -m "Release version 1.1.0"

# Push tag
git push origin v1.1.0

# Or push all tags
git push --tags
```

## Best Practices

### Be User-Focused

```markdown
Good: "Added automatic retry for failed trait analyses with configurable backoff"
Bad:  "Refactored retry logic implementation"

Good: "Fixed workflow failing when phenotype file contains spaces in column names"
Bad:  "Fixed parser bug"
```

### Include Context

```markdown
Good: "Updated OpenBLAS to 0.3.21 for 15% performance improvement in matrix operations"
Bad:  "Updated OpenBLAS"

Good: "Deprecated --legacy-mode flag; will be removed in v2.0.0 (use --models=BLINK instead)"
Bad:  "Deprecated --legacy-mode"
```

### Reference PRs and Issues

```markdown
### Added
- Comprehensive Claude development commands (#42)
- Automated GWAS result aggregation script (#38)

### Fixed
- Corrected trait validation logic for edge cases (fixes #35)
- Resolved Docker build failures on ARM platforms (#40)
```

### Group Related Changes

```markdown
### Changed
- Docker improvements:
  - Multi-stage builds for smaller image size
  - Layer caching for faster rebuilds
  - Runtime configuration via environment variables
```

## Quick Commands

```bash
# View commits for CHANGELOG entry
git log --oneline --no-merges v1.0.0..HEAD

# Count commits by type (conventional commits)
git log --oneline v1.0.0..HEAD | grep -c "^[a-f0-9]* feat:"
git log --oneline v1.0.0..HEAD | grep -c "^[a-f0-9]* fix:"

# Generate commit list
git log --pretty=format:"- %s (%h)" v1.0.0..HEAD
```

## CHANGELOG Location

- **File**: `CHANGELOG.md` (project root)
- **Format**: Markdown
- **Sections**: Sorted by version (newest first)

## Verification

After updating:

```bash
# Verify markdown syntax
# (Can use markdownlint or similar)

# Check that version numbers follow semver
# Check that dates are in YYYY-MM-DD format
# Ensure each entry is actionable and user-focused
```

## Related Commands

- `/pr-description` - Generate PR descriptions (source for CHANGELOG entries)
- `/review-pr` - Review PRs (may identify CHANGELOG-worthy changes)
