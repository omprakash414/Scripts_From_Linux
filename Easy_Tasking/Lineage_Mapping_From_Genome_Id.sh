#!/usr/bin/env bash
set -euo pipefail

# ============================== #
# Help / Input check
# ============================== #
if [ "$#" -ne 2 ]; then
  echo "Usage: $0 assembly_taxid_map.tsv output_lineage.tsv"
  exit 1
fi

ASSEMBLY_TAXID_FILE="$1"
OUTFILE="$2"

# ============================== #
# Setup workspace
# ============================== #
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

mkdir -p "$WORKDIR/unzip"
TAXONOMY_FILE="$WORKDIR/all_taxonomy.tsv"
> "$TAXONOMY_FILE"

# ============================== #
# Step 1: Extract unique taxon IDs
# ============================== #
echo "📋 Extracting unique taxon IDs..."
cut -f2 "$ASSEMBLY_TAXID_FILE" | sort -u > "$WORKDIR/taxids.txt"
echo "📋 Unique TaxIDs: $(wc -l < "$WORKDIR/taxids.txt")"

# ============================== #
# Step 2: Loop over taxon IDs and download taxonomy
# ============================== #
echo "📡 Downloading taxonomy per taxon..."

while read -r TAXID; do
  ZIP="$WORKDIR/taxon_${TAXID}.zip"
  OUTDIR="$WORKDIR/unzip"

  datasets download taxonomy taxon "$TAXID" --filename "$ZIP" >/dev/null 2>&1 || {
    echo "⚠️  Failed to download taxon: $TAXID"
    continue
  }

  unzip -q "$ZIP" -d "$OUTDIR"

  TSV_FILE=$(find "$OUTDIR/ncbi_dataset/data/" -name "taxonomy_summary.tsv" | head -n1)

  if [[ -f "$TSV_FILE" ]]; then
    cat "$TSV_FILE" >> "$TAXONOMY_FILE"
  else
    echo "⚠️ taxonomy_summary.tsv not found for taxon $TAXID"
  fi

  rm -rf "$ZIP" "$OUTDIR"
done < "$WORKDIR/taxids.txt"

# ============================== #
# Step 3: Parse lineage
# ============================== #
echo "🧬 Parsing taxonomy summary..."
LINEAGE_FILE="$WORKDIR/taxid_lineage.tsv"

awk -F '\t' 'BEGIN{OFS="\t"}
NR > 1 {
  lineage = $11";"$13";"$15";"$17";"$19";"$21";"$23
  taxid = $2
  taxname = $3
  lineage_full = lineage";"taxname
  print taxid, lineage_full
}' "$TAXONOMY_FILE" > "$LINEAGE_FILE"

# ============================== #
# Step 4: Join with accession IDs
# ============================== #
echo "🔗 Mapping accessions to full lineage..."

join -t $'\t' -1 2 -2 1 <(sort -k2,2 "$ASSEMBLY_TAXID_FILE") <(sort "$LINEAGE_FILE") |
  awk -F '\t' 'BEGIN{OFS="\t"} {print $2, $3}' > "$OUTFILE"

echo "✅ Done. Lineage mapping saved to: $OUTFILE"
