import argparse
import requests
from bs4 import BeautifulSoup
import pandas as pd
import os
from concurrent.futures import ProcessPoolExecutor, as_completed

# Function to scrape taxonomy information from NCBI
def scrape_taxonomy(species_name):
    if "_" in species_name:
        species_name = "%20".join(species_name.split("_"))
    elif " " in species_name:
        species_name = "%20".join(species_name.split(" "))

    url = f"https://www.ncbi.nlm.nih.gov/Taxonomy/Browser/wwwtax.cgi?name={species_name}"
    try:
        response = requests.get(url)
        response.raise_for_status()
        soup = BeautifulSoup(response.content, 'html.parser')
        species_tag = soup.find('a', title='species')
        if species_tag:
            latest_name = species_tag.text
            return latest_name.replace(" ", "_").replace("[", "").replace("]", "")
        else:
            return "_".join(species_name.split("%20")).replace("[", "").replace("]", "")
    except Exception as e:
        print(f"Error fetching taxonomy for {species_name}: {e}")
        return "_".join(species_name.split("%20")).replace("[", "").replace("]", "")

def process_species(species):
    latest_name = scrape_taxonomy(species)
    return species, latest_name

# Function to process the input file
def process_file(input_file):
    if not input_file.endswith('.txt'):
        print("Error: Unsupported file format. Please provide a .txt file.")
        return

    try:
        with open(input_file, 'r') as f:
            species_list = [line.strip().strip('"') for line in f if line.strip()]
    except Exception as e:
        print(f"Error reading input file: {e}")
        return

    unique_species = {}
    max_workers = os.cpu_count()

    with ProcessPoolExecutor(max_workers=max_workers) as executor:
        futures = {executor.submit(process_species, species): species for species in species_list}
        for future in as_completed(futures):
            species, species_name = future.result()
            unique_species[species] = species_name

    output_df = pd.DataFrame(list(unique_species.items()), columns=['Previous_Name', 'New_Name'])

    merged_output_file = os.path.join(os.path.dirname(input_file), "Merged_" + os.path.basename(input_file))
    new_output_file = os.path.join(os.path.dirname(input_file), "New_" + os.path.basename(input_file))

    output_df.to_csv(merged_output_file, sep='\t', index=False)

    with open(new_output_file, 'w') as new_file:
        for new_name in unique_species.values():
            new_file.write(f"{new_name}\n")

    print(f"✅ Species names updated successfully!\nMerged file: {merged_output_file}\nNew names file: {new_output_file}")

# Main execution with argparse
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Update species names using NCBI taxonomy database.")
    parser.add_argument("input_file", help="Path to the input text file containing species names (one per line).")
    
    args = parser.parse_args()
    
    process_file(args.input_file)
