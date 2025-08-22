#!/usr/bin/env Rscript

# -------------------------
# Command-line interface
# -------------------------
args <- commandArgs(trailingOnly = TRUE)

show_help <- function() {
  cat("
Usage:
  Rscript grid_pipeline.R <path_to_parent_folder> [--prefix <name>]
  Rscript grid_pipeline.R -h
  Rscript grid_pipeline.R --help

Steps performed:
  1) Recursively finds all files matching '*.GRiD.txt' under <path_to_parent_folder>.
  2) Treats the immediate parent directory of each file as the Sample ID.
  3) Imports and combines all GRiD outputs into 'combined_df'.
  4) Filters 'combined_df' to rows where GRiD > 1 (growing species).
  5) Builds three matrices (list 'GRiD_Result_for_Plots') with rows = samples and columns = species:
       - $GRiD
       - $Species_heterogeneity
       - $Coverage
  6) Saves an RData bundle and exports the three matrices as .txt (tab-delimited).

Inputs:
  <path_to_parent_folder> : Parent folder containing sample subfolders with '*.GRiD.txt'.

Options:
  --prefix <name> : Filename prefix for outputs (default: GRiD_results)

Outputs (saved in the same directory as <path_to_parent_folder>):
  - <prefix>.RData
  - <prefix>__GRiD.txt
  - <prefix>__Species_heterogeneity.txt
  - <prefix>__Coverage.txt

Example:
  Rscript grid_pipeline.R /home/data/GRiD --prefix CohortA
\n")
}

# -------------------------
# Parse arguments
# -------------------------
if (length(args) == 0 || any(args %in% c("-h", "--help"))) {
  show_help()
  if (length(args) == 0) quit(status = 1) else quit(status = 0)
}

path   <- NULL
prefix <- "GRiD_results"

i <- 1
while (i <= length(args)) {
  a <- args[i]
  if (a %in% c("-h", "--help")) {
    show_help(); quit(status = 0)
  } else if (a == "--prefix") {
    if (i == length(args)) stop("--prefix requires a value")
    i <- i + 1; prefix <- args[i]
  } else if (is.null(path)) {
    path <- a
  }
  i <- i + 1
}

if (is.null(path) || !dir.exists(path)) {
  stop(sprintf("Path does not exist or not provided: %s", ifelse(is.null(path), "<missing>", path)))
}

outdir <- path   # outputs always go to input dir

# -------------------------
# Functions (unchanged)
# -------------------------
import_grid_data <- function(path) {
  files <- list.files(path, pattern = "\\.GRiD\\.txt$", full.names = TRUE, recursive = TRUE)
  if (length(files) == 0) stop("No GRiD output files found in the given path.")
  sample_ids <- basename(dirname(files))
  all_data <- list()
  for (i in seq_along(files)) {
    dat <- read.table(files[i], header = TRUE, sep = "\t", stringsAsFactors = FALSE)
    dat$Sample <- sample_ids[i]
    all_data[[i]] <- dat
  }
  combined <- do.call(rbind, all_data)
  rownames(combined) <- NULL
  return(combined)
}

data_for_heatmap <- function(df){
  sample_ids <- unique(df$Sample)
  genomes <- unique(df$Genome)
  df1 <- data.frame(matrix(NA, length(sample_ids), length(genomes)))
  rownames(df1) <- sample_ids
  colnames(df1) <- genomes
  df2 <- df1; df3 <- df1
  for (s in sample_ids) {
    sub <- df[df$Sample == s, ]
    for (g in sub$Genome) {
      df1[s, g] <- sub[sub$Genome == g, "GRiD"]
      df2[s, g] <- sub[sub$Genome == g, "Species_heterogeneity"]
      df3[s, g] <- sub[sub$Genome == g, "Coverage"]
    }
  }
  return(list(GRiD = df1, Species_heterogeneity = df2, Coverage = df3))
}

# -------------------------
# Pipeline
# -------------------------
combined_df <- import_grid_data(path)
combined_df <- combined_df[which(combined_df$GRiD > 1), ]
GRiD_Result_for_Plots <- data_for_heatmap(combined_df)

# -------------------------
# Save outputs
# -------------------------
rdata_file <- file.path(outdir, paste0(prefix, ".RData"))
save(combined_df, GRiD_Result_for_Plots, file = rdata_file)

df1_out <- data.frame(Sample = rownames(GRiD_Result_for_Plots$GRiD),
                      GRiD_Result_for_Plots$GRiD,
                      check.names = FALSE, row.names = NULL)

df2_out <- data.frame(Sample = rownames(GRiD_Result_for_Plots$Species_heterogeneity),
                      GRiD_Result_for_Plots$Species_heterogeneity,
                      check.names = FALSE, row.names = NULL)

df3_out <- data.frame(Sample = rownames(GRiD_Result_for_Plots$Coverage),
                      GRiD_Result_for_Plots$Coverage,
                      check.names = FALSE, row.names = NULL)

write.table(df1_out, file.path(outdir, paste0(prefix, "__GRiD.txt")),
            sep = "\t", quote = FALSE, row.names = FALSE)
write.table(df2_out, file.path(outdir, paste0(prefix, "__Species_heterogeneity.txt")),
            sep = "\t", quote = FALSE, row.names = FALSE)
write.table(df3_out, file.path(outdir, paste0(prefix, "__Coverage.txt")),
            sep = "\t", quote = FALSE, row.names = FALSE)
write.table(combined_df,
            file.path(outdir, paste0(prefix, "__combined_df.txt")),
            sep = "\t", quote = FALSE, row.names = FALSE)

cat(sprintf("\nSaved outputs in %s:\n  - %s\n  - %s\n  - %s\n  - %s\n\n",
            outdir,
            paste0(prefix, ".RData"),
            paste0(prefix, "__GRiD.txt"),
            paste0(prefix, "__Species_heterogeneity.txt"),
            paste0(prefix, "__Coverage.txt")))
