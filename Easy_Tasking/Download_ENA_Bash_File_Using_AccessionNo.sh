#!/bin/bash

# Check if accession is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <ACCESSION_NUMBER>"
    exit 1
fi

ACCESSION="$1"
FOLDER="$ACCESSION"

# Create directory
mkdir -p "$FOLDER"

# Move into the directory
cd "$FOLDER" || exit

# Download TSV metadata file
wget -q "https://www.ebi.ac.uk/ena/portal/api/filereport?accession=$ACCESSION&result=read_run&fields=fastq_ftp&format=tsv&download=true" -O "${ACCESSION}.tsv"

# Check if download was successful
if [ ! -s "${ACCESSION}.tsv" ]; then
    echo "Error: Failed to download TSV for accession $ACCESSION"
    exit 1
fi

# Create the download script
tail -n +2 "${ACCESSION}.tsv" | cut -f2 | awk -F';' '{
    for(i=1;i<=NF;i++) {
        if($i != "") print "wget -nc ftp://"$i
    }
}' > "${ACCESSION}.sh"

# Make the script executable
chmod +x "${ACCESSION}.sh"

echo "Download script created at ${FOLDER}/${ACCESSION}.sh"
