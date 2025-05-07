#!/bin/bash

corrupted_files="corrupted_files.txt"
> "$corrupted_files"  # Clear the file

for file in *.fastq.gz; do
    pigz -p 25 -dc "$file" > /dev/null 2>/dev/null || echo "$file" >> "$corrupted_files"
done
