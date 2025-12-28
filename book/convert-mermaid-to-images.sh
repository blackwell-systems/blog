#!/bin/bash
# convert-mermaid-to-images.sh
# Converts mermaid blocks to PNG image references for Leanpub PDF/EPUB
# Preserves original files in manuscript/, creates Leanpub version in manuscript-leanpub/

set -e

SOURCE_DIR="manuscript"
OUTPUT_DIR="manuscript-leanpub"

# Clean and create output directory
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

echo "=== Converting mermaid blocks to image references ==="
echo ""
echo "Source: $SOURCE_DIR/"
echo "Output: $OUTPUT_DIR/"
echo ""

# Copy Book.txt
cp Book.txt "$OUTPUT_DIR/"

# Function to process a file
process_file() {
    local source_file="$1"
    local output_file="$2"
    
    # Determine the chapter/file name for diagram numbering
    local basename=$(basename "$source_file" .md)
    local diagram_counter=1
    local in_mermaid=false
    
    # Create output directory structure
    mkdir -p "$(dirname "$output_file")"
    
    # Process line by line
    while IFS= read -r line; do
        # Convert Hugo callout shortcodes to Leanpub format
        if [[ "$line" =~ ^\{\{.*callout\ type=\"info\".*\>\}\}$ ]]; then
            echo "{blurb, class: information}" >> "$output_file"
            continue
        fi
        if [[ "$line" =~ ^\{\{.*callout\ type=\"warning\".*\>\}\}$ ]]; then
            echo "{blurb, class: warning}" >> "$output_file"
            continue
        fi
        if [[ "$line" =~ ^\{\{.*callout\ type=\"success\".*\>\}\}$ ]]; then
            echo "{blurb, class: tip}" >> "$output_file"
            continue
        fi
        if [[ "$line" =~ ^\{\{.*callout\ type=\"danger\".*\>\}\}$ ]]; then
            echo "{blurb, class: error}" >> "$output_file"
            continue
        fi
        if [[ "$line" =~ ^\{\{.*\/callout.*\>\}\}$ ]]; then
            echo "{/blurb}" >> "$output_file"
            continue
        fi
        
        # Check for Hugo shortcode mermaid block start
        if [[ "$line" =~ ^\{\{\<\ mermaid\ \>\}\}$ ]]; then
            in_mermaid=true
            # Output image reference with width constraint
            echo "" >> "$output_file"
            echo "![Diagram $diagram_counter](resources/mermaid-diagrams/${basename}-diagram-${diagram_counter}.png){width=85%}" >> "$output_file"
            echo "" >> "$output_file"
            diagram_counter=$((diagram_counter + 1))
            continue
        fi
        
        # Check for Hugo shortcode mermaid block end
        if [[ "$line" =~ ^\{\{.*\/mermaid.*\}\}$ ]]; then
            in_mermaid=false
            continue
        fi
        
        # Check for code fence mermaid block start
        if [[ "$line" == '```mermaid' ]]; then
            in_mermaid=true
            # Output image reference with width constraint
            echo "" >> "$output_file"
            echo "![Diagram $diagram_counter](resources/mermaid-diagrams/${basename}-diagram-${diagram_counter}.png){width=85%}" >> "$output_file"
            echo "" >> "$output_file"
            diagram_counter=$((diagram_counter + 1))
            continue
        fi
        
        # Check for code fence end (any ``` while in mermaid block)
        if [[ "$in_mermaid" == true && "$line" == '```' ]]; then
            in_mermaid=false
            continue
        fi
        
        # Skip lines inside mermaid blocks
        if [[ "$in_mermaid" == true ]]; then
            continue
        fi
        
        # Convert Hugo relref shortcodes to plain text (remove shortcode syntax)
        # Example: [text]({{< relref "file.md" >}}) → [text](#)
        line=$(echo "$line" | sed 's/{{< relref "[^"]*" >}}/#/g')
        
        # Output normal lines
        echo "$line" >> "$output_file"
    done < "$source_file"
}

# Process all files listed in Book.txt
while IFS= read -r filepath; do
    # Skip empty lines
    [[ -z "$filepath" ]] && continue
    
    source_file="$SOURCE_DIR/$filepath"
    output_file="$OUTPUT_DIR/$filepath"
    
    if [[ -f "$source_file" ]]; then
        echo "Processing: $filepath"
        process_file "$source_file" "$output_file"
    else
        echo "WARNING: File not found: $source_file"
    fi
done < Book.txt

# Copy images to resources/mermaid-diagrams (for Leanpub Editor Resources)
echo ""
echo "Copying images to resources/mermaid-diagrams/..."
mkdir -p "$OUTPUT_DIR/resources/mermaid-diagrams"
cp "$SOURCE_DIR/images/diagrams/"*.png "$OUTPUT_DIR/resources/mermaid-diagrams/"

echo ""
echo "=== Conversion Complete ==="
echo ""
echo "Original files (with mermaid): $SOURCE_DIR/"
echo "Leanpub files (with PNGs):     $OUTPUT_DIR/"
echo ""
echo "Next steps:"
echo "1. Review a few files in $OUTPUT_DIR/ to verify conversion"
echo "2. Upload $OUTPUT_DIR/ contents to Leanpub (via Dropbox or browser)"
echo "3. Generate preview on Leanpub"
echo ""
