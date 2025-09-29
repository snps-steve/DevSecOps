#!/bin/bash

# Define the download URL for Bridge CLI
BRIDGE_CLI_URL="https://github.com/bridgecrewio/bridgecrew-cli/releases/latest/download/bridgecrew"

# Define the installation directory
INSTALL_DIR="/usr/local/bin"

# Download the Bridge CLI
echo "Downloading Bridge CLI from $BRIDGE_CLI_URL..."
curl -L $BRIDGE_CLI_URL -o bridgecrew

# Make the CLI executable
chmod +x bridgecrew

# Move the CLI to the installation directory
sudo mv bridgecrew $INSTALL_DIR/

# Verify installation
if command -v bridgecrew &> /dev/null; then
    echo "Bridge CLI installed successfully."
else
    echo "Bridge CLI installation failed."
fi
