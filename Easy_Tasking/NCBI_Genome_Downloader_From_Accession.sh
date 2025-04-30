#!/bin/bash

# Check if a file was provided as an argument
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <accession_numbers.txt>"
    exit 1
fi

# Get the file from the argument
ACCESSION_FILE="$1"

# Check if the file exists
if [ ! -f "$ACCESSION_FILE" ]; then
    echo "Error: File '$ACCESSION_FILE' not found."
    exit 1
fi

# Save the current working directory
SCRIPT_DIR=$(pwd)

# Loop over each line in the file
while IFS= read -r accession_number; do
    # Trim whitespace or hidden characters
    accession_number=$(echo "$accession_number" | tr -d '\r' | xargs)

    # Skip empty lines
    if [ -z "$accession_number" ]; then
        continue
    fi

    # Set the filename with .zip extension
    output_filename="${accession_number}.zip"

    # Download the genome for the current accession number with the --filename option
    echo "Downloading genome for accession number: $accession_number"
    datasets download genome accession "$accession_number" --filename "$output_filename"

    # Check if the command was successful
    if [ $? -ne 0 ]; then
        echo "Failed to download genome for accession number: $accession_number"
        continue
    fi

    # Unzip the downloaded file
    echo "Unzipping $output_filename"
    unzip -q "$output_filename" -d "${accession_number}_unzipped"

    # Navigate to the .fna file
    fna_file_path=$(find "${accession_number}_unzipped" -type f -name "*.fna" | head -n 1)

    if [ -z "$fna_file_path" ]; then
        echo "No .fna file found for accession number: $accession_number"
    else
        # Move the .fna file to the original script directory
        echo "Moving $fna_file_path to $SCRIPT_DIR"
        mv "$fna_file_path" "$SCRIPT_DIR"
    fi

    # Clean up: remove the unzipped directory
    rm -rf "${accession_number}_unzipped"

    # Optionally, remove the zip file if not needed
    rm "$output_filename"
done < "$ACCESSION_FILE"

echo "Processing completed."
