#!/bin/bash

# Function to display help message
show_help() {
    echo "Usage: bash GRID_Script.sh <mode> <input_file> <grid_db_path> [<num_threads>]"
    echo ""
    echo "Arguments:"
    echo "  <mode>          'paired' or 'single' (required)"
    echo "  <input_file>    Input file with sample info (required)"
    echo "  <grid_db_path>  Path to GRID DB directory (required)"
    echo "  <num_threads>   Number of threads (optional, default: 16)"
    echo ""
    echo "Examples:"
    echo "  bash GRID_Script.sh paired paired_samples.txt /path/to/db 20"
    echo "  bash GRID_Script.sh single single_samples.txt /path/to/db"
    echo ""
    echo "Input file format:"
    echo "  Paired: <read1.fastq.gz> <tab> <read2.fastq.gz>"
    echo "  Single: <read.fastq.gz> : <ignored_field>"
}

# Default value
num_threads=16

# Check argument count
if [[ $# -lt 3 ]]; then
    echo "Error: Mode, input file, and GRID DB path are required."
    show_help
    exit 1
fi

# Assign variables
mode="$1"
input_file="$2"
grid_db="$3"
if [[ $# -ge 4 ]]; then
    num_threads="$4"
fi

# Validate input
if [[ ! -f "$input_file" ]]; then
    echo "Error: Input file '$input_file' not found."
    exit 1
fi

if [[ ! -d "$grid_db" ]]; then
    echo "Error: GRID DB path '$grid_db' not found."
    exit 1
fi

echo "Mode        : $mode"
echo "Input File  : $input_file"
echo "GRID DB     : $grid_db"
echo "Threads     : $num_threads"
echo ""

# --- Paired-end ---
if [[ "$mode" == "paired" ]]; then

    while IFS=$'\t' read -r read_one read_two; do
        base_name=$(basename "$read_one" | cut -d'_' -f1)
        echo "Processing paired sample: $base_name"

        output_dir="$base_name"
        mkdir -p "$output_dir"

        pigz -dc --fast -p "$num_threads" "$read_one" "$read_two" > "$base_name.fastq"
        echo "Decompressed: $base_name"

        grid multiplex -r . -e fastq -o "$output_dir" -d "$grid_db" -c 0.2 -n "$num_threads"

        rm "$base_name.fastq"
        echo "Finished sample: $base_name"
        echo ""

    done < "$input_file"

# --- Single-end ---
elif [[ "$mode" == "single" ]]; then

    while IFS=':' read -r read_file _; do
        read_file=$(echo "$read_file" | xargs)
        base_name=$(basename "$read_file" | cut -d'_' -f1)

        echo "Processing single sample: $base_name"

        output_dir="$base_name"
        mkdir -p "$output_dir"

        pigz -dc --fast -p "$num_threads" "$read_file" > "$base_name.fastq"

        grid multiplex -r . -e fastq -o "$output_dir" -d "$grid_db" -p -n "$num_threads"

        rm "$base_name.fastq"
        echo "Finished sample: $base_name"
        echo ""

    done < "$input_file"

else
    echo "Error: Invalid mode '$mode'. Must be 'paired' or 'single'."
    show_help
    exit 1
fi
