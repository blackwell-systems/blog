#!/bin/bash
# prepare-for-leanpub-browser.sh
# Creates numbered files for easy copy/paste into Leanpub browser interface

OUTPUT_DIR="leanpub-browser-ready"
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

echo "=== Preparing files for Leanpub browser interface ==="
echo ""

counter=1

# Read Book.txt and copy files with numbers
while IFS= read -r filepath; do
    # Skip empty lines
    [[ -z "$filepath" ]] && continue
    
    source_file="manuscript/$filepath"
    
    if [[ -f "$source_file" ]]; then
        # Get just the filename without path
        filename=$(basename "$filepath")
        # Create numbered copy
        numbered_file=$(printf "%02d-%s" "$counter" "$filename")
        
        cp "$source_file" "$OUTPUT_DIR/$numbered_file"
        echo "[$counter] $filename"
        
        counter=$((counter + 1))
    else
        echo "WARNING: File not found: $source_file"
    fi
done < Book.txt

echo ""
echo "=== Complete ==="
echo "Files prepared in: $OUTPUT_DIR/"
echo "Total files: $((counter - 1))"
echo ""
echo "Next steps:"
echo "1. Go to Leanpub → Create book → Choose 'Browser'"
echo "2. In Leanpub, create 18 chapters (they'll create placeholders)"
echo "3. Open each file in $OUTPUT_DIR/ and copy/paste into Leanpub"
echo "4. Files are numbered in correct order (01- through 18-)"
echo "5. Click 'Preview' when done to see your book!"
