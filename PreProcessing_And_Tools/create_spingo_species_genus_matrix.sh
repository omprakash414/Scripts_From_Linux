#!/bin/bash

# Check if the user has provided the directory path
if [ $# -ne 1 ]; then
    echo "Usage: $0 <directory_path>"
    exit 1
fi

# Get the directory path from the user's input
BASE_DIR=$1

# Check if the provided path exists and is a directory
if [ ! -d "$BASE_DIR" ]; then
    echo "Error: $BASE_DIR is not a valid directory."
    exit 1
fi

# Loop through all folders starting with PRJ in the specified directory
for PRJ_FOLDER in "$BASE_DIR"/PRJ*; do
    if [ -d "$PRJ_FOLDER" ]; then
        # Get the folder name (basename)
        FOLDER_NAME=$(basename "$PRJ_FOLDER")
        
        echo "Processing folder: $FOLDER_NAME"
        
        # Navigate into the folder
        cd "$PRJ_FOLDER" || { echo "Failed to enter folder $PRJ_FOLDER"; continue; }
        
        # Execute the commands
        ls *.spingo.out.txt > all_spingo.txt
        perl ~/spingo/create_genus_matrix.pl all_spingo.txt > "${FOLDER_NAME}_genus_matrix.txt"
        
        # Navigate back to the base directory
        cd "$BASE_DIR" || { echo "Failed to return to base directory"; exit 1; }
    fi
done

echo "Processing completed for all PRJ folders in $BASE_DIR!"
