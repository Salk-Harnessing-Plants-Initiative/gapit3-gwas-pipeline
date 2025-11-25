# Validate R Scripts

Validate R scripts for syntax errors and common issues without running them.

## Syntax Check All Scripts

```bash
# Check all R scripts for syntax errors
for script in scripts/*.R tests/testthat/*.R; do
  if [ -f "$script" ]; then
    echo "Validating: $script"
    Rscript -e "source('$script', echo=FALSE)" 2>&1 | grep -q "Error" && echo "✗ Syntax error" || echo "✓ Valid"
  fi
done
```

## Parse Without Execution

```bash
# Parse R script without running it
Rscript -e "tryCatch(parse('scripts/run_gwas_single_trait.R'), error = function(e) { cat('Syntax error:', conditionMessage(e), '\n'); quit(status=1) })"
```

## Quick Single Script Check

```bash
Rscript --vanilla -e "parse('scripts/run_gwas_single_trait.R')"
```

## Using lintr (Recommended)

```bash
# Install lintr package
Rscript -e "install.packages('lintr')"

# Lint all R scripts
Rscript -e "lintr::lint_dir('scripts', pattern = '\\.R$')"

# Lint specific file
Rscript -e "lintr::lint('scripts/run_gwas_single_trait.R')"
```

## Description

This command validates R scripts for:

1. **Syntax errors**
   - Unclosed brackets/parentheses
   - Invalid function calls
   - Undefined variables (parse-time)

2. **Style issues (with lintr)**
   - Line length violations (>80 chars)
   - Whitespace issues
   - Naming conventions (snake_case)
   - Unused variables
   - Missing documentation

## Common Issues Found by lintr

### Line too long
```r
# Bad
long_variable_name <- data.table::fread("very/long/path/to/file/that/exceeds/eighty/characters.csv")

# Good
long_variable_name <- data.table::fread(
  "very/long/path/to/file/that/exceeds/eighty/characters.csv"
)
```

### Trailing whitespace
```r
# Bad (space at end)
x <- 1

# Good
x <- 1
```

### Missing documentation
```r
# Bad
my_function <- function(x, y) {
  return(x + y)
}

# Good
#' Add two numbers
#'
#' @param x First number
#' @param y Second number
#' @return Sum of x and y
my_function <- function(x, y) {
  return(x + y)
}
```

## Configure lintr

Create `.lintr` file in project root:

```r
linters: linters_with_defaults(
  line_length_linter(120),  # Allow 120 chars instead of 80
  object_name_linter = NULL,  # Disable snake_case enforcement
  cyclocomp_linter(25)  # Allow complexity up to 25
)
```

## Expected Output

```
Validating: scripts/run_gwas_single_trait.R
✓ Valid
Validating: scripts/validate_inputs.R
✓ Valid
Validating: scripts/collect_results.R
✓ Valid

All R scripts valid!
```

## Static Analysis

For deeper analysis:

```bash
# Check for potential bugs
Rscript -e "goodpractice::gp('.')"

# Check code complexity
Rscript -e "cyclocomp::cyclocomp('scripts/run_gwas_single_trait.R')"
```

## CI Integration

R script validation could be added to `.github/workflows/test-r-scripts.yml`:

```yaml
- name: Lint R scripts
  run: Rscript -e "lintr::lint_dir('scripts')"
```

## Fix Style Issues

```bash
# Auto-format R code with styler
Rscript -e "install.packages('styler')"
Rscript -e "styler::style_dir('scripts')"
```

## Related Commands

- `/test-r` - Run R unit tests
- `/validate-bash` - Validate shell scripts