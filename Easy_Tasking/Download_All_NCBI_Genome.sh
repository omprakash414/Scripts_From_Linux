#!/usr/bin/env bash
set -euo pipefail

############################################################
# Help message
############################################################
print_help() {
cat <<'EOF'

Usage:
  Download_All_NABI_Genomes.sh <organism_group> <output_dir>

Description:
  • Downloads BOTH RefSeq and GenBank assembly summaries for the given group
    (bacteria, fungi, viral, archaea, protozoa, etc.).
  • Filters rows with assembly_level == "Complete Genome".
  • Keeps all RefSeq genomes, then adds ONLY GenBank genomes that are NOT
    already in RefSeq (refseq_category == "na"), avoiding duplicates.
  • Downloads the genomic FASTA (.fna.gz) files into <output_dir>.
  • Creates a mapping file of Assembly Accession to TaxID (assembly_taxid_map.tsv).

Arguments:
  <organism_group>   Organism group recognised by NCBI FTP (e.g. fungi, bacteria, viral)
  <output_dir>       Directory where genome FASTA files will be saved

Example:
  ./Download_All_NABI_Genomes.sh fungi   fungi_db
  ./Download_All_NABI_Genomes.sh bacteria bacteria_db

EOF
}

[[ ${1:-} == "-h" || ${1:-} == "--help" || $# -ne 2 ]] && { print_help; exit 0; }

############################################################
# Parameters
############################################################
GROUP="$1"
OUTDIR="$2"

mkdir -p "$OUTDIR"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

############################################################
# 1. Download assembly summary files
############################################################
REFSEQ_ASM="$TMP/${GROUP}_refseq_assembly_summary.txt"
GENBANK_ASM="$TMP/${GROUP}_genbank_assembly_summary.txt"

echo "🔄 Downloading RefSeq assembly summary for '${GROUP}'..."
curl -sSf "https://ftp.ncbi.nlm.nih.gov/genomes/refseq/${GROUP}/assembly_summary.txt" -o "$REFSEQ_ASM"
echo "🔄 Downloading GenBank assembly summary for '${GROUP}'..."
curl -sSf "https://ftp.ncbi.nlm.nih.gov/genomes/genbank/${GROUP}/assembly_summary.txt" -o "$GENBANK_ASM"

############################################################
# 2. Filter for Complete Genomes and prepare paths + mapping
############################################################
REFSEQ_PATHS="$TMP/refseq_paths.txt"
GENBANK_PATHS_RAW="$TMP/genbank_paths_raw.txt"
REFSEQ_MAP="$TMP/refseq_map.tsv"
GENBANK_MAP="$TMP/genbank_map.tsv"

# Extract ftp_path, assembly_accession, taxid from RefSeq
awk -F'\t' '!/^#/ && $12=="Complete Genome" {print $20 "\t" $1 "\t" $6}' "$REFSEQ_ASM" > "$REFSEQ_MAP"
awk -F'\t' '!/^#/ && $12=="Complete Genome" {print $20}' "$REFSEQ_ASM" > "$REFSEQ_PATHS"

# Extract only GenBank entries not in RefSeq (refseq_category == "na")
awk -F'\t' '!/^#/ && $12=="Complete Genome" && $5=="na" {print $20 "\t" $1 "\t" $6}' "$GENBANK_ASM" > "$GENBANK_MAP"
awk -F'\t' '!/^#/ && $12=="Complete Genome" && $5=="na" {print $20}' "$GENBANK_ASM" > "$GENBANK_PATHS_RAW"

# Combine paths and mapping
ALL_PATHS="$TMP/all_unique_paths.txt"
cat "$REFSEQ_PATHS" "$GENBANK_PATHS_RAW" | sort -u > "$ALL_PATHS"

ALL_MAP="$OUTDIR/assembly_taxid_map.tsv"
(cat "$REFSEQ_MAP" "$GENBANK_MAP" | sort -u | awk -F'\t' '
  NR==FNR { path[$1]; next }
  ($1 in path) { print $2 "\t" $3 }
' "$ALL_PATHS" -) > "$ALL_MAP"

# Save original summaries
cp "$REFSEQ_ASM" "$OUTDIR/refseq_${GROUP}_assembly_summary.txt"
cp "$GENBANK_ASM" "$OUTDIR/genbank_${GROUP}_assembly_summary.txt"
cp "$ALL_PATHS" "$OUTDIR/${GROUP}_all_downloaded_paths.txt"

echo "✅ RefSeq complete genomes : $(wc -l < "$REFSEQ_PATHS")"
echo "✅ Extra GenBank genomes   : $(wc -l < "$GENBANK_PATHS_RAW")"
echo "✅ Total unique genomes    : $(wc -l < "$ALL_PATHS")"
echo "🧬 TaxID mapping file written to: $ALL_MAP"

############################################################
# 3. Download genomes
############################################################
echo "⬇️  Downloading .fna.gz files to '$OUTDIR'..."
while read -r ftp_path; do
  fname=$(basename "$ftp_path")
  fna_url="${ftp_path}/${fname}_genomic.fna.gz"
  echo "   └─ $fna_url"
  wget -q -c -P "$OUTDIR" "$fna_url"
done < "$ALL_PATHS"

## If the above download didn't work then use below:
# ############################################################
# # 3. Download genomes
# ############################################################
# echo "⬇️  Downloading .fna.gz files to '$OUTDIR'..."

# while read -r ftp_path; do
#   fname=$(basename "$ftp_path")
#   fna_url="${ftp_path}/${fname}_genomic.fna.gz"

#   echo "   └─ Downloading: $fna_url"

#   wget -4 -c --show-progress \
#        --timeout=30 --read-timeout=30 \
#        --tries=5 \
#        -P "$OUTDIR" "$fna_url"

# done < "$ALL_PATHS"

echo "🎉 Finished. Genomes saved in: $OUTDIR"
