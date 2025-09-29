# Set variables
$baseUrl = "https://repo.blackduck.com/bds-integrations-release/com/blackduck/integration/bridge/binaries/bridge-cli-thin-client/latest/"
$zipFile = "bridge-cli-linux64.zip"
$downloadUrl = "$baseUrl/$zipFile"
$installDir = "$env:ProgramFiles\BridgeCLI"
$zipPath = "$env:TEMP\$zipFile"

# Create install directory if it doesn't exist
if (-not (Test-Path $installDir)) {
    New-Item -ItemType Directory -Path $installDir | Out-Null
}

# Download the ZIP file
Write-Host "Downloading Bridge CLI for Linux 64 bit OS from $downloadUrl..."
Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath

# Extract the ZIP contents
Write-Host "Extracting Bridge CLI for Linux 64 bit OS to $installDir..."
Expand-Archive -Path $zipPath -DestinationPath $installDir -Force
# Optionally add to PATH (for current user)
$envPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
if ($envPath -notlike "*$installDir*") {
    [System.Environment]::SetEnvironmentVariable("Path", "$envPath;$installDir", "User")
    Write-Host "Bridge CLI path added to user environment PATH."
}

# Cleanup
Remove-Item $zipPath

# Confirm installation
$exePath = Join-Path $installDir "bridge.exe"
if (Test-Path $exePath) {
    Write-Host "Bridge CLI installed successfully at $exePath"
} else {
    Write-Host "Installation failed."
}
