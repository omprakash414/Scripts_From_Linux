#!/bin/bash
set -x
# Function to display help message
show_help() {
    echo "Usage: $0 <input_file> <mode> [<num_threads>]"
    echo ""
    echo "Options:"
    echo "  <input_file>   Path to the input file containing sample information (required)"
    echo "  <mode>         Analysis mode: 'paired' or 'single' (required)"
    echo "  <num_threads>  Number of threads for RGI (optional, default: 16)"
    echo ""
    echo "Description:"
    echo "This script processes FASTQ files listed in the input file. It supports both paired-end and single-end reads."
    echo "For paired-end mode, each line in the input file should have two columns:"
    echo "  <read_one> <tab> <read_two>"
    echo "For single-end mode, each line in the input file should have one column:"
    echo "  <read_one>"
    echo ""
    echo "Example usage:"
    echo "  $0 samples_paired.txt paired 20"
    echo "  $0 samples_single.txt single 20"
}

# Default values
num_threads=16
input_file=""
mode=""

# Parse the input arguments
if [[ $# -lt 2 ]]; then
    echo "Error: Input file and mode are required."
    show_help
    exit 1
fi

input_file="$1"
mode="$2"

# Check if the number of threads is provided (optional)
if [[ $# -ge 3 ]]; then
    num_threads="$3"
fi

# Validate the mode
if [[ "$mode" != "paired" && "$mode" != "single" ]]; then
    echo "Error: Mode must be 'paired' or 'single'."
    show_help
    exit 1
fi

# Check if input file exists
if [[ ! -f "$input_file" ]]; then
    echo "Error: Input file '$input_file' does not exist."
    exit 1
fi

# Processing for paired-end mode
if [[ "$mode" == "paired" ]]; then
    while IFS=$'\t' read -r read_one read_two; do
        # Ensure two columns are present for paired-end mode
        if [[ -z "$read_two" ]]; then
            echo "Error: Paired-end mode requires two columns in the input file. Missing second file for sample: $read_one"
            exit 1
        fi

        start_time=$(date +"%Y-%m-%d %H:%M:%S")
        echo "[$start_time] Starting processing single-end sample: $base_name"

        # Extract base name (e.g., ERR1297555) from read_one file
        base_name=$(basename "$read_one" | sed 's/\.fastq.*$//' | sed 's/_.*$//')

        # Create output directory for this sample
        output_dir="$base_name"
        mkdir -p "$output_dir"

        echo "Processing paired-end sample: $base_name"
        rgi bwt --read_one "$read_one" --read_two "$read_two" --output_file "$output_dir/${base_name}" -n "$num_threads" --clean

        # Clean up temporary files (e.g., BAM files) in the output directory
        rm -f "$output_dir"/*.bam
        echo "Processed paired-end sample: $base_name"

        # Print end timestamp
        end_time=$(date +"%Y-%m-%d %H:%M:%S")
        echo "[$end_time] Finished processing single-end sample: $base_name"

    done < "$input_file"

# Processing for single-end mode
elif [[ "$mode" == "single" ]]; then
    while IFS=$'\t' read -r read_one; do

        start_time=$(date +"%Y-%m-%d %H:%M:%S")
        echo "[$start_time] Starting processing single-end sample: $base_name"
        
        # Extract base name (e.g., ERR1297555) from read_one file
        base_name=$(basename "$read_one" | sed 's/\.fastq.*$//' | sed 's/_.*$//')

        # Create output directory for this sample
        output_dir="$base_name"
        mkdir -p "$output_dir"

        echo "Processing single-end sample: $base_name"
        rgi bwt --read_one "$read_one" --output_file "$output_dir/${base_name}" -n "$num_threads" --clean

        # Clean up temporary files (e.g., BAM files) in the output directory
        rm -f "$output_dir"/*.bam
        echo "Processed single-end sample: $base_name"

        # Print end timestamp
        end_time=$(date +"%Y-%m-%d %H:%M:%S")
        echo "[$end_time] Finished processing single-end sample: $base_name"

    done < "$input_file"
fi
