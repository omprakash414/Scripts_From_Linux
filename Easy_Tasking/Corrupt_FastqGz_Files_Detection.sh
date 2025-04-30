corrupted_files="corrupted_files.txt"
for file in *.fastq.gz; do
    zcat "$file" > /dev/null || echo "$file" >> "$corrupted_files"
done

