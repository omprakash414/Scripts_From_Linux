#!/bin/bash

# Function to display help message
function display_help() {
    echo "Usage: $0 <source_folder> <mapping_file>"
    echo
    echo "This script copies and renames .fastq.gz files based on a mapping file."
    echo
    echo "Arguments:"
    echo "  source_folder   The folder containing the original .fastq.gz files."
    echo "  mapping_file    The tab-delimited text file with new and old base names."
    echo
    echo "Mapping file format:"
    echo "  The mapping file should have two columns separated by tabs:"
    echo "    1st column - New base name for the files"
    echo "    2nd column - Current base name of the files"
    echo
    echo "Example:"
    echo "  $0 /path/to/source_folder mapping.txt"
    echo
    echo "Options:"
    echo "  -h    Show this help message and exit"
}

# Check for the help flag or incorrect number of arguments
if [[ "$1" == "-h" || "$#" -ne 2 ]]; then
    display_help
    exit 1
fi

# Define input variables
source_folder="$1"
input_file="$2"
destination_folder="Modified_files"

# Check if the source folder exists
if [[ ! -d "$source_folder" ]]; then
    echo "Error: Source folder '$source_folder' does not exist."
    exit 1
fi

# Check if the input file exists
if [[ ! -f "$input_file" ]]; then
    echo "Error: Mapping file '$input_file' does not exist."
    exit 1
fi

# Create the destination folder if it doesn't exist
mkdir -p "$destination_folder"

# Loop through each line in the mapping file
while IFS=$'\t' read -r new_base_name old_base_name; do
    # Define the filenames for both files (.1.fastq.gz and .2.fastq.gz)
    old_file_1="${source_folder}/${old_base_name}.1.fastq.gz"
    old_file_2="${source_folder}/${old_base_name}.2.fastq.gz"
    new_file_1="${destination_folder}/${new_base_name}.1.fastq.gz"
    new_file_2="${destination_folder}/${new_base_name}.2.fastq.gz"

    # Check if the old files exist before copying
    if [[ -f "$old_file_1" && -f "$old_file_2" ]]; then
        # Copy and rename the files
        cp "$old_file_1" "$new_file_1"
        cp "$old_file_2" "$new_file_2"
        echo "Copied $old_file_1 to $new_file_1 and $old_file_2 to $new_file_2"
    else
        echo "Warning: $old_base_name files not found in $source_folder"
    fi
done < "$input_file"
