# Run Docker Functional Tests

Run functional tests on the Docker container to verify proper operation.

## Quick Test Suite

Run all functional tests:

```bash
# Build image first if needed
docker build -t gapit3-gwas-pipeline:latest .

# Test 1: Validation command
docker run --rm -v $(pwd)/tests/fixtures:/data gapit3-gwas-pipeline:latest validate

# Test 2: Trait extraction
docker run --rm -v $(pwd)/tests/fixtures:/data gapit3-gwas-pipeline:latest extract-traits

# Test 3: Environment variable configuration
docker run --rm -e OPENBLAS_NUM_THREADS=8 gapit3-gwas-pipeline:latest bash -c 'echo $OPENBLAS_NUM_THREADS'

# Test 4: Entrypoint help
docker run --rm gapit3-gwas-pipeline:latest --help
```

## Individual Test Details

### Test 1: Input Validation

```bash
docker run --rm \
  -v $(pwd)/tests/fixtures:/data \
  -e GENOTYPE_FILE=/data/test_genotype.hmp.txt \
  -e PHENOTYPE_FILE=/data/test_phenotype.txt \
  gapit3-gwas-pipeline:latest validate
```

**Expected output**: "✓ All validation checks passed"

### Test 2: Trait Extraction

```bash
docker run --rm \
  -v $(pwd)/tests/fixtures:/data \
  -v $(pwd)/outputs:/outputs \
  -e PHENOTYPE_FILE=/data/test_phenotype.txt \
  gapit3-gwas-pipeline:latest extract-traits
```

**Expected output**: JSON manifest with 3 traits

### Test 3: Single Trait Execution (Dry Run)

```bash
docker run --rm \
  -v $(pwd)/tests/fixtures:/data \
  -v $(pwd)/outputs:/outputs \
  -e GENOTYPE_FILE=/data/test_genotype.hmp.txt \
  -e PHENOTYPE_FILE=/data/test_phenotype.txt \
  -e TRAIT_INDEX=2 \
  gapit3-gwas-pipeline:latest run-single-trait --dry-run
```

**Expected output**: Command that would be executed (no actual GWAS run)

### Test 4: Environment Configuration

```bash
docker run --rm \
  -e MODELS=BLINK \
  -e PCA_COMPONENTS=5 \
  -e OPENBLAS_NUM_THREADS=12 \
  gapit3-gwas-pipeline:latest bash -c 'env | grep -E "MODELS|PCA|OPENBLAS"'
```

**Expected output**: Environment variables set correctly

## Windows Users (PowerShell)

Replace `$(pwd)` with `${PWD}`:

```powershell
docker run --rm -v ${PWD}/tests/fixtures:/data gapit3-gwas-pipeline:latest validate
```

## Automated Test Script

Create a test script `scripts/test-docker-functional.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

IMAGE="gapit3-gwas-pipeline:latest"
FIXTURE_DIR="$(pwd)/tests/fixtures"

echo "Running Docker functional tests..."

echo "✓ Test 1: Validation"
docker run --rm -v "$FIXTURE_DIR:/data" "$IMAGE" validate

echo "✓ Test 2: Trait extraction"
docker run --rm -v "$FIXTURE_DIR:/data" "$IMAGE" extract-traits

echo "✓ Test 3: Environment vars"
docker run --rm -e OPENBLAS_NUM_THREADS=8 "$IMAGE" bash -c 'test $OPENBLAS_NUM_THREADS -eq 8'

echo "✓ Test 4: Help text"
docker run --rm "$IMAGE" --help | grep -q "GAPIT3 GWAS Pipeline"

echo "All tests passed!"
```

## CI Integration

These tests run automatically in `.github/workflows/docker-build.yml` after each successful build.

## Troubleshooting

### Volume mount errors on Windows
Use absolute paths or ensure Docker Desktop has access to the drive.

### Test fixtures not found
Verify `tests/fixtures/` directory exists with test data files.

### Container exits immediately
Check logs: `docker logs <container-id>`

## Related Commands

- `/docker-build` - Build the image before testing
- `/test-r` - Run unit tests inside devcontainer