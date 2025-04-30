#!/bin/bash

# Function to display help
show_help() {
    echo "Usage: $0 <directory>"
    echo ""
    echo "This script processes a directory with SAM files and generates consensus markers and clades information:"
    echo ""
    echo "1. **Generate Consensus Marker**: The script uses `sample2markers.py` to generate consensus markers from SAM files."
    echo "2. **Print Clades**: It runs `strainphlan` to print clades from the consensus markers."
    echo "3. **Extract Clades Information**: It extracts clades information from the `print_clades_only.tsv` file and creates `clades.txt`."
    echo "4. **Extract Markers for Each Clade**: Finally, it extracts markers for each clade and processes them using `strainphlan`."
    echo ""
    echo "If 'clades.txt' already exists, the script will skip steps 2 and 3 and proceed directly to step 4."
    echo ""
    echo "Arguments:"
    echo "  <directory>  Path to the directory containing SAM files and other necessary files."
    echo ""
    echo "Examples:"
    echo "  $0 /path/to/directory"
    echo ""
    echo "Options:"
    echo "  -h, --help   Show this help message and exit"
}

# Check for help option
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_help
    exit 0
fi

# Check if one directory argument is provided
if [ $# -ne 1 ]; then
    echo "Usage: $0 <directory>"
    exit 1
fi

# Assign the directory argument to a variable
input_dir="$1"

# Change to the input directory
cd "$input_dir" || { echo "Error: Unable to access directory $input_dir"; exit 1; }

# Function to process a directory
process_directory() {
    local consensus_marker_dir

    # Step 2: Generate consensus marker
    consensus_marker_dir="consensus_marker"
    mkdir -p "$consensus_marker_dir"
    sample2markers.py -i "sams"/*.sam.bz2 -o "$consensus_marker_dir" -n 20

    # Step 3: Print clades for further process
    strainphlan -s "$consensus_marker_dir"/*.json.bz2 -o "$consensus_marker_dir" --print_clades_only --marker_in_n_samples_perc 10

    # Extracting clades info from text file
    tail -n +2 "$consensus_marker_dir/print_clades_only.tsv" | cut -f1 > "$consensus_marker_dir/clades.txt"

    echo "$consensus_marker_dir/clades.txt"
}

# Check if clades.txt exists
if [ -f "consensus_marker/clades.txt" ]; then
    echo "Using existing clades.txt file."
    clades_file="consensus_marker/clades.txt"
else
    # Process the directory to generate clades.txt
    clades_file=$(process_directory)

    # Check if clades_file is created successfully
    if [ ! -f "$clades_file" ]; then
        echo "Error: clades_file not created."
        exit 1
    fi
fi

# Assign the clades file
common_clades_file="$clades_file"

# Step 4: Extract markers for each clade
db_marker_dir="db_marker"
output_dir="output"

mkdir -p "$db_marker_dir"
mkdir -p "$output_dir"

while IFS= read -r clade; do
    clade_marker_file="$db_marker_dir/${clade}.fna"
    echo "Processing clade: $clade"
    echo "Marker file path: $clade_marker_file"

    if [ ${#clade_marker_file} -ge 255 ]; then
        echo "Error: File path too long: $clade_marker_file"
        exit 1
    fi

    extract_markers.py -c "$clade" -o "$db_marker_dir"
    strainphlan -s "consensus_marker"/*.json.bz2 -m "$clade_marker_file" --marker_in_n_samples_perc 10 -o "$output_dir" -n 25 -c "$clade" --mutation_rates
done < "$common_clades_file"
