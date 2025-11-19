# Build Docker Image

Build the GAPIT3 GWAS pipeline Docker image for local testing or deployment.

## Command

```bash
docker build -t gapit3-gwas-pipeline:latest .
```

## With Custom Tag

```bash
docker build -t gapit3-gwas-pipeline:v1.0.0 -t gapit3-gwas-pipeline:latest .
```

## Description

Builds a Docker image containing:
- R 4.4.1 runtime
- GAPIT3 package from GitHub
- All R dependencies (data.table, ggplot2, etc.)
- OpenBLAS for optimized linear algebra
- Pipeline scripts and configuration

The Dockerfile uses multi-stage builds with layer caching for faster subsequent builds.

## Build Time

- **First build**: ~15-20 minutes (downloads and compiles R packages)
- **Subsequent builds**: ~2-5 minutes (uses layer cache)

## Build Arguments

```bash
# Specify R version
docker build --build-arg R_VERSION=4.4.1 -t gapit3-gwas-pipeline:latest .

# Specify number of CPU cores for compilation
docker build --build-arg NCPUS=8 -t gapit3-gwas-pipeline:latest .
```

## Verify Build

After building, verify the image works:

```bash
docker run --rm gapit3-gwas-pipeline:latest --version
```

Expected output: R version and GAPIT3 information

## Check Image Size

```bash
docker images gapit3-gwas-pipeline
```

Expected size: ~2-3 GB

## Build for GitHub Container Registry

```bash
docker build -t ghcr.io/salk-harnessing-plants-initiative/gapit3-gwas-pipeline:latest .
```

## Troubleshooting

### Build fails during R package installation
- Check internet connection (downloads from CRAN/GitHub)
- Increase Docker memory allocation (recommend 8GB+)
- Try building with `--no-cache` to force fresh install

### Out of disk space
```bash
# Clean up old images and build cache
docker system prune -a
```

## CI Integration

Docker images are built automatically in GitHub Actions via `.github/workflows/docker-build.yml` on:
- Changes to `Dockerfile`
- Changes to `scripts/**`
- Changes to `config/**`

## Related Commands

- `/docker-test` - Run functional tests in Docker container
- `/validate-bash` - Validate scripts before building