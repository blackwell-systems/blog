#!/bin/bash

echo "=== Rendering All Mermaid Diagrams ==="
echo ""

TOTAL_DIAGRAMS=0

# Process all chapter files including DIAGRAMS files
for chapter in manuscript/chapters/chapter-*.md; do
    if [ -f "$chapter" ]; then
        chapter_name=$(basename "$chapter" .md)
        
        # Skip OUTLINE files (they don't have diagrams to render)
        if [[ "$chapter_name" == *"OUTLINE"* ]]; then
            continue
        fi
        
        echo "Processing: $chapter_name"
        
        ./extract-mermaid.sh "$chapter"
        
        # Extract base chapter number for counting
        base_name=$(echo "$chapter_name" | sed 's/-DIAGRAMS$//' | sed 's/-DATA$//')
        count=$(ls manuscript/images/diagrams/${base_name}-diagram-*.png 2>/dev/null | wc -l)
        TOTAL_DIAGRAMS=$((TOTAL_DIAGRAMS + count))
        echo ""
    fi
done

echo "=== Complete ==="
echo "Total diagrams rendered: $TOTAL_DIAGRAMS"
echo "Output directory: manuscript/images/diagrams/"
