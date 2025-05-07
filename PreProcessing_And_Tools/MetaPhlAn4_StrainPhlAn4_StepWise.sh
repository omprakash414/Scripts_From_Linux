#!/bin/bash

# Function to display help
show_help() {
    echo "Usage: $0 <directory> <paired|single> [steps]"
    echo ""
    echo "This script processes a directory with fastq files (paired-end or single-end) through a series of steps:"
    echo "1. Metaphlan (MetaPhlAn 4) for each file or pair of forward and reverse files"
    echo "2. Generate consensus marker"
    echo "3. Print clades for further process"
    echo "4. Extract markers for each clade and run StrainPhlAn (v4)"
    echo ""
    echo "Examples:"
    echo "  Run all steps: bash script.sh /path/to/directory paired 1 2 3 4"
    echo "  Run specific steps: bash script.sh /path/to/directory single 1 3"
    echo ""
    echo "Options:"
    echo "  -h, --help    Show this help message and exit"
}

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_help
    exit 0
fi

if [ $# -lt 3 ]; then
    echo "Usage: $0 <directory> <paired|single> [steps]"
    exit 1
fi

input_dir="$1"
file_type="$2"
shift 2
steps=($@)

cd "$input_dir" || { echo "Error: Unable to access directory $input_dir"; exit 1; }

step1_paired() {
    echo "Running Step 1 (paired-end): MetaPhlAn 4"
    mkdir -p bowtie2 sams
    for file in *_1.fastq.gz; do
        sample_name=$(basename "$file" _1.fastq.gz)
        zcat "${sample_name}_1.fastq.gz" "${sample_name}_2.fastq.gz" > "${sample_name}.merged.fastq"
        metaphlan "${sample_name}.merged.fastq" --input_type fastq -s "sams/${sample_name}.sam.bz2" \
            --bowtie2out "bowtie2/${sample_name}.bowtie2.bz2" --nproc 20 -o "${sample_name}_profiled.txt"
        rm "${sample_name}.merged.fastq"
    done
    rm -rf bowtie2
}

step1_single() {
    echo "Running Step 1 (single-end): MetaPhlAn 4"
    mkdir -p bowtie2 sams
    for file in *.fastq.gz; do
        sample_name=$(basename "$file" .fastq.gz)
        metaphlan "$file" --input_type fastq -s "sams/${sample_name}.sam.bz2" \
            --bowtie2out "bowtie2/${sample_name}.bowtie2.bz2" --nproc 20 -o "${sample_name}_profiled.txt"
    done
    rm -rf bowtie2
}

step2() {
    echo "Running Step 2: sample2markers"
    mkdir -p consensus_marker
    sample2markers.py -i sams/*.sam.bz2 -o consensus_marker -n 20
}

step3() {
    echo "Running Step 3: strainphlan --print_clades_only"
    strainphlan -s consensus_marker/*.json.bz2 -o consensus_marker \
        --print_clades_only --marker_in_n_samples_perc 10
    tail -n +2 consensus_marker/print_clades_only.tsv | cut -f1 > consensus_marker/clades.txt
    echo "Saved clades to consensus_marker/clades.txt"
}

step4() {
    echo "Running Step 4: extract_markers and strainphlan"
    clades_file="consensus_marker/clades.txt"
    if [ ! -f "$clades_file" ]; then
        echo "Error: $clades_file not found. Please run step 3 first."
        exit 1
    fi

    mkdir -p db_marker output
    while read -r clade; do
        echo "Processing clade: $clade"
        extract_markers.py -c "$clade" -o db_marker
        strainphlan -s consensus_marker/*.json.bz2 -m "db_marker/${clade}.fna" \
            -o output -c "$clade" --marker_in_n_samples_perc 10 --mutation_rates -n 25
    done < "$clades_file"
}

for step in "${steps[@]}"; do
    case $step in
        1)
            [ "$file_type" == "paired" ] && step1_paired || step1_single
            ;;
        2) step2 ;;
        3) step3 ;;
        4) step4 ;;
        *) echo "Invalid step: $step" ;;
    esac
