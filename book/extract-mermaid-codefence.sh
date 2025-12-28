#!/bin/bash

# Extract mermaid diagrams from markdown files (handles ```mermaid code fences)
INPUT_FILE="$1"
CHAPTER_NAME=$(basename "$INPUT_FILE" .md)

# Remove -DIAGRAMS suffix for output filename consistency
BASE_CHAPTER=$(echo "$CHAPTER_NAME" | sed 's/-DIAGRAMS$//' | sed 's/-DATA$//')

OUTPUT_DIR="manuscript/images/diagrams"
TEMP_DIR="temp_mermaid"

mkdir -p "$OUTPUT_DIR"
mkdir -p "$TEMP_DIR"

DIAGRAM_COUNT=0
IN_MERMAID=false
MERMAID_CONTENT=""

while IFS= read -r line; do
    if [[ "$line" =~ ^\`\`\`mermaid ]]; then
        IN_MERMAID=true
        MERMAID_CONTENT=""
        continue
    fi
    
    if [[ "$IN_MERMAID" == true ]]; then
        if [[ "$line" =~ ^\`\`\`$ ]]; then
            ((DIAGRAM_COUNT++))
            
            MMD_FILE="$TEMP_DIR/${BASE_CHAPTER}-diagram-${DIAGRAM_COUNT}.mmd"
            PNG_FILE="$OUTPUT_DIR/${BASE_CHAPTER}-diagram-${DIAGRAM_COUNT}.png"
            
            echo "$MERMAID_CONTENT" > "$MMD_FILE"
            
            echo "  Rendering diagram $DIAGRAM_COUNT..."
            mmdc -i "$MMD_FILE" -o "$PNG_FILE" -c mermaid-config.json -w 1800 -b transparent -q
            
            if [ $? -eq 0 ]; then
                echo "    ✓ Created: $PNG_FILE"
            else
                echo "    ✗ Failed to render diagram $DIAGRAM_COUNT"
            fi
            
            IN_MERMAID=false
            MERMAID_CONTENT=""
        else
            MERMAID_CONTENT="${MERMAID_CONTENT}${line}"$'\n'
        fi
    fi
done < "$INPUT_FILE"

echo ""
echo "Extracted $DIAGRAM_COUNT diagrams from $CHAPTER_NAME"
