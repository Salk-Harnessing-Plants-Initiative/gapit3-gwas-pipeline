# ==============================================================================
# GAPIT3 GWAS Pipeline - Production Container
# ==============================================================================
# Multi-stage build for optimized R environment with GAPIT3
# Base: rocker/r-ver with multi-threaded OpenBLAS for efficient linear algebra
# Author: Elizabeth (Salk HPI)
# ==============================================================================

FROM rocker/r-ver:4.4.1 AS base

# Set environment variables (build-time only - runtime config via ENV at container start)
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=America/Los_Angeles \
    R_LIBS_USER=/usr/local/lib/R/site-library

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Build essentials
    build-essential \
    gfortran \
    pkg-config \
    # OpenBLAS for fast linear algebra (critical for GAPIT)
    libopenblas-dev \
    liblapack-dev \
    # Git for devtools
    git \
    # System tools
    curl \
    wget \
    ca-certificates \
    # For data processing
    libxml2-dev \
    libssl-dev \
    libcurl4-openssl-dev \
    libfontconfig1-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    libfreetype6-dev \
    libpng-dev \
    libtiff5-dev \
    libjpeg-dev \
    libwebp-dev \
    # Cleanup
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install R packages in layers for better caching
# Layer 1: Core dependencies (changes rarely)
RUN R -e "install.packages(c( \
    'devtools', \
    'data.table', \
    'dplyr', \
    'tidyr', \
    'readr' \
    ), repos='https://cloud.r-project.org', Ncpus=4)"

# Layer 2: Visualization and utilities
RUN R -e "install.packages(c( \
    'ggplot2', \
    'gridExtra', \
    'matrixStats', \
    'optparse', \
    'jsonlite', \
    'logging', \
    'testthat' \
    ), repos='https://cloud.r-project.org', Ncpus=4)"

# Layer 3: GAPIT3 from GitHub (pinned version)
RUN R -e "library(devtools); install_github('jiabowang/GAPIT@master', force=TRUE)"

# Verify GAPIT installation and version
RUN R -e "library(GAPIT); cat('GAPIT version:', as.character(packageVersion('GAPIT')), '\n')"

# ==============================================================================
# Runtime stage
# ==============================================================================
FROM base AS runtime

# Create directory structure
RUN mkdir -p /data/genotype \
    /data/phenotype \
    /data/metadata \
    /outputs \
    /logs \
    /scripts

# Set working directory
WORKDIR /workspace

# Copy pipeline scripts
COPY scripts/ /scripts/

# Make scripts executable
RUN chmod +x /scripts/*.sh /scripts/*.R

# Set entrypoint (handles runtime configuration via environment variables)
ENTRYPOINT ["/scripts/entrypoint.sh"]

# Default command - run single trait analysis
CMD ["run-single-trait"]

# ==============================================================================
# Metadata
# ==============================================================================
LABEL org.opencontainers.image.title="GAPIT3 GWAS Pipeline" \
      org.opencontainers.image.description="Parallelized GWAS analysis using GAPIT3 for Arabidopsis thaliana" \
      org.opencontainers.image.authors="Salk Harnessing Plants Initiative" \
      org.opencontainers.image.source="https://github.com/Salk-Harnessing-Plants-Initiative/gapit3-gwas-pipeline" \
      org.opencontainers.image.version="1.0.0" \
      org.opencontainers.image.vendor="Salk Institute" \
      r.version="4.4.1" \
      gapit.version="3.5.0"
