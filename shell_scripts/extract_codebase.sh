#!/bin/zsh

# Require source and output arguments
if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <source_path> <output_file>"
  exit 1
fi

src_path="$1"
output_file="$2"

# Run the find command
find "$src_path" -type f \( -name "*.tsx" -o -name "*.ts" -o -name "*.jsx" -o -name "*.js" -o -name "*.css" \) \
  -not -path "*/node_modules/*" -not -path "*/.next/*" \
  -exec echo "=== {} ===" \; -exec cat {} \; > "$output_file"

# Confirm output
echo "✅ Codebase saved to $output_file"
