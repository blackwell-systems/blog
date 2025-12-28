#!/bin/bash

echo "=== Rendering All Mermaid Diagrams ==="
echo ""

TOTAL_DIAGRAMS=0

for chapter in manuscript/chapters/chapter-*.md; do
    if [ -f "$chapter" ]; then
        chapter_name=$(basename "$chapter" .md)
        echo "Processing: $chapter_name"
        
        ./extract-mermaid.sh "$chapter"
        
        count=$(ls manuscript/images/diagrams/${chapter_name}-diagram-*.png 2>/dev/null | wc -l)
        TOTAL_DIAGRAMS=$((TOTAL_DIAGRAMS + count))
        echo ""
    fi
done

echo "=== Complete ==="
echo "Total diagrams rendered: $TOTAL_DIAGRAMS"
echo "Output directory: manuscript/images/diagrams/"
