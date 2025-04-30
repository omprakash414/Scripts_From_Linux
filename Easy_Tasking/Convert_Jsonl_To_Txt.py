import json
import sys

def jsonl_to_txt(jsonl_file, output_file):
    with open(jsonl_file, 'r') as infile, open(output_file, 'w') as outfile:
        # Write the header row
        header = [
            "Accession", "Assembly Name", "Assembly Level", "Bioproject Accession",
            "Organism Name", "Strain", "Submitter", "Release Date",
            "Annotation Name", "Annotation Provider", "Annotation Release Date",
            "Total Genes", "Protein-coding Genes", "Non-coding Genes", "Pseudogenes",
            "Contig L50", "Contig N50", "GC Percent", "Total Sequence Length",
            "ANI Category", "ANI Value", "ANI Organism"
        ]
        outfile.write("\t".join(header) + "\n")

        # Process each line in the JSONL file
        for line in infile:
            record = json.loads(line)

            # Extract basic assembly information
            accession = record.get("accession", "N/A")
            assembly_name = record.get("assemblyInfo", {}).get("assemblyName", "N/A")
            assembly_level = record.get("assemblyInfo", {}).get("assemblyLevel", "N/A")
            bioproject = record.get("assemblyInfo", {}).get("bioprojectAccession", "N/A")
            organism_name = record.get("organism", {}).get("organismName", "N/A")
            strain = record.get("organism", {}).get("infraspecificNames", {}).get("strain", "N/A")
            submitter = record.get("submitter", "N/A")
            release_date = record.get("releaseDate", "N/A")

            # Annotation information
            annotation_name = record.get("annotationInfo", {}).get("name", "N/A")
            annotation_provider = record.get("annotationInfo", {}).get("provider", "N/A")
            annotation_release_date = record.get("annotationInfo", {}).get("releaseDate", "N/A")
            gene_counts = record.get("annotationInfo", {}).get("stats", {}).get("geneCounts", {})
            total_genes = gene_counts.get("total", "N/A")
            protein_coding_genes = gene_counts.get("proteinCoding", "N/A")
            non_coding_genes = gene_counts.get("nonCoding", "N/A")
            pseudogenes = gene_counts.get("pseudogene", "N/A")

            # Assembly statistics
            contig_l50 = record.get("assemblyStats", {}).get("contigL50", "N/A")
            contig_n50 = record.get("assemblyStats", {}).get("contigN50", "N/A")
            gc_percent = record.get("assemblyStats", {}).get("gcPercent", "N/A")
            total_sequence_length = record.get("assemblyStats", {}).get("totalSequenceLength", "N/A")

            # Average Nucleotide Identity (ANI) information
            ani_category = record.get("averageNucleotideIdentity", {}).get("category", "N/A")
            ani_value = record.get("averageNucleotideIdentity", {}).get("bestAniMatch", {}).get("ani", "N/A")
            ani_organism = record.get("averageNucleotideIdentity", {}).get("bestAniMatch", {}).get("organismName", "N/A")

            # Write the data in a tabular format
            row = [
                accession, assembly_name, assembly_level, bioproject, organism_name, strain,
                submitter, release_date, annotation_name, annotation_provider,
                annotation_release_date, total_genes, protein_coding_genes,
                non_coding_genes, pseudogenes, contig_l50, contig_n50,
                gc_percent, total_sequence_length, ani_category, ani_value,
                ani_organism
            ]
            outfile.write("\t".join(map(str, row)) + "\n")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python3 convert_jsonl_to_txt.py <input_jsonl_file> <output_txt_file>")
        sys.exit(1)

    jsonl_file = sys.argv[1]
    output_file = sys.argv[2]
    jsonl_to_txt(jsonl_file, output_file)
