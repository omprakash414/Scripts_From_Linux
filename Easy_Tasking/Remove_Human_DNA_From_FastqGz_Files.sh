#!/bin/bash

# Check if the correct number of arguments is provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <input_file.txt> <bowtie2_index>"
    exit 1
fi

# Input file containing forward, reverse reads, and sample names
input_file=$1
bowtie2_index=$2  # Path to Bowtie2 human genome index

# Create output directories
mkdir -p SAM_files BAM_files Filtered_files

# Loop through each line in the input file
while IFS=$'\t' read -r forward reverse sample; do
    echo "Processing sample: $sample"

    # Run Bowtie2 alignment
    bowtie2 -x "$bowtie2_index" -1 "$forward" -2 "$reverse" --very-sensitive -p 28 -S "SAM_files/${sample}.sam"
    echo "Bowtie2 alignment done"
    # Convert SAM to BAM
    samtools view -bS "SAM_files/${sample}.sam" > "BAM_files/${sample}.bam"
    echo
    
    # Filter out human reads (keep only unmapped reads)
    samtools view -b -f 12 -F 256 "BAM_files/${sample}.bam" > "BAM_files/${sample}_non_human.bam"
# Use -f 12 if you're strictly interested in fully unmapped pairs (neither read aligned).
# Use -f 4 if you're OK with partially mapped pairs (e.g., mate mapped but read isn't) or working with single-end data.
# -F 256 ensures that we exclude secondary alignments
    
    echo "Filtered out human reads"
    # Convert BAM back to FASTQ (Non-human reads)
    samtools fastq -1 "Filtered_files/${sample}_R1_clean.fastq" -2 "Filtered_files/${sample}_R2_clean.fastq" "BAM_files/${sample}_non_human.bam"
    echo "Converted BAM to FASTQ"
    echo "Finished processing $sample"
    # Remove intermediate files
    rm "SAM_files/${sample}.sam" "BAM_files/${sample}.bam" "BAM_files/${sample}_non_human.bam"
    echo "Removed intermediate files"

done < "$input_file"

echo "All samples processed. Filtered reads are in 'Filtered_files/'"
