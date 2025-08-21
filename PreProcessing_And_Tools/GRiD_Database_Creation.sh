#!/bin/bash

# -----------------------------
# Function: Help message
# -----------------------------
show_help() {
    echo "Usage: bash create_grid_db.sh -g <genome_directory> -o <output_directory> -p <prefix>"
    echo ""
    echo "Options:"
    echo "  -g    Path to the directory containing genome files (.fa, .fna, .fasta) [Required]"
    echo "  -o    Output directory for processed genomes and index files [Required]"
    echo "  -p    Prefix for the Bowtie2 index [Required]"
    echo "  -h    Display this help message"
    echo ""
    echo " Following packages must be installed:"
    echo "          sudo dnf install parallel"
    echo "          conda install -c bioconda bowtie2"
    echo "          sudo dnf install bc"
    echo "Example:"
    echo "  bash create_grid_db.sh -g /home/user/genomes -o /home/user/GRID_DB -p GRID_INDEX"
    exit 0
}

# -----------------------------
# Parse command-line arguments
# -----------------------------
while getopts "g:o:p:h" opt; do
  case ${opt} in
    g ) GENOME_DIR=$OPTARG ;;
    o ) OUTPUT_DIR=$OPTARG ;;
    p ) PREFIX=$OPTARG ;;
    h ) show_help ;;
    \? ) echo "Invalid option: -$OPTARG" >&2; show_help ;;
  esac
done

# -----------------------------
# Check arguments
# -----------------------------
if [[ -z "$GENOME_DIR" || -z "$OUTPUT_DIR" || -z "$PREFIX" ]]; then
    echo "Error: Missing required arguments."
    show_help
fi

if [[ ! -d "$GENOME_DIR" ]]; then
    echo "Error: Genome directory '$GENOME_DIR' does not exist."
    exit 1
fi

mkdir -p "$OUTPUT_DIR/processed_genomes"
mkdir -p "$OUTPUT_DIR/index"

# -----------------------------
# Step 1: Collect genome files
# -----------------------------
echo "Step 1: Collecting genome files..."
find "$GENOME_DIR" -type f \( -name "*.fa" -o -name "*.fna" -o -name "*.fasta" \) > "$OUTPUT_DIR/genome_list.txt"

if [[ ! -s "$OUTPUT_DIR/genome_list.txt" ]]; then
    echo "Error: No genome files found in $GENOME_DIR"
    exit 1
fi

# -----------------------------
# Function: Process genome file
# -----------------------------
process_genome() {
    file="$1"
    name=$(basename "$file" | rev | cut -d"." -f2- | rev)

    # Remove first line (original FASTA header), replace extra headers with Ns,
    # flatten to one line, and reinsert simplified header
    sed '1d' "$file" \
    | sed "s/>.*/$(printf '%.0sN' {0..100})/g" \
    | tr -d '\n' \
    | sed "1 i>$name" \
    > "$OUTPUT_DIR/processed_genomes/grid_database_$(basename "$file")"
}
export -f process_genome
export OUTPUT_DIR

# -----------------------------
# Step 2: Preprocess genomes
# -----------------------------
echo "Step 2: Preprocessing genomes (Parallel Mode)..."
parallel -j 16 process_genome :::: "$OUTPUT_DIR/genome_list.txt"

# -----------------------------
# Step 3: Merge processed genomes
# -----------------------------
echo "Step 3: Merging all processed genomes..."
find "$OUTPUT_DIR/processed_genomes" -type f -name "grid_database_*" | xargs cat > "$OUTPUT_DIR/combined_genomes.fa"

# -----------------------------
# Step 4: Build Bowtie2 index
# -----------------------------
echo "Step 4: Building Bowtie2 index..."
bowtie2-build --threads 25 "$OUTPUT_DIR/combined_genomes.fa" "$OUTPUT_DIR/index/$PREFIX"

# -----------------------------
# Step 5: Metadata generation
# -----------------------------
echo "Step 5: Generating metadata and database_misc.txt..."
METADATA_FILE="$OUTPUT_DIR/GRID_metadata.txt"
DB_MISC_FILE="$OUTPUT_DIR/index/database_misc.txt"
> "$METADATA_FILE"
echo -e "Genome\tFragment_range\tBreakpoints\tGenome_length\tFragment_per_Mbp" > "$DB_MISC_FILE"

cd "$OUTPUT_DIR/processed_genomes" || exit

for f in grid_database_*; do
    # Genome length
    len=$(awk '/^>/ {if (seqlen){print seqlen}; print; seqlen=0; next;} {seqlen += length($0)} END {print seqlen}' "$f" \
          | grep -v "^>" | awk '{total += $1} END {print total}')

    # Genome name
    gen=$(grep "^>" "$f" | sed 's/[ >]//g')

    # Fragment ranges (Ns define cut points)
    var1=$(sed '1d' "$f" | tr -d '\n' \
           | grep -b -o N* | cut -f1 -d':' \
           | awk '{print ($1-1)"p"$0}' \
           | sed 's/p/p\n/g' \
           | sed '1 i\1' \
           | sed "\$ s/\$/${len}p/" \
           | tr '\r\n' ',')

    # Breakpoints
    var2=$(sed '1d' "$f" | tr -d '\n' \
           | grep -b -o N* | cut -f1 -d':' \
           | awk '{print $0","($1+99)"d"}' \
           | tr '\r\n' ';')

    # Fragment per Mbp
    fragment=$(echo "$var1" | sed 's/p,/\n/g' | wc -l)
    fpmb=$(echo "scale=3; ($fragment*1000000)/$len" | bc)

    echo -e "$gen\t$var1\t$var2\t$len\t$fpmb" >> "$DB_MISC_FILE"
done

# -----------------------------
# Step 6: Finalize
# -----------------------------
echo "Step 6: Finalizing the database..."
#echo "BOWTIE_$PREFIX" > "$OUTPUT_DIR/bowtie.txt"
echo "$PREFIX" > "$OUTPUT_DIR/index/bowtie.txt"

echo "GRID database creation completed successfully!"
echo "Bowtie2 index: $OUTPUT_DIR/index/$PREFIX"
echo "Metadata file: $OUTPUT_DIR/GRID_metadata.txt"
echo "Database misc file: $OUTPUT_DIR/index/database_misc.txt"
