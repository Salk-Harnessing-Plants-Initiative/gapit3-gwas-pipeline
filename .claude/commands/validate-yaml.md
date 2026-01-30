# Validate Argo Workflow YAML Files

Validate Argo Workflow YAML files for syntax errors and schema compliance.

## Basic YAML Syntax Check

```bash
# Check all YAML files for valid syntax
for yaml in cluster/argo/**/*.yaml; do
  if [ -f "$yaml" ]; then
    echo "Validating: $yaml"
    python -c "import yaml; yaml.safe_load(open('$yaml'))" && echo "✓ Valid YAML"
  fi
done
```

## Using yq (Recommended)

```bash
# Install yq
# macOS: brew install yq
# Linux: wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/local/bin/yq
# Windows: choco install yq

# Validate and pretty-print YAML
for yaml in cluster/argo/**/*.yaml; do
  if [ -f "$yaml" ]; then
    echo "Validating: $yaml"
    yq eval '.' "$yaml" > /dev/null && echo "✓ Valid YAML"
  fi
done
```

## Argo Workflow Schema Validation

```bash
# Requires argo CLI installed
# Check Argo workflow syntax
argo lint cluster/argo/workflows/*.yaml
argo lint cluster/argo/workflow-templates/*.yaml
```

## Single File Validation

```bash
# Validate specific workflow
argo lint cluster/argo/workflows/gapit3-test-pipeline.yaml

# Or using Python
python -c "import yaml; print(yaml.safe_load(open('cluster/argo/workflows/gapit3-test-pipeline.yaml')))"
```

## Description

This command validates YAML files for:

1. **Syntax errors**
   - Incorrect indentation
   - Missing colons
   - Invalid YAML structures

2. **Argo-specific issues**
   - Invalid apiVersion
   - Missing required fields (metadata, spec)
   - Invalid workflow templates
   - Parameter mismatches

## Common Issues

### Indentation errors
```yaml
# Bad - inconsistent indentation
spec:
  templates:
   - name: example
     script:
```

```yaml
# Good - consistent 2-space indentation
spec:
  templates:
    - name: example
      script:
```

### Missing quotes for special characters
```yaml
# Bad
- name: test-value-with-special-chars
  value: 5e-8

# Good
- name: test-value-with-special-chars
  value: "5e-8"
```

### Invalid workflow references
```yaml
# Bad - template not defined
tasks:
  - name: run-task
    template: non-existent-template

# Good - template exists
templates:
  - name: my-template
    script: ...
tasks:
  - name: run-task
    template: my-template
```

## Expected Output

```
Validating: cluster/argo/workflows/gapit3-test-pipeline.yaml
✓ Valid YAML
Validating: cluster/argo/workflows/gapit3-parallel-pipeline.yaml
✓ Valid YAML
Validating: cluster/argo/workflow-templates/single-trait-template.yaml
✓ Valid YAML

All YAML files valid!
```

## Validate Before Submission

Always validate YAML before submitting workflows to the cluster:

```bash
# 1. Validate syntax
argo lint cluster/argo/workflows/my-workflow.yaml

# 2. Dry-run submission (doesn't actually run)
argo submit --dry-run cluster/argo/workflows/my-workflow.yaml

# 3. Submit if validation passes
argo submit cluster/argo/workflows/my-workflow.yaml
```

## Installing argo CLI

```bash
# macOS
brew install argo

# Linux
curl -sLO https://github.com/argoproj/argo-workflows/releases/download/v3.5.0/argo-linux-amd64.gz
gunzip argo-linux-amd64.gz
chmod +x argo-linux-amd64
sudo mv argo-linux-amd64 /usr/local/bin/argo

# Windows
choco install argo
```

## Related Commands

- `/validate-bash` - Validate shell scripts
- `/submit-test-workflow` - Submit validated workflow