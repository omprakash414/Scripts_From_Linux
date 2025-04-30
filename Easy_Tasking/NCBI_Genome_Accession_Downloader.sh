#!/bin/bash

# Check if the list of species names is provided
if [ $# -lt 1 ]; then
    echo "Usage: $0 species_list.txt"
    exit 1
fi

species_list=$1
no_species_found="No_Species_Found.txt"
no_genomes_found="No_Genomes_Found.txt"

# Clear or create the error files
> $no_species_found
> $no_genomes_found

# Function to convert JSONL to TXT in vertical format
jsonl_to_txt() {
    local jsonl_file="$1"
    local output_file="$2"

    # Process each line in the JSONL file
    while IFS= read -r line; do
        # Extracting fields using jq
        accession=$(echo "$line" | jq -r '.currentAccession // "N/A"')
        assembly_name=$(echo "$line" | jq -r '.assemblyInfo.assemblyName // "N/A"')
        assembly_level=$(echo "$line" | jq -r '.assemblyInfo.assemblyLevel // "N/A"')
        assembly_method=$(echo "$line" | jq -r '.assemblyInfo.assemblyMethod // "N/A"')
        assembly_status=$(echo "$line" | jq -r '.assemblyInfo.assemblyStatus // "N/A"')
        assembly_type=$(echo "$line" | jq -r '.assemblyInfo.assemblyType // "N/A"')
        bioproject_accession=$(echo "$line" | jq -r '.assemblyInfo.bioprojectAccession // "N/A"')
        bioproject_title=$(echo "$line" | jq -r '.assemblyInfo.bioprojectLineage[0].bioprojects[0].title // "N/A"')
        strain=$(echo "$line" | jq -r '.assemblyInfo.biosample.attributes[] | select(.name=="strain").value // "N/A"')
        isolation_source=$(echo "$line" | jq -r '.assemblyInfo.biosample.isolationSource // "N/A"')
        collection_date=$(echo "$line" | jq -r '.assemblyInfo.biosample.collectionDate // "N/A"')
        location=$(echo "$line" | jq -r '.assemblyInfo.biosample.geoLocName // "N/A"')
        sample_type=$(echo "$line" | jq -r '.assemblyInfo.biosample.sampleType // "N/A"')
        organism_name=$(echo "$line" | jq -r '.organism.organismName // "N/A"')
        tax_id=$(echo "$line" | jq -r '.organism.taxId // "N/A"')
        submitter=$(echo "$line" | jq -r '.submitter // "N/A"')
        release_date=$(echo "$line" | jq -r '.releaseDate // "N/A"')
        sequencing_tech=$(echo "$line" | jq -r '.assemblyInfo.sequencingTech // "N/A"')

        # Annotation information
        gene_counts=$(echo "$line" | jq -r '.annotationInfo.stats.geneCounts')
        total_genes=$(echo "$gene_counts" | jq -r '.total // "N/A"')
        protein_coding_genes=$(echo "$gene_counts" | jq -r '.proteinCoding // "N/A"')
        non_coding_genes=$(echo "$gene_counts" | jq -r '.nonCoding // "N/A"')
        pseudogenes=$(echo "$gene_counts" | jq -r '.pseudogene // "N/A"')

        # Assembly statistics
        contig_l50=$(echo "$line" | jq -r '.assemblyStats.contigL50 // "N/A"')
        contig_n50=$(echo "$line" | jq -r '.assemblyStats.contigN50 // "N/A"')
        gc_percent=$(echo "$line" | jq -r '.assemblyStats.gcPercent // "N/A"')
        total_sequence_length=$(echo "$line" | jq -r '.assemblyStats.totalSequenceLength // "N/A"')

        # Average Nucleotide Identity (ANI) information
        ani_category=$(echo "$line" | jq -r '.averageNucleotideIdentity.category // "N/A"')
        ani_value=$(echo "$line" | jq -r '.averageNucleotideIdentity.bestAniMatch.ani // "N/A"')
        ani_organism=$(echo "$line" | jq -r '.averageNucleotideIdentity.bestAniMatch.organismName // "N/A"')

        # CheckM information
        checkm_completeness=$(echo "$line" | jq -r '.checkmInfo.completeness // "N/A"')
        checkm_contamination=$(echo "$line" | jq -r '.checkmInfo.contamination // "N/A"')

        # Write the data in a vertical format
        {
            echo "Accession: $accession"
            echo "Assembly Name: $assembly_name"
            echo "Assembly Level: $assembly_level"
            echo "Assembly Method: $assembly_method"
            echo "Assembly Status: $assembly_status"
            echo "Assembly Type: $assembly_type"
            echo "Bioproject Accession: $bioproject_accession"
            echo "Bioproject Title: $bioproject_title"
            echo "Strain: $strain"
            echo "Isolation Source: $isolation_source"
            echo "Collection Date: $collection_date"
            echo "Location: $location"
            echo "Sample Type: $sample_type"
            echo "Organism Name: $organism_name"
            echo "Tax ID: $tax_id"
            echo "Submitter: $submitter"
            echo "Release Date: $release_date"
            echo "Sequencing Tech: $sequencing_tech"
            echo "Total Genes: $total_genes"
            echo "Protein-coding Genes: $protein_coding_genes"
            echo "Non-coding Genes: $non_coding_genes"
            echo "Pseudogenes: $pseudogenes"
            echo "Contig L50: $contig_l50"
            echo "Contig N50: $contig_n50"
            echo "GC Percent: $gc_percent"
            echo "Total Sequence Length: $total_sequence_length"
            echo "ANI Category: $ani_category"
            echo "ANI Value: $ani_value"
            echo "ANI Organism: $ani_organism"
            echo "CheckM Completeness: $checkm_completeness"
            echo "CheckM Contamination: $checkm_contamination"
            echo "Current Accession: $accession"
            echo "Source Database: SOURCE_DATABASE_GENBANK"
            echo ""  # Blank line between records
        } >> "$output_file"
    done < "$jsonl_file"
}

# Loop through each species name in the provided file
while IFS= read -r species; do
    echo "Processing species: $species"
    
    # Replace underscores with spaces in species name
    cleaned_species=$(echo "$species" | tr '_' ' ')

    # Create a folder for the species
    species_folder="${cleaned_species// /_}"  # Folder name still uses underscores
    mkdir -p "$species_folder"

    # Set the download file name
    download_file="$species_folder/ncbi_dataset.zip"

    # Try downloading the genomes with --filename option
    datasets download genome taxon "$cleaned_species" --filename "$download_file"
    
    # Check if the download was successful
    if [ $? -ne 0 ]; then
        echo "$species" >> $no_species_found
        rm -rf "$species_folder"
        continue
    fi

    # Unzip the downloaded file
    unzip "$download_file" -d "$species_folder"
    if [ $? -ne 0 ]; then
        echo "$species" >> $no_genomes_found
        rm -rf "$species_folder"
        continue
    fi

    # Check if any .fna files are present
    fna_files=$(find "$species_folder/ncbi_dataset/data/" -name "*.fna")
    if [ -z "$fna_files" ]; then
        echo "$species" >> $no_genomes_found
        rm -rf "$species_folder"
        continue
    fi

    # Move .fna files to the species folder
    find "$species_folder/ncbi_dataset/data/" -name "*.fna" -exec mv {} "$species_folder/" \;

    # Move the original .jsonl file to the species folder and convert it to a .txt file
    jsonl_file="$species_folder/ncbi_dataset/data/assembly_data_report.jsonl"
    if [ -f "$jsonl_file" ]; then
        mv "$jsonl_file" "$species_folder/"
        # Convert the .jsonl file to .txt with the name <species_name>_report.txt
        report_txt_file="$species_folder/${species_folder}_report.txt"
        jsonl_to_txt "$species_folder/assembly_data_report.jsonl" "$report_txt_file"
    fi

    # Remove the downloaded zip and subdirectories
    rm -rf "$download_file" "$species_folder/ncbi_dataset"

    # Remove GCF entries if corresponding GCA entries exist
    while IFS= read -r gca_file; do
        gcf_file="${gca_file/GCA_/GCF_}"

        # Check if GCF file exists
        if [ -f "$gcf_file" ]; then
            # Remove GCF entry from the report_txt_file
            sed -i "/Accession: $gcf_file/,/^Accession:/d" "$report_txt_file"
            # Remove the GCF file
            rm -f "$gcf_file"
        fi
    done < <(find "$species_folder" -name "GCA_*.fna")

done < "$species_list"
