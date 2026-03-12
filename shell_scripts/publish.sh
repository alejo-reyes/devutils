#!/bin/bash

# Publish Script
# Symlinks shell scripts to ~/.local/bin and ensures it's in PATH

set -e

SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
LOCAL_BIN="$HOME/.local/bin"
SCRIPTS_TO_PUBLISH=(
    "chrome-inject.sh"
    "compare-folders.sh"
    "device-switch.sh"
)

echo "Publishing shell scripts to $LOCAL_BIN"
echo "======================================"

# Create ~/.local/bin if it doesn't exist
if [ ! -d "$LOCAL_BIN" ]; then
    echo "Creating directory: $LOCAL_BIN"
    mkdir -p "$LOCAL_BIN"
else
    echo "Directory already exists: $LOCAL_BIN"
fi

# Symlink scripts
echo ""
echo "Checking symlinks..."
for script in "${SCRIPTS_TO_PUBLISH[@]}"; do
    script_path="$SCRIPTS_DIR/$script"
    # create link name without .sh extension
    link_name="$(basename "$script" .sh)"
    link_path="$LOCAL_BIN/$link_name"
    
    # Check if script exists
    if [ ! -f "$script_path" ]; then
        echo "⚠ WARNING: Script not found: $script_path"
        continue
    fi
    
    # Check if symlink already exists and points to correct location
    if [ -L "$link_path" ]; then
        current_target=$(readlink "$link_path")
        if [ "$current_target" = "$script_path" ]; then
            echo "✓ Already symlinked: $link_name (-> $script)"
        else
            echo "! Symlink exists but points elsewhere, removing and recreating: $script"
            rm "$link_path"
            ln -s "$script_path" "$link_path"
            echo "✓ Symlinked: $link_name (-> $script)"
        fi
    elif [ -f "$link_path" ]; then
        echo "! Regular file exists at $link_path, backing up and symlinking"
        mv "$link_path" "$link_path.backup"
        ln -s "$script_path" "$link_path"
        echo "✓ Symlinked: $link_name (-> $script) (backed up original to $link_path.backup)"
    else
        echo "✓ Creating symlink: $link_name -> $script"
        ln -s "$script_path" "$link_path"
    fi
done

# Check if ~/.local/bin is in PATH
echo ""
echo "Checking PATH..."
if [[ ":$PATH:" == *":$LOCAL_BIN:"* ]]; then
    echo "✓ $LOCAL_BIN is already in PATH"
else
    echo "! $LOCAL_BIN is not in PATH, adding to .zshrc"
    
    # Check if .zshrc exists
    zshrc_file="$HOME/.zshrc"
    if [ ! -f "$zshrc_file" ]; then
        echo "Creating $zshrc_file"
        touch "$zshrc_file"
    fi
    
    # Add to PATH if not already there (check file content, not runtime PATH)
    if grep -q "export PATH.*\.local/bin" "$zshrc_file"; then
        echo "✓ PATH entry already exists in .zshrc"
    else
        echo "# Added by devutils publish script" >> "$zshrc_file"
        echo "export PATH=\"\$HOME/.local/bin:\$PATH\"" >> "$zshrc_file"
        echo "✓ Added $LOCAL_BIN to PATH in .zshrc"
        echo ""
        echo "⚠ Please restart your terminal or run: source ~/.zshrc"
    fi
fi

echo ""
echo "======================================"
echo "✓ Publishing complete!"
echo ""
echo "You can now run the scripts from anywhere:"
for script in "${SCRIPTS_TO_PUBLISH[@]}"; do
    echo "  $(basename "$script" .sh)"
done
