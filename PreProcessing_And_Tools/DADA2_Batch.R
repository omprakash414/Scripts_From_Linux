#!/usr/bin/env Rscript

# Load required library
#!/usr/bin/env Rscript

# Set CRAN mirror to India (Bhubaneswar)
# options(repos = c(CRAN = "https://mirror.niser.ac.in/"))

# Ensure BiocManager is installed
#if (!requireNamespace("BiocManager", quietly = TRUE)) {
#  install.packages("BiocManager", ask = FALSE)
#}

# Ensure dada2 is installed
#if (!requireNamespace("dada2", quietly = TRUE)) {
#  BiocManager::install("dada2", ask = FALSE, update = TRUE)
#}
cat("+++++++++++ ===========  loading dada2 library  =========== +++++++++++","\n")
library(dada2)

# Read command-line arguments
args <- commandArgs(trailingOnly = TRUE)

if (length(args) < 3) {
  stop("Usage: Rscript dada2_pipeline.R <data_directory> <forward_pattern> <reverse_pattern>")
}

data_dir <- args[1]
forward_pattern <- args[2]
reverse_pattern <- args[3]

# Set working directory
setwd(data_dir)
cat(paste0("+++++++++++ =========== Directory: ",data_dir,"  =========== +++++++++++"), "\n")
# List and filter files
fnFs <- list.files(data_dir, pattern = forward_pattern, full.names = TRUE)
fnRs <- list.files(data_dir, pattern = reverse_pattern, full.names = TRUE)

# Extract sample names
sample_names <- gsub(paste0(forward_pattern, "|", reverse_pattern), "", basename(c(fnFs, fnRs)))
sample_names <- unique(sample_names)

# Create filtered output file paths
filt_path <- file.path(data_dir, "filtered")
dir.create(filt_path, showWarnings = FALSE)
cat(paste0("+++++++++++ =========== Created Output Directory: ",filt_path,"  =========== +++++++++++"), "\n")

filtFs <- file.path(filt_path, paste0(sample_names, "_F_filt.fastq.gz"))
filtRs <- file.path(filt_path, paste0(sample_names, "_R_filt.fastq.gz"))

names(filtFs) <- sample_names
names(filtRs) <- sample_names
cat("+++++++++++ =========== Filtering and Trimming  =========== +++++++++++", "\n")
# Filter and trim
out <- filterAndTrim(fnFs, filtFs, fnRs, filtRs, compress=TRUE, multithread=TRUE)

cat("+++++++++++ =========== Learning Error Rates  =========== +++++++++++", "\n")
# Learn error rates
errF <- learnErrors(filtFs, multithread=TRUE)
errR <- learnErrors(filtRs, multithread=TRUE)

# Infer samples
dadaFs <- dada(filtFs, err=errF, multithread=TRUE)
dadaRs <- dada(filtRs, err=errR, multithread=TRUE)
cat("+++++++++++ =========== Merging Paired Reads  =========== +++++++++++", "\n")
# Merge paired reads
mergers <- mergePairs(dadaFs, filtFs, dadaRs, filtRs, verbose=TRUE)

cat("+++++++++++ =========== Creating ASV Table  =========== +++++++++++", "\n")
# Create ASV table
seqtab <- makeSequenceTable(mergers)

# Save R data
save_image_path <- file.path(data_dir, "overall_datasets_ASVs.RData")
save.image(save_image_path)

# Export FASTA
seq_list <- colnames(seqtab)
fasta_file_path <- file.path(data_dir, "overall_datasets_ASVs.fasta")

cat(paste0("+++++++++++ =========== Exporting FASTA file of ASVs: ",fasta_file_path,"  =========== +++++++++++"), "\n")

fasta_lines <- sapply(seq_along(seq_list), function(i) {
  paste0(">ASV", i, "\n", seq_list[i])
})

writeLines(fasta_lines, fasta_file_path)

cat("Pipeline complete. ASV table and FASTA exported.\n")
