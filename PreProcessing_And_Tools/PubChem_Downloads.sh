#!/bin/bash

# Usage: ./download_conformer.sh "compound name" format
# Example: ./download_conformer.sh "aspirin" sdf

compound_name="$1"
file_format="$2"

if [[ -z "$compound_name" || -z "$file_format" ]]; then
    echo "Usage: $0 \"compound name\" format"
    echo "Example: $0 \"aspirin\" sdf"
    exit 1
fi

# Step 1: Get CID for the compound
cid=$(curl -s "https://pubchem.ncbi.nlm.nih.gov/rest/pug/compound/name/${compound_name// /%20}/cids/TXT" | head -n 1)

if [[ -z "$cid" ]]; then
    echo "❌ Could not find CID for '$compound_name'"
    exit 1
fi

echo "✅ Found CID: $cid for '$compound_name'"

# Step 2: Download 3D conformer
output_file="${compound_name// /_}_3d.${file_format}"
curl -s -L "https://pubchem.ncbi.nlm.nih.gov/rest/pug/compound/CID/${cid}/record/${file_format}?record_type=3d" -o "$output_file"

# Step 3: Check if download was successful
if [[ -s "$output_file" ]]; then
    echo "💾 Saved 3D conformer to $output_file"
else
    echo "❌ No 3D conformer found for CID $cid in format '$file_format'"
    rm -f "$output_file"
fi
