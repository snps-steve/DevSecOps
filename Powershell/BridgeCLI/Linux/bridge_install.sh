#!/bin/bash
# ============================================================
# Bridge CLI - Linux Installation Script
# ============================================================
# This script downloads and installs Bridge CLI on Linux
# For use in Azure DevOps pipelines on Linux agents
# ============================================================

set -e  # Exit on error
set -u  # Exit on undefined variable

# Configuration
BRIDGE_VERSION="${BRIDGE_VERSION:-latest}"
INSTALL_DIR="${AGENT_TEMPDIRECTORY:-.}"

echo "========================================"
echo "Bridge CLI Linux Installation"
echo "========================================"

# Define download URL
BRIDGE_URL="https://repo.blackduck.com/bds-integrations-release/com/blackduck/integration/bridge/binaries/bridge-cli-thin-client/${BRIDGE_VERSION}/bridge-cli-linux64.zip"

# Create installation directory if it doesn't exist
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

echo ""
echo "Downloading Bridge CLI from: $BRIDGE_URL"

# Download Bridge CLI
if command -v curl >/dev/null 2>&1; then
    curl -fLsS -o bridge-cli-linux64.zip "$BRIDGE_URL"
elif command -v wget >/dev/null 2>&1; then
    wget -q -O bridge-cli-linux64.zip "$BRIDGE_URL"
else
    echo "Error: Neither curl nor wget is available"
    exit 1
fi

echo "✓ Download completed successfully"

# Extract the archive
echo ""
echo "Extracting Bridge CLI..."
unzip -qo bridge-cli-linux64.zip

# Clean up zip file
rm -f bridge-cli-linux64.zip
echo "✓ Extraction completed"

# Set executable permissions
chmod +x bridge-cli-bundle-linux64/bridge-cli
echo "✓ Permissions set"

# Verify installation
echo ""
echo "Verifying Bridge CLI installation..."
BRIDGE_CLI_PATH="${INSTALL_DIR}/bridge-cli-bundle-linux64/bridge-cli"

if [ -f "$BRIDGE_CLI_PATH" ]; then
    VERSION=$("$BRIDGE_CLI_PATH" --version 2>&1 || true)
    echo "✓ Bridge CLI installed successfully!"
    echo "Version: $VERSION"
    echo "Location: $BRIDGE_CLI_PATH"
else
    echo "✗ Bridge CLI executable not found at expected location"
    exit 1
fi

echo ""
echo "========================================"
echo "Installation Complete!"
echo "========================================"
