# Validate Bash Scripts

Validate all bash scripts for syntax errors and common issues using shellcheck.

## Command

```bash
# Run syntax check on all scripts
for script in scripts/*.sh; do
  if [ -f "$script" ]; then
    echo "Checking: $script"
    bash -n "$script" && echo "✓ Syntax OK"
  fi
done
```

## With ShellCheck (Recommended)

```bash
# Install shellcheck (if not already installed)
# Ubuntu/Debian: sudo apt-get install shellcheck
# macOS: brew install shellcheck
# Windows: choco install shellcheck

# Run shellcheck on all scripts
for script in scripts/*.sh; do
  if [ -f "$script" ]; then
    echo "ShellCheck: $script"
    shellcheck -e SC1091 "$script"
  fi
done
```

## Quick Single Script Check

```bash
bash -n scripts/entrypoint.sh && shellcheck scripts/entrypoint.sh
```

## Description

This command validates bash scripts for:

1. **Syntax errors** (bash -n)
   - Missing quotes
   - Unclosed brackets
   - Invalid variable references

2. **ShellCheck issues**
   - Unused variables
   - Incorrect quoting
   - Potential word splitting issues
   - Unquoted variable expansions
   - Deprecated syntax

## Common Issues Found

### SC2086: Double quote to prevent globbing
```bash
# Bad
echo $VARIABLE

# Good
echo "$VARIABLE"
```

### SC2046: Quote to prevent word splitting
```bash
# Bad
for file in $(find . -name "*.sh"); do

# Good
while IFS= read -r file; do
done < <(find . -name "*.sh")
```

### SC2155: Separate declaration and assignment
```bash
# Bad
local var="$(command)"

# Good
local var
var="$(command)"
```

## Ignored Checks

`.github/workflows/validate-bash-scripts.yml` ignores:
- **SC1091**: Not following source files (external scripts may not be in repo)

## Expected Output

```
Checking: scripts/entrypoint.sh
✓ Syntax OK
ShellCheck: scripts/entrypoint.sh
✓ No issues

Checking: scripts/monitor-runai-jobs.sh
✓ Syntax OK
ShellCheck: scripts/monitor-runai-jobs.sh
✓ No issues
```

## CI Integration

Bash validation runs automatically in `.github/workflows/validate-bash-scripts.yml` on:
- Changes to `scripts/**/*.sh`
- Pull requests

The workflow checks:
1. Bash syntax (bash -n)
2. ShellCheck analysis
3. Shebang consistency
4. Safe bash options (set -euo pipefail)

## Fix Common Issues Automatically

Many ShellCheck issues can be auto-fixed:

```bash
# Format with shfmt (optional)
# Install: go install mvdan.cc/sh/v3/cmd/shfmt@latest
shfmt -w -i 2 -ci scripts/*.sh
```

## Related Commands

- `/validate-yaml` - Validate Argo YAML files
- `/validate-r` - Validate R scripts