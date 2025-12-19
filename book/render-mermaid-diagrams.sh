#!/bin/bash
# render-mermaid-diagrams.sh - Extract and render mermaid diagrams to PNG

CHAPTERS_DIR="manuscript/chapters"
IMAGES_DIR="manuscript/images/diagrams"
mkdir -p "$IMAGES_DIR"

echo "=== Rendering Mermaid Diagrams for PDF/EPUB ==="
echo ""
echo "Note: This is only needed for Pandoc builds (Amazon KDP, Gumroad)"
echo "Leanpub renders mermaid natively from markdown"
echo ""

# Check if mermaid-cli is installed
if ! command -v mmdc &> /dev/null; then
    echo "ERROR: mermaid-cli not found"
    echo "Install with: npm install -g @mermaid-js/mermaid-cli"
    exit 1
fi

diagram_count=0

# Process each chapter
for chapter in "$CHAPTERS_DIR"/*.md; do
    chapter_name=$(basename "$chapter" .md)
    echo "Processing: $chapter_name"
    
    # Extract mermaid blocks and save individually
    diagram_num=0
    in_mermaid=0
    
    while IFS= read -r line; do
        if [[ "$line" == '```mermaid' ]]; then
            in_mermaid=1
            diagram_num=$((diagram_num + 1))
            mmd_file="$IMAGES_DIR/${chapter_name}-diagram-${diagram_num}.mmd"
            > "$mmd_file"  # Clear file
        elif [[ "$line" == '```' ]] && [ $in_mermaid -eq 1 ]; then
            in_mermaid=0
            
            # Render to PNG
            png_file="${mmd_file%.mmd}.png"
            echo "  Rendering diagram $diagram_num → $(basename $png_file)"
            
            mmdc -i "$mmd_file" \
                 -o "$png_file" \
                 -t dark \
                 -b transparent \
                 -w 1800 \
                 -H 1200 \
                 -s 3 \
                 --quiet
            
            if [ $? -eq 0 ]; then
                diagram_count=$((diagram_count + 1))
                rm "$mmd_file"  # Clean up temp .mmd file
            else
                echo "    ERROR: Failed to render diagram"
            fi
        elif [ $in_mermaid -eq 1 ]; then
            echo "$line" >> "$mmd_file"
        fi
    done < "$chapter"
    
done

echo ""
echo "=== Complete ==="
echo "Total diagrams rendered: $diagram_count"
echo "Output directory: $IMAGES_DIR/"
echo ""
echo "Next steps:"
echo "1. Review PNG files for quality"
echo "2. Replace mermaid blocks in markdown with image references"
echo "3. Build PDF/EPUB with Pandoc"
echo ""
echo "For tall diagrams, consider:"
echo "  - Rotating with {width=100% angle=90}"
echo "  - Splitting into multiple focused diagrams"
echo "  - Using landscape orientation"
