#!/bin/bash

# Set the script name, location, and download URL
script_name="chatgpt"
script_url="https://raw.githubusercontent.com/aamirrasheed/chatgpt-terminal/main/chatgpt.sh"
install_dir="$HOME/.local/bin"

# Create the installation directory if it doesn't exist
mkdir -p "$install_dir"

# Download the script from GitHub
curl -sSL "$script_url" -o "$install_dir/$script_name"

# Set the right permissions for the script
chmod +x "$install_dir/$script_name"

# Add an alias to the user's shell configuration file
echo "alias $script_name=\"$install_dir/$script_name\"" >> "$HOME/.zshrc"

# Source the shell configuration file
source "$HOME/.zshrc"

echo "Installation complete. You can now use the '$script_name' command."
