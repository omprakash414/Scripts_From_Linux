#!/bin/bash

# Function to display help
show_help() {
    echo "Usage: $0 <directory> <paired|single> [steps]"
    echo ""
    echo "This script processes a directory with fastq files (paired-end or single-end) through a series of steps:"
    echo "1. Metaphlan for each file or pair of forward and reverse files"
    echo "2. Generate consensus marker"
    echo "3. Print clades for further process"
    echo "4. Extract markers for each clade"
    echo ""
    echo "You can run all steps or specific steps by providing the corresponding step numbers."
    echo ""
    echo "Examples:"
    echo "  Run all steps: bash /home/username/strainphlan4_stepwise.sh /path/to/directory paired 1 2 3 4"
    echo "  Run specific steps: bash /home/username/strainphlan4_stepwise.sh /path/to/directory single 1 3"
    echo ""
    echo "Options:"
    echo "  -h, --help    Show this help message and exit"
}

# Check for help option
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_help
    exit 0
fi

# Check if directory and file type arguments are provided
if [ $# -lt 3 ]; then
    echo "Usage: $0 <directory> <paired|single> [steps]"
    exit 1
fi

# Assign the arguments to variables
input_dir="$1"
file_type="$2"
shift 2
steps=("$@")

# Change to the input directory
cd "$input_dir" || { echo "Error: Unable to access directory $input_dir"; exit 1; }

# Function to run metaphlan for paired-end files
step1_paired() {
    echo "Running Step 1 for paired-end files: Metaphlan for each pair of forward and reverse files"
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

# Function to run metaphlan for single-end files
step1_single() {
    echo "Running Step 1 for single-end files: Metaphlan for each file"
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

# Function to generate consensus marker
step2() {
    echo "Running Step 2: Generate consensus marker"
    consensus_marker_dir="consensus_marker"
    mkdir -p "$consensus_marker_dir"
    sample2markers.py -i "sams"/*.sam.bz2 -o "$consensus_marker_dir" -n 20
}

# Function to print clades for further process
step3() {
    echo "Running Step 3: Print clades for further process"
    consensus_marker_dir="consensus_marker"
    strainphlan -s "$consensus_marker_dir"/*.json.bz2 -o "$consensus_marker_dir" --print_clades_only --marker_in_n_samples_perc 10

    # Extracting clades info from text file
    tail -n +2 "$consensus_marker_dir/print_clades_only.tsv" | cut -f1 > "$consensus_marker_dir/clades.txt"

    echo "$consensus_marker_dir/clades.txt"
}

# Function to extract markers for each clade
step4() {
    echo "Running Step 4: Extract markers for each clade"
    consensus_marker_dir="consensus_marker"
    clades_file="$consensus_marker_dir/clades.txt"
    print_clades_file="$consensus_marker_dir/print_clades_only.tsv"

    # Debug: Print the current directory and the file path being checked
    echo "Current directory: $(pwd)"
    echo "Looking for clades.txt in: $clades_file"
    
    if [ ! -f "$clades_file" ]; then
        echo "Error: clades.txt not found in $(pwd)/$consensus_marker_dir"
        exit 1
    else
        echo "clades.txt found!"
    fi

    db_marker_dir="db_marker"
    output_dir="output"

    mkdir -p "$db_marker_dir"
    mkdir -p "$output_dir"

    while IFS= read -r clade; do
        extract_markers.py -c "$clade" -o "$db_marker_dir"
        strainphlan -s "$consensus_marker_dir"/*.json.bz2 -m "$db_marker_dir/${clade}.fna" --marker_in_n_samples_perc 10 -o "$output_dir" -n 25 -c "$clade" --mutation_rates
    done < "$clades_file"
}

# Function to check for required directories
check_directories() {
    local required_dirs=("$@")
    for dir in "${required_dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            read -p "Directory $dir is not present. If you have this folder with another name, please enter the name, or press Enter to create it: " new_dir_name
            if [ -z "$new_dir_name" ]; then
                mkdir -p "$dir"
            else
                echo "Using $new_dir_name as $dir"
                eval "${dir}='${new_dir_name}'"
            fi
        fi
    done
}

# Determine which steps will not be run to check required directories
required_dirs=()
[[ ! " ${steps[@]} " =~ " 1 " ]] && required_dirs+=("sams")
[[ ! " ${steps[@]} " =~ " 2 " ]] && required_dirs+=("consensus_marker")
[[ ! " ${steps[@]} " =~ " 3 " ]] && required_dirs+=("consensus_marker/clades.txt")

# Check for required directories
check_directories "${required_dirs[@]}"

# Run selected steps
for step in "${steps[@]}"; do
    case $step in
        1) 
            if [ "$file_type" == "paired" ]; then
                step1_paired
            elif [ "$file_type" == "single" ]; then
                step1_single
            else
                echo "Invalid file type specified. Please enter 'paired' or 'single'."
                exit 1
            fi
            ;;
        2) step2 ;;
        3) step3 ;;
        4) step4 ;;
        *) echo "Invalid step: $step" ;;
    esac
done
