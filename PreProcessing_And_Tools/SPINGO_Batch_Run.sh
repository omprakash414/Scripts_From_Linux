#!/bin/bash

set -e  # Exit if any command fails

# Function to display help message
show_help() {
    echo "Usage: $0 <directory_path> <single_or_paired> [forward_pattern] [reverse_pattern]"
    echo ""
    echo "This script processes metagenomic FASTQ files and converts them to FASTA,"
    echo "then runs Spingo for species identification."
    echo ""
    echo "Arguments:"
    echo "  -h                    Show this help message and exit."
    echo "  <directory_path>      Path to the folder containing FASTQ files."
    echo "  <single_or_paired>    Choose 'single' for single-end files or 'paired' for paired-end files."
    echo "  [forward_pattern]     Required if 'paired' is selected. Example: '_1.fastq.gz'"
    echo "  [reverse_pattern]     Required if 'paired' is selected. Example: '_2.fastq.gz'"
    echo "  [file_pattern]        Required if 'single' is selected. Example: '.fastq.gz'"
    echo ""
    echo "Example Usage:"
    echo "  bash $0 /storage/sakshi/Aftab single \".fastq.gz\""
    echo "  bash $0 /storage/sakshi/Aftab paired \"_1.fastq.gz\" \"_2.fastq.gz\""
    exit 0
}

# Check if -h is passed
if [ "$1" == "-h" ]; then
    show_help
fi

# Check if correct arguments are provided
if [ "$#" -lt 2 ]; then
    echo "Error: Missing arguments! Use -h for help."
    exit 1
fi

DIRECTORY="$1"
MODE="$2"  # "single" or "paired"

# Function to process a single-end sample
process_single() {
    local SE_FILE="$1"
    local sample=$(basename "$SE_FILE" "$SE_PATTERN")

    local fq="$sample.fastq"
    local fa="$sample.fasta"

    echo "Processing single-end sample: $sample"

    # Use pigz if available for faster decompression
    if command -v pigz &> /dev/null; then
        echo "Extracting fastq with pigz..."
        pigz -dc "$SE_FILE" > "$fq"
    else
        echo "Extracting fastq with zcat..."
        zcat "$SE_FILE" > "$fq"
    fi

    # Convert FASTQ to FASTA
    echo "Converting to fasta..."
    awk 'NR%4==1 {gsub("@",">",$0); print} NR%4==2 {print}' "$fq" > "$fa"

    echo "Running Spingo..."
    /home/omprakash/spingo/SPINGO-master/spingo -d /home/omprakash/spingo/SPINGO-master/database/RDP_11.2.species.fa -p 30 -i "$fa" > "$sample.spingo.out.txt"

    echo "Removing intermediate files..."
    rm -rf "$fa" "$fq"

    echo "✅ Completed processing for: $sample"
}

# Function to process a paired-end sample
process_paired() {
    local R1="$1"
    local R2="$2"
    local sample="$3"

    local fq="$sample.fastq"
    local fa="$sample.fasta"

    echo "Processing paired-end sample: $sample"

    # Use pigz if available for faster decompression
    if command -v pigz &> /dev/null; then
        echo "Merging fastq files with pigz..."
        pigz -dc "$R1" "$R2" > "$fq"
    else
        echo "Merging fastq files with zcat..."
        zcat "$R1" "$R2" > "$fq"
    fi

    # Convert FASTQ to FASTA
    echo "Converting to fasta..."
    awk 'NR%4==1 {gsub("@",">",$0); print} NR%4==2 {print}' "$fq" > "$fa"

    echo "Running Spingo..."
    /home/omprakash/spingo/SPINGO-master/spingo -d /home/omprakash/spingo/SPINGO-master/database/RDP_11.2.species.fa -p 30 -i "$fa" > "$sample.spingo.out.txt"

    echo "Removing intermediate files..."
    rm -rf "$fa" "$fq"

    echo "✅ Completed processing for: $sample"
}

# Processing based on the mode (single-end or paired-end)
if [ "$MODE" == "single" ]; then
    if [ "$#" -ne 3 ]; then
        echo "Error: For single-end, provide <directory_path> single <file_pattern>. Use -h for help."
        exit 1
    fi
    SE_PATTERN="$3"

    # Process all single-end files
    for SE_FILE in "$DIRECTORY"/*"$SE_PATTERN"; do
        echo "+++++++++ Processing single-end sample ++++++++: $SE_FILE"
        process_single "$SE_FILE"
    done

elif [ "$MODE" == "paired" ]; then
    if [ "$#" -ne 4 ]; then
        echo "Error: For paired-end, provide <directory_path> paired <forward_pattern> <reverse_pattern>. Use -h for help."
        exit 1
    fi
    FORWARD_PATTERN="$3"
    REVERSE_PATTERN="$4"

    # Process all paired-end files
    for R1 in "$DIRECTORY"/*"$FORWARD_PATTERN"; do
        sample=$(basename "$R1" "$FORWARD_PATTERN")
        R2="$DIRECTORY/${sample}${REVERSE_PATTERN}"

        echo "+++++++++ Processing paired-end sample ++++++++: $sample"
        if [ ! -f "$R2" ]; then
            echo "Skipping: Reverse read file missing for $sample"
            continue
        fi

        process_paired "$R1" "$R2" "$sample"
    done

else
    echo "Error: Invalid mode! Use 'single' or 'paired'. Use -h for help."
    exit 1
fi

echo "🎉 All files processed!"


# Send email notification after completion
send_email
