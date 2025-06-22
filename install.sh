# Create uvc directory and download the main script
mkdir -p $HOME/.uvc
wget -O $HOME/.uvc/uvc.sh 'https://github.com/LiangYang666/uvc/releases/download/latest/uvc.sh'

enable_uvc='source "$HOME/.uvc/uvc.sh"'

# Check and add to zsh and bash configuration files
added_files=()

# Add to zsh config if it exists
if [[ -f "$HOME/.zshrc" ]]; then
    if ! grep -qxF "$enable_uvc" "$HOME/.zshrc"; then
        echo "$enable_uvc" >> "$HOME/.zshrc"
        added_files+=("$HOME/.zshrc")
    fi
fi

# Add to bash config if it exists
if [[ -f "$HOME/.bashrc" ]]; then
    if ! grep -qxF "$enable_uvc" "$HOME/.bashrc"; then
        echo "$enable_uvc" >> "$HOME/.bashrc"
        added_files+=("$HOME/.bashrc")
    fi
fi

# If neither zsh nor bash config exists, add to profile as fallback
if [[ ${#added_files[@]} -eq 0 ]]; then
    if ! grep -qxF "$enable_uvc" "$HOME/.profile"; then
        echo "$enable_uvc" >> "$HOME/.profile"
        added_files+=("$HOME/.profile")
    fi
fi

# Try to source the first added file to apply changes immediately
if [[ ${#added_files[@]} -gt 0 ]]; then
    source "${added_files[0]}" 2>/dev/null || echo "Please restart your terminal or run: source ${added_files[0]}"
fi

echo "uvc installed successfully!"