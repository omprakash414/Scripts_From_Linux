#!/bin/bash

# Function to display help information
show_help() {
    echo "Usage: $0 <text_file_with_input_output_pairs> or $0 <input_file_(fastq.gz)> <output_file_(fastq.gz)>"
    echo
    echo "This script processes fastq.gz files to remove:"
    echo "1. Incomplete sequences (any sequence entry with less than 4 lines)."
    echo "2. Sequences where the length of the DNA sequence does not match the length of the quality score."
    echo
    echo "Options:"
    echo "  -h    Show this help message and exit"
    echo
    echo "Arguments:"
    echo "  <file_with_input_output_pairs>   A text file where each line contains an input and output file pair separated by a tab."
    echo "  <input_file> <output_file>       Process a single input file and save the result to the specified output file."
    echo
    echo "Example:"
    echo "  $0 input_output_list.txt"
    echo "  $0 input.fastq.gz output.fastq.gz"
}

# Function to process a single file
process_file() {
    local input_file=$1
    local output_file=$2
    local temp_output=$(mktemp)

    echo "Processing $input_file..."

    # Process the file to remove incomplete sequences and sequences with mismatched lengths
    zcat "$input_file" | awk '
    BEGIN { complete = 1 }
    NR % 4 == 1 { header = $0; complete = 0 }
    NR % 4 == 2 { seq = $0 }
    NR % 4 == 3 { plus = $0 }
    NR % 4 == 0 {
        qual = $0;
        complete = 1;
        if (length(seq) == length(qual)) {
            print header "\n" seq "\n" plus "\n" qual
        } else {
            print "Mismatched sequence and quality score lengths found and removed." > "/dev/stderr"
        }
    }
    END {
        if (!complete) {
            print "Incomplete sequence found and removed." > "/dev/stderr"
        }
    }
    ' > "$temp_output"

    # Compress the cleaned data
    gzip "$temp_output"

    # Move the cleaned compressed file to the output file
    mv "$temp_output.gz" "$output_file"

    echo "Finished processing $input_file, output saved to $output_file."
}

# Main script
if [[ $# -eq 1 && $1 == "-h" ]]; then
    show_help
    exit 0
fi

if [[ $# -eq 1 ]]; then
    # One argument: expecting a text file with input-output pairs
    input_list=$1

    if [[ -f $input_list ]]; then
        while IFS=$'\t' read -r input_file output_file; do
            if [[ -f $input_file ]]; then
                process_file "$input_file" "$output_file"
            else
                echo "Input file not found: $input_file"
            fi
        done < "$input_list"
    else
        echo "Input list file not found: $input_list"
        exit 1
    fi
elif [[ $# -eq 2 ]]; then
    # Two arguments: expecting input and output filenames
    input_file=$1
    output_file=$2

    if [[ -f $input_file ]]; then
        process_file "$input_file" "$output_file"
    else
        echo "Input file not found: $input_file"
        exit 1
    fi
else
    show_help
    exit 1
fi
