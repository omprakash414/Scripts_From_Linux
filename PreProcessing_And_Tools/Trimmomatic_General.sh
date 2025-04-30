#!/bin/bash

# Function to display help message
function display_help() {
    echo "Usage: $0 <mode> <Input_file_list.txt> <output_directory> <threads>"
    echo ""
    echo "Arguments:"
    echo "  mode              >>>     'single' or 'paired'"
    echo "  Input_file_list.txt >>>   A file with input reads:"
    echo "                               - single: one column (forward reads)"
    echo "                               - paired: two columns (forward and reverse reads)"
    echo "  output_directory  >>>     Directory to save output files"
    echo "  threads           >>>     Number of threads for Trimmomatic"
    echo ""
    echo "Example (single-end):"
    echo "  $0 single single_input.txt /path/to/output 8"
    echo ""
    echo "Example (paired-end):"
    echo "  $0 paired paired_input.txt /path/to/output 8"
    echo ""
    echo "To display this help message:"
    echo "  $0 -h"
    echo "  $0 --help"
}

# Check for help request
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    display_help
    exit 0
fi

# Validate arguments
if [[ $# -ne 4 ]]; then
    echo "Error: Incorrect number of arguments."
    display_help
    exit 1
fi

mode=$1
file_list=$2
output_dir=$3
threads=$4

mkdir -p "$output_dir"

# Trimmomatic parameters
phred="phred33"
trimlog_prefix="trimlog"
slidingwindow="SLIDINGWINDOW:5:27"
minlen="MINLEN:100"
avgqual="AVGQUAL:27"

# Run Trimmomatic for single-end reads
if [[ "$mode" == "single" ]]; then
    while IFS=$'\t' read -r forward_file; do
        forward_base=$(basename "$forward_file" .fastq.gz)
        forward_trimmed="$output_dir/${forward_base}.fastq.gz"
        trimlog="$output_dir/${trimlog_prefix}_${forward_base}.log.txt"

        trimmomatic SE -threads "$threads" -"$phred" \
            "$forward_file" \
            "$forward_trimmed" \
            -trimlog "$trimlog" \
            $slidingwindow $minlen $avgqual
    done < "$file_list"

# Run Trimmomatic for paired-end reads
elif [[ "$mode" == "paired" ]]; then
    while IFS=$'\t' read -r forward_file reverse_file; do
        forward_base=$(basename "$forward_file" .fastq.gz)
        reverse_base=$(basename "$reverse_file" .fastq.gz)

        forward_paired="$output_dir/${forward_base}_paired.fastq.gz"
        forward_unpaired="$output_dir/${forward_base}_unpaired.fastq.gz"
        reverse_paired="$output_dir/${reverse_base}_paired.fastq.gz"
        reverse_unpaired="$output_dir/${reverse_base}_unpaired.fastq.gz"
        trimlog="$output_dir/${trimlog_prefix}_${forward_base}.log.txt"

        trimmomatic PE -threads "$threads" -"$phred" \
            "$forward_file" "$reverse_file" \
            "$forward_paired" "$forward_unpaired" \
            "$reverse_paired" "$reverse_unpaired" \
            -trimlog "$trimlog" \
            $slidingwindow $minlen $avgqual
    done < "$file_list"

else
    echo "Error: Mode must be 'single' or 'paired'"
    display_help
    exit 1
fi

echo "Trimmomatic $mode-end processing completed."
