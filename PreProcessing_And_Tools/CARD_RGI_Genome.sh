#!/bin/bash

# Check if the user has provided the mapping file
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 mapping_file.txt"
    echo "Please provide a mapping file with input and output file names."
    exit 1
fi

# Read the mapping file
mapping_file="$1"

# Check if the file exists
if [ ! -f "$mapping_file" ]; then
    echo "Mapping file $mapping_file not found!"
    exit 1
fi

# Loop through each line in the mapping file
while IFS=$'\t' read -r input_file output_file; do
    # Skip empty lines or lines starting with #
    if [[ -z "$input_file" || "$input_file" == \#* ]]; then
        continue
    fi

    # Run the rgi command
    echo "Processing file: $input_file"
    rgi main -i "$input_file" -o "$output_file" -t contig -a DIAMOND -n 20 -g PRODIGAL --split_prodigal_jobs --clean

    # Check if the command was successful
    if [ $? -eq 0 ]; then
        echo "Successfully processed: $input_file"
    else
        echo "Error processing: $input_file"
    fi
done < "$mapping_file"
