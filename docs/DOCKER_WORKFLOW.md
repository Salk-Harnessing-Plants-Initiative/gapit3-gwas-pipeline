# Docker Workflow Guide

Complete guide for building, testing, and deploying Docker images with test/prod separation.

---

## Overview

The pipeline uses a **two-tier tagging strategy**:
- **Test images** (`-test` suffix): Built on PRs and main branch merges
- **Production images** (no suffix): Built on version tags or manual dispatch with version input

---

## Tagging Strategy

### Test Images (Development)

Built automatically for:
- **Pull requests**: `pr-<number>-test`
- **Main branch pushes**: `main-test`, `sha-<commit>-test`

**Examples:**
```
ghcr.io/salk-harnessing-plants-initiative/gapit3-gwas-pipeline:pr-1-test
ghcr.io/salk-harnessing-plants-initiative/gapit3-gwas-pipeline:main-test
ghcr.io/salk-harnessing-plants-initiative/gapit3-gwas-pipeline:sha-abc1234-test
```

### Production Images (Stable)

Built for:
- **Git tags**: `v1.0.0`, `v1.0`, `latest`
- **Manual dispatch** with version input

**Examples:**
```
ghcr.io/salk-harnessing-plants-initiative/gapit3-gwas-pipeline:latest
ghcr.io/salk-harnessing-plants-initiative/gapit3-gwas-pipeline:1.0.0
ghcr.io/salk-harnessing-plants-initiative/gapit3-gwas-pipeline:1.0
```

---

## Workflow Triggers

### 1. Pull Request (Automatic - Test Build)

**Trigger:** Any PR to any branch that modifies:
- `Dockerfile`
- `scripts/**`
- `config/**`
- `.github/workflows/docker-build.yml`

**Result:**
- Builds image locally (not pushed)
- Runs verification tests
- Tags: `pr-<number>-test`

### 2. Main Branch Push (Automatic - Test Build)

**Trigger:** Push to `main` branch with relevant file changes

**Result:**
- Builds and pushes to GHCR
- Runs verification tests
- Tags: `main-test`, `sha-<commit>-test`

### 3. Version Tag (Automatic - Production Build)

**Trigger:** Push a semantic version tag

**Steps:**
```bash
git tag v1.0.0
git push origin v1.0.0
```

**Result:**
- Builds and pushes to GHCR
- Runs verification tests
- Tags: `1.0.0`, `1.0`, `latest`

### 4. Manual Dispatch (Manual - Test or Prod)

**Trigger:** Manually via GitHub Actions UI

**Options:**
- **Environment**: `test` or `prod`
- **Version**: Required for `prod` builds (e.g., `1.0.0`)

**Steps:**
1. Go to: https://github.com/Salk-Harnessing-Plants-Initiative/gapit3-gwas-pipeline/actions/workflows/docker-build.yml
2. Click "Run workflow"
3. Select environment
4. Enter version (if prod)
5. Click "Run workflow"

---

## Verification Tests

All builds run verification tests:

✅ **R Installation**
- Verifies R 4.4.1 is installed

✅ **GAPIT3 Package**
- Loads GAPIT library
- Checks version

✅ **Required R Packages**
- Tests all dependencies load correctly
- Packages: `data.table`, `dplyr`, `tidyr`, `ggplot2`, `readr`, `matrixStats`, `gridExtra`, `optparse`, `yaml`, `jsonlite`

✅ **Entrypoint Script**
- Tests `--help` command
- Validates entrypoint routing

✅ **Validation Script**
- Runs input validation script
- Ensures error handling works

---

## Usage Examples

### Pull Production Image

```bash
# Latest production version
docker pull ghcr.io/salk-harnessing-plants-initiative/gapit3-gwas-pipeline:latest

# Specific version
docker pull ghcr.io/salk-harnessing-plants-initiative/gapit3-gwas-pipeline:1.0.0

# Latest test version
docker pull ghcr.io/salk-harnessing-plants-initiative/gapit3-gwas-pipeline:main-test
```

### Run Container

