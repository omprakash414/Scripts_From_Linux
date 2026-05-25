#!/usr/bin/env python3

import pandas as pd
import re
import sys
import os
import argparse

def extract_sample_map(file_path, output_map_path):
    sample_map = {}
    with open(file_path) as f:
        for line in f:
            if line.startswith("#S"):
                parts = line.strip().split()
                if len(parts) == 2:
                    sample_id = parts[0].lstrip("#")
                    sample_name = parts[1].replace("_report.txt", "").strip()
                    sample_map[sample_id] = sample_name

    if not sample_map:
        print("❌ No sample mappings found in the input file.")
        return {}

    with open(output_map_path, "w") as out:
        out.write("Sample_ID\tSample_Name\n")
        for sid, name in sample_map.items():
            out.write(f"{sid}\t{name}\n")

    print(f"📄 Sample mapping saved to: {output_map_path}")
    return sample_map

def parse_combined_report(file_path, sample_map, level="S"):
    header_line = None

    with open(file_path) as f:
        lines = f.readlines()
        for line in lines:
            if line.startswith("#perc"):
                header_line = line
                break

    if not header_line:
        print("❌ Error: Header line (#perc ...) not found.")
        sys.exit(1)

    header = header_line.lstrip("#").strip().split("\t")
    df = pd.read_csv(file_path, sep="\t", comment="#", names=header)

    sample_cols = [col for col in df.columns if re.match(r"S\d+_all", col)]
    matrix_data = {}

    for idx, row in df.iterrows():
        if row['lvl_type'] != level:
            continue

        name = row['name'].strip().replace(" ", "_")

        for col in sample_cols:
            sample_id = col.replace("_all", "")
            sample = sample_map.get(sample_id, sample_id)
            count = int(row[col])
            matrix_data.setdefault(sample, {})[name] = count

    output_df = pd.DataFrame.from_dict(matrix_data, orient="index").fillna(0).astype(int)
    output_df.index.name = "Sample"
    return output_df

def main():
    parser = argparse.ArgumentParser(description="Generate species and genus matrices from Kraken2 combined report.")
    parser.add_argument("input_file", help="Path to Kraken2 combined report file")
    parser.add_argument("--output", "-o", required=True, help="Output base filename (e.g. result.xlsx)")
    args = parser.parse_args()

    if not os.path.isfile(args.input_file):
        print(f"❌ Error: File not found: {args.input_file}")
        sys.exit(1)

    mapping_file = "sample_mapping.tsv"
    sample_map = extract_sample_map(args.input_file, mapping_file)
    if not sample_map:
        sys.exit(1)

    print("📊 Generating species matrix...")
    df_species = parse_combined_report(args.input_file, sample_map, level="S")

    print("📊 Generating genus matrix...")
    df_genus = parse_combined_report(args.input_file, sample_map, level="G")

    base, ext = os.path.splitext(args.output)
    species_file = f"{base}_species_matrix{ext}"
    genus_file = f"{base}_genus_matrix{ext}"

    try:
        if ext == ".tsv":
            df_species.to_csv(species_file, sep="\t")
            df_genus.to_csv(genus_file, sep="\t")
        elif ext == ".csv":
            df_species.to_csv(species_file)
            df_genus.to_csv(genus_file)
        elif ext == ".xlsx":
            df_species.to_excel(species_file)
            df_genus.to_excel(genus_file)
        else:
            print("❌ Error: Output file extension must be one of: .tsv, .csv, .xlsx")
            sys.exit(1)
    except ModuleNotFoundError as e:
        print(f"❌ Missing dependency: {e}. For Excel output, run: pip install openpyxl")
        sys.exit(1)

    print(f"✅ Species matrix written to: {species_file}")
    print(f"✅ Genus matrix written to: {genus_file}")

if __name__ == "__main__":
    main()
