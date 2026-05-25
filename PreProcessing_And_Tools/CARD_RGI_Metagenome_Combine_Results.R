#!/usr/bin/env Rscript

# -------------------------
# Load Libraries
# -------------------------
suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  library(stringr)
})

# -------------------------
# Help Message
# -------------------------
help_message <- function() {
  cat("
CARD_RGI_Metagenome_Combine_Results.R - Summarize RGI output across multiple samples (allele & gene level)

USAGE:
  Rscript CARD_RGI_Metagenome_Combine_Results.R /path/to/parent_folder/

  or for help:
  Rscript CARD_RGI_Metagenome_Combine_Results.R -h
  Rscript CARD_RGI_Metagenome_Combine_Results.R --help

DESCRIPTION:
  This script recursively scans subfolders inside the specified parent folder.
  It looks for RGI output files ending with:
    - '.allele_mapping_data.txt'  → allele-level resistance genes
    - '.gene_mapping_data.txt'    → gene-level resistance genes

  It then:
    1. Combines all allele-level files and gene-level files
    2. Separates Drug.Class annotations (multiple entries per gene)
    3. Summarizes read counts per Drug Class and Donor_Group
    4. Creates raw and normalized abundance tables

OUTPUT:
  In the current working directory, the following files are generated:
    ✔ Allele_AntibioticsClass_Abundance.csv
    ✔ Allele_AntibioticsClass_Abundance_Normalized.csv
    ✔ Gene_AntibioticsClass_Abundance.csv
    ✔ Gene_AntibioticsClass_Abundance_Normalized.csv

NOTE:
  - Sample folders must contain the RGI output text files.
  - File names must follow the format: <SampleID>.allele_mapping_data.txt, etc.

")
  quit(status = 0)
}

# -------------------------
# Parse Arguments
# -------------------------
args <- commandArgs(trailingOnly = TRUE)

if (length(args) == 0 || args[1] %in% c("-h", "--help")) {
  help_message()
}

parent_path <- args[1]

if (!dir.exists(parent_path)) {
  stop("❌ Error: The provided path does not exist.\nUse -h for help.")
}

# -------------------------
# Functions
# -------------------------
read_rgi_file <- function(file_path, level = "allele") {
  df <- read.delim(file_path, stringsAsFactors = FALSE)
  donor_id <- basename(file_path) %>%
    str_replace(paste0("\\.", level, "_mapping_data\\.txt$"), "")
  df$Donor_Group <- donor_id
  return(df)
}

process_mapping_data <- function(df) {
  df_clean <- df %>%
    filter(!is.na(Drug.Class)) %>%
    separate_rows(Drug.Class, sep = ";\\s*") %>%
    group_by(Donor_Group, Drug.Class) %>%
    summarise(Abundance = sum(Completely.Mapped.Reads, na.rm = TRUE), .groups = "drop") %>%
    pivot_wider(names_from = Drug.Class, values_from = Abundance, values_fill = 0)

  df_matrix <- as.data.frame(df_clean)
  rownames(df_matrix) <- df_matrix$Donor_Group
  df_matrix$Donor_Group <- NULL

  df_matrix_norm <- df_matrix / rowSums(df_matrix)
  return(list(raw = df_matrix, normalized = df_matrix_norm))
}

# -------------------------
# Load and Combine Data
# -------------------------
sample_dirs <- list.dirs(path = parent_path, recursive = FALSE)

allele_data_list <- list()
gene_data_list <- list()

for (dir in sample_dirs) {
  allele_file <- list.files(path = dir, pattern = "\\.allele_mapping_data\\.txt$", full.names = TRUE)
  gene_file   <- list.files(path = dir, pattern = "\\.gene_mapping_data\\.txt$", full.names = TRUE)

  if (length(allele_file) > 0) {
    allele_data_list[[length(allele_data_list) + 1]] <- read_rgi_file(allele_file[1], level = "allele")
  }

  if (length(gene_file) > 0) {
    gene_data_list[[length(gene_data_list) + 1]] <- read_rgi_file(gene_file[1], level = "gene")
  }
}

if (length(allele_data_list) == 0) stop("❌ No allele-level files found.")
if (length(gene_data_list) == 0) stop("❌ No gene-level files found.")

all_allele_data <- bind_rows(allele_data_list)
all_gene_data   <- bind_rows(gene_data_list)

allele_processed <- process_mapping_data(all_allele_data)
gene_processed   <- process_mapping_data(all_gene_data)

# -------------------------
# Write Output
# -------------------------
write.csv(allele_processed$raw, file = "Allele_AntibioticsClass_Abundance.csv")
write.csv(allele_processed$normalized, file = "Allele_AntibioticsClass_Abundance_Normalized.csv")
write.csv(gene_processed$raw, file = "Gene_AntibioticsClass_Abundance.csv")
write.csv(gene_processed$normalized, file = "Gene_AntibioticsClass_Abundance_Normalized.csv")

cat("✅ RGI aggregation complete. Output files written to current directory.\n")
