# ============================================================
# GWAS pipeline using GAPIT 3
# Author: Elohim Bello Bello
# Institution: Salk Institute for Biological Studies
# Description:
#   This script performs genome-wide association studies (GWAS)
#   in Arabidopsis thaliana using the GAPIT3 R package.
#
#   It imports phenotypic data (mean_median_root_length_day2.txt) and genotype data (acc_snps_filtered_maf_perl_edited_diploid.hmp.txt, ~1.37 million SNPs across 546 accessions), filters accessions, and executes GWAS using the BLINK model.
#   
#   Steps included:
#     1. Install and load GAPIT3 under R version 4.4.1.
#     2. Import and preprocess phenotype and genotype data.
#     3. Verify accession matching between phenotype and genotype matrices.
#     4. Perform GWAS using the FarmCPU model with three principal components.
#     5. Generate Manhattan and QQ plots for each analyzed trait.
# ============================================================

# --- Install CRAN dependencies ---
>install.packages(c(
  "devtools",       # For installing GAPIT3 directly from GitHub
  "data.table",     # Efficient handling of large data files
  "dplyr",          # Data manipulation (filter, select, join)
  "tidyr",          # Data reshaping and cleaning
  "ggplot2",        # Visualization (Manhattan and QQ plots)
  "readr",          # Fast import of CSV and text files
  "matrixStats",    # Optimized matrix operations for GWAS
  "gridExtra"       # Plot layout management for multi-panel plots
))

# Installating GAPIT3 from GitHub under R 4.4.1

> R.version.string
[1] "R version 4.4.1 (2024-06-14)"
> install.packages("devtools")
> devtools::install_github("jiabowang/GAPIT", force=TRUE)
> library(GAPIT)
> packageVersion("GAPIT")
[1] ‘3.5.0’

# Load packages

> library(GAPIT)
> library(data.table)
> library(dplyr)
> library(tidyr)
> library(ggplot2)
> library(readr)
> library(matrixStats)
> library(gridExtra)

# Importing phenotype data from a text file

> data <- read.table("iron_traits_edited.txt", head = TRUE) 
> head(data)
> length(data$Taxa)
> data_unique <- data[!duplicated(data$Taxa), ]
> head(data_unique)
> length(data_unique$Taxa)
> myY <- data_unique
> head(myY)

# Keep only rows in myY where Taxa is also present in data$Taxa

> data <- read.table("ids_gwas.txt", head = TRUE)
> head(data)
> myY <- myY[myY$Taxa %in% data$Taxa, ]
> head(myY)
> nrow(myY)

# Importing genotype data (hapmap file)

> myG <- read.table("acc_snps_filtered_maf_perl_edited_diploid.hmp.txt", head = FALSE)

# Inspect the structure of the hapmap format
# First 11 columns = metadata, rest = genotypes

> head(myG[1:16])

# Count the total number of SNPs (rows excluding the header)

> num_snps <- nrow(myG) - 1
> cat("Number of SNPs:", num_snps, "\n")
 
# Check the total number of accessions

> num_acc <- ncol(myG) - 11
> num_acc

# Running GWAS using GAPIT
# GAPIT function call with detailed parameters in gapit_help_document.pdf

> library(GAPIT)
> myGAPIT <- GAPIT(
  Y = myY[, c(1, 2:187)],  # Include ID (column 1) + all phenotype columns (2–187)
  G = myG,                 # Genotype matrix
  PCA.total = 3,           # Number of principal components to use
  model = c("BLINK", "FarmCPU"),  # GWAS models to run
  Multiple_analysis = TRUE # Perform multiple analyses automatically
)

Messages at the end of the gwas run

[1] "GAPIT.ID accomplished successfully for multiple traits. Results are saved"
[1] "GAPIT accomplished successfully for multiple traits. Result are saved"
[1] "GAPIT.Association.Manhattans has done !!!"
[1] "GAPIT has output Multiple Manhattan figure with Symphysic type!!!"
[1] "GAPIT has done all analysis!!!"
[1] "Please find your all results in :"
[1] "/Users/elohimbellobello/Desktop/iron_gwas.gz"
Warning message:
In plot.formula(1 ~ 1, col = "white", xlab = "", ylab = "", ylim = c(0,  :
  the formula '1 ~ 1' is treated as '1 ~ 1'