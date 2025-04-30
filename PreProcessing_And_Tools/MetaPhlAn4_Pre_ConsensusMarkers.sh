#!/bin/bash

# Function to display help
show_help() {
    echo "Usage: $0 <directory> [file_type]"
    echo ""
    echo "This script processes a directory with fastq files through a series of steps:"
    echo "1. Metaphlan for each file or pair of forward and reverse files"
    echo ""
    echo "Arguments:"
    echo "  <directory>  Path to the directory containing the fastq files."
    echo "  [file_type]  Type of files ('paired' or 'single'). If not provided, defaults to 'paired'."
    echo ""
    echo "Examples:"
    echo "  Process paired-end files: $0 /path/to/directory paired"
    echo "  Process single-end files: $0 /path/to/directory single"
    echo ""
    echo "Options:"
    echo "  -h, --help   Show this help message and exit"
}

# Check for help option
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_help
    exit 0
fi

# Check if directory argument is provided
if [ $# -lt 1 ]; then
    echo "Usage: $0 <directory> [file_type]"
    exit 1
fi

# Assign the directory argument to a variable
input_dir="$1"

# Assign file type argument if provided
file_type="${2:-paired}"

# Change to the input directory
cd "$input_dir" || { echo "Error: Unable to access directory $input_dir"; exit 1; }

# Function to process paired-end files
process_directory_paired() {
    echo "Processing paired-end files..."

    for file in *_1.fastq.gz; do
        if [ -e "$file" ]; then
            sample_name=$(basename "$file" _1.fastq.gz)
            merged_file="${sample_name}.fastq"
            zcat "${sample_name}_1.fastq.gz" "${sample_name}_2.fastq.gz" > "$merged_file"
            mkdir -p bowtie2 sams
            metaphlan "$merged_file" --input_type fastq -s "sams/${sample_name}.sam.bz2" --bowtie2out "bowtie2/${sample_name}.bowtie2.bz2" --nproc 20 -o "${sample_name}_profiled.txt"
            rm "$merged_file"
        fi
    done

    # Remove the bowtie2 folder after processing
    rm -rf bowtie2
}

# Function to process single-end files
process_directory_single() {
    echo "Processing single-end files..."

    for file in *.fastq.gz; do
        if [ -e "$file" ]; then
            sample_name=$(basename "$file" .fastq.gz)
            mkdir -p bowtie2 sams
            metaphlan "$file" --input_type fastq -s "sams/${sample_name}.sam.bz2" --bowtie2out "bowtie2/${sample_name}.bowtie2.bz2" --nproc 20 -o "${sample_name}_profiled.txt"
        fi
    done

    # Remove the bowtie2 folder after processing
    rm -rf bowtie2
}

# Run the appropriate processing function based on file type
if [ "$file_type" == "paired" ]; then
    process_directory_paired
elif [ "$file_type" == "single" ]; then
    process_directory_single
else
    echo "Invalid file type specified. Please enter 'paired' or 'single'."
    exit 1
fi
