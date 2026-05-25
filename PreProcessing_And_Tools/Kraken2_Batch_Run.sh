#!/bin/bash

# ========================
# Help Function
# ========================
show_help() {
  echo ""
  echo "Usage:"
  echo "  bash $0 /path/to/reads_list.txt /path/to/kraken2_db NUM_THREADS SAMPLE_NAME_PATTERN"
  echo ""
  echo "Description:"
  echo "  This script runs Kraken2 classification using paired-end FASTQ files listed in a two-column text file."
  echo ""
  echo "Positional Arguments:"
  echo "  /path/to/reads_list.txt     Text file with two columns: forward_read reverse_read (full paths)"
  echo "  /path/to/kraken2_db         Path to the Kraken2 database"
  echo "  NUM_THREADS                 Number of threads to use"
  echo "  SAMPLE_NAME_PATTERN         Pattern to strip from forward read file name to get sample name (e.g. '_R1_paired.fastq.gz')"
  echo ""
  echo "Example:"
  echo "  bash $0 reads_list.txt ./kraken2_db 32 _R1_paired.fastq.gz"
  echo ""
  exit 0
}

# ========================
# Show Help if -h or --help is used
# ========================
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
  show_help
fi

# ========================
# Input Parameters
# ========================
READS_LIST="$1"
DB_PATH="$2"
THREADS="$3"
PATTERN="$4"

# ========================
# Validate Inputs
# ========================
if [ "$#" -ne 4 ]; then
  echo "❌ Error: Incorrect number of arguments."
  echo "Use -h for help: bash $0 -h"
  exit 1
fi

if [ ! -f "$READS_LIST" ]; then
  echo "❌ Error: Reads list file '$READS_LIST' does not exist."
  exit 1
fi

if [ ! -d "$DB_PATH" ]; then
  echo "❌ Error: Kraken2 database folder '$DB_PATH' does not exist."
  exit 1
fi

if ! [[ "$THREADS" =~ ^[0-9]+$ ]]; then
  echo "❌ Error: Threads must be a positive integer."
  exit 1
fi

# ========================
# Start Processing
# ========================
echo "🧬 Running Kraken2 classification using reads from: $READS_LIST"
echo "🧪 Database: $DB_PATH"
echo "🧵 Threads: $THREADS"
echo "🧾 Sample name pattern to strip: $PATTERN"
echo ""

while read -r R1 R2; do
  # Validate files
  if [ ! -f "$R1" ] || [ ! -f "$R2" ]; then
    echo "⚠️  Warning: One or both files not found: $R1 $R2 — skipping."
    continue
  fi

  # Get sample name by stripping user-defined pattern from forward read filename
  BASENAME=$(basename "$R1")
  SAMPLE="${BASENAME/$PATTERN/}"
  OUTPUT_DIR=$(dirname "$R1")

  echo "🔍 Processing sample: $SAMPLE"

  kraken2 \
    --db "$DB_PATH" \
    --paired \
    --gzip-compressed \
    --threads "$THREADS" \
    --report "${OUTPUT_DIR}/${SAMPLE}_report.txt" \
    --output "${OUTPUT_DIR}/${SAMPLE}_kraken2_output.txt" \
    "$R1" "$R2"

  echo "✅ Finished: $SAMPLE"
  echo

done < "$READS_LIST"

echo "🎉 All samples processed based on: $READS_LIST"