```bash
# Test help
docker run --rm ghcr.io/salk-harnessing-plants-initiative/gapit3-gwas-pipeline:latest --help

# Run single trait
docker run --rm \
  -v /path/to/data:/data \
  -v /path/to/outputs:/outputs \
  ghcr.io/salk-harnessing-plants-initiative/gapit3-gwas-pipeline:latest \
  run-single-trait --trait-index 2
```

---

## Creating a Production Release

### Step-by-Step Process

1. **Test on `main` branch first**
   ```bash
   git checkout main
   git pull
   # Verify main-test image works
   docker pull ghcr.io/salk-harnessing-plants-initiative/gapit3-gwas-pipeline:main-test
   ```

2. **Create and push version tag**
   ```bash
   git tag -a v1.0.0 -m "Release v1.0.0: Initial production release"
   git push origin v1.0.0
   ```

3. **Wait for GitHub Actions**
   - Monitor: https://github.com/Salk-Harnessing-Plants-Initiative/gapit3-gwas-pipeline/actions
   - Build takes ~10-15 minutes
   - Verification tests run automatically

4. **Verify production image**
   ```bash
   docker pull ghcr.io/salk-harnessing-plants-initiative/gapit3-gwas-pipeline:1.0.0
   docker run --rm ghcr.io/salk-harnessing-plants-initiative/gapit3-gwas-pipeline:1.0.0 --help
   ```

5. **Update Argo workflows** (if needed)
   ```yaml
   # Update image tag in cluster/argo workflows
   image: ghcr.io/salk-harnessing-plants-initiative/gapit3-gwas-pipeline:1.0.0
   ```

---

## Troubleshooting

### Build Failed

**Check logs:**
```bash
gh run list --workflow=docker-build.yml
gh run view <run-id> --log-failed
```

**Common issues:**
- R package installation failure → Check CRAN mirror availability
- Docker layer caching → Try manual dispatch to rebuild from scratch

### Verification Failed

**Test locally:**
```bash
docker build -t gapit3-test .
docker run --rm gapit3-test R --version
docker run --rm gapit3-test R -e "library(GAPIT)"
```

### Wrong Tag

**Delete and retag:**
```bash
# Delete remote tag
git push origin --delete v1.0.0

# Delete local tag
git tag -d v1.0.0

# Create correct tag
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0
```

---

## Path Filtering

The workflow only builds when these files change:
- `Dockerfile`
- `scripts/**`
- `config/**`
- `.github/workflows/docker-build.yml`

**Skipped builds** for:
- Documentation changes (`docs/**`, `*.md`)
- Data files
- Cluster configs (unless workflow file itself changes)

This saves CI minutes and avoids unnecessary builds.

---

## Best Practices

1. **Always test with `-test` suffix first**
   - Merge PR → Test `main-test` image
   - Only tag production when confident

2. **Use semantic versioning**
   - `v1.0.0` - Major release
   - `v1.1.0` - New features
   - `v1.0.1` - Bug fixes

3. **Create GitHub releases**
   - Go to: https://github.com/Salk-Harnessing-Plants-Initiative/gapit3-gwas-pipeline/releases
   - Click "Create a new release"
   - Select tag
   - Add release notes

4. **Pin production images in Argo**
   ```yaml
   # Good (pinned version)
   image: ghcr.io/.../gapit3-gwas-pipeline:1.0.0

   # Avoid (floating tag)
   image: ghcr.io/.../gapit3-gwas-pipeline:latest
   ```

---

## Advanced: Manual Production Build

If you need to build a production image without creating a git tag:

1. Go to Actions → Build and Push Docker Image
2. Click "Run workflow"
3. Select:
   - **Branch**: `main`
   - **Environment**: `prod`
   - **Version**: `1.0.0` (or your version)
4. Run workflow

**Result:**
```
ghcr.io/salk-harnessing-plants-initiative/gapit3-gwas-pipeline:1.0.0
```

---

## Related Documentation

- [Argo Setup Guide](ARGO_SETUP.md) - Cluster deployment
- [Main README](../README.md) - Project overview
- [Quick Start](../QUICKSTART.md) - Getting started

---

**Questions?** Open an issue: https://github.com/Salk-Harnessing-Plants-Initiative/gapit3-gwas-pipeline/issues
