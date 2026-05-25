import os
import math
import pandas as pd
import argparse as ag

def main(path, output_file):
    all_tsv_files = [i for i in os.listdir(path) if '.txt' in i]

    files, species_info = [], {}
    for idx, file in enumerate(all_tsv_files):
        df = pd.read_csv(f'{path}/{file}', sep='\t', skiprows=4)
        for i, j in df.iterrows():
            clade = j['#clade_name']
            abundance = j['relative_abundance']
            if "t__" in j['#clade_name']:
                continue
            if "s__" in j['#clade_name']:
                specie = clade.split('s__')[1]
                if specie not in species_info:
                    species_info[specie] = [0] * int(idx+1)
                    species_info[specie][idx] = abundance
                else:
                    while len(species_info[specie]) <= int(idx):
                        species_info[specie].append(0)
                    species_info[specie][idx] = abundance
        files.append(file.replace('_profiled.txt', ''))

    abundance_matrix = pd.DataFrame(index=files, columns=species_info.keys())

    for i, j in species_info.items():
        for m, n in enumerate(j):
            abundance_matrix.at[abundance_matrix.index[m], i] = n

    abundance_matrix = abundance_matrix.fillna(0).astype(float)

    abundance_matrix.to_csv(f'{output_file}.csv')

if __name__ == "__main__":
    parser = ag.ArgumentParser(description='making Abundance matrix from tsv files present in the given directory')
    parser.add_argument("-i", type=str, help='give path of the directory where txt file are present')
    parser.add_argument("-o", type=str, help='give output file name without extension')
    args = parser.parse_args()
    main(args.i, args.o)
