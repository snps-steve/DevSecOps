<#
.SYNOPSIS
    Downloads and installs Bridge CLI on Windows for Azure DevOps pipelines
    
.DESCRIPTION
    This script downloads the Bridge CLI from the Black Duck repository and 
    extracts it to a specified location for use in Azure DevOps pipelines.
    
.PARAMETER InstallDirectory
    The directory where Bridge CLI will be installed (default: agent temp directory)
    
.PARAMETER BridgeVersion
    The version of Bridge CLI to download (default: latest)
    
.EXAMPLE
    .\Install-BridgeCLI-Windows.ps1
    
.EXAMPLE
    .\Install-BridgeCLI-Windows.ps1 -InstallDirectory "C:\tools\bridge" -BridgeVersion "latest"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$InstallDirectory = $env:AGENT_TEMPDIRECTORY,
    
    [Parameter(Mandatory=$false)]
    [string]$BridgeVersion = "latest"
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Bridge CLI download URLs
$BridgeBaseUrl = "https://repo.blackduck.com/bds-integrations-release/com/blackduck/integration/bridge/binaries/bridge-cli-thin-client"

# Determine download URL based on version
if ($BridgeVersion -eq "latest") {
    $DownloadUrl = "$BridgeBaseUrl/latest/bridge-cli-win64.zip"
} else {
    $DownloadUrl = "$BridgeBaseUrl/$BridgeVersion/bridge-cli-win64.zip"
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Bridge CLI Installation Script - Windows" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

try {
    # Create installation directory if it doesn't exist
    if (-not (Test-Path -Path $InstallDirectory)) {
        Write-Host "Creating installation directory: $InstallDirectory" -ForegroundColor Yellow
        New-Item -ItemType Directory -Path $InstallDirectory -Force | Out-Null
    }
    
    Write-Host "Installation Directory: $InstallDirectory" -ForegroundColor Green
    Write-Host "Bridge CLI Version: $BridgeVersion" -ForegroundColor Green
    Write-Host "Download URL: $DownloadUrl" -ForegroundColor Green
    Write-Host ""
    
    # Download Bridge CLI
    $ZipPath = Join-Path -Path $InstallDirectory -ChildPath "bridge-cli-win64.zip"
    Write-Host "Downloading Bridge CLI..." -ForegroundColor Yellow
    
    # Use TLS 1.2 for secure download
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $ZipPath -UseBasicParsing
    Write-Host "Download completed successfully!" -ForegroundColor Green
    Write-Host ""
    
    # Extract Bridge CLI
    Write-Host "Extracting Bridge CLI..." -ForegroundColor Yellow
    Expand-Archive -Path $ZipPath -DestinationPath $InstallDirectory -Force
    Write-Host "Extraction completed successfully!" -ForegroundColor Green
    Write-Host ""
    
    # Clean up zip file
    Remove-Item -Path $ZipPath -Force
    Write-Host "Cleaned up temporary files" -ForegroundColor Green
    Write-Host ""
    
    # Verify installation
    $BridgeExePath = Join-Path -Path $InstallDirectory -ChildPath "bridge-cli-bundle-win64\bridge-cli.exe"
    
    if (Test-Path -Path $BridgeExePath) {
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "Bridge CLI installed successfully!" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "Executable Location: $BridgeExePath" -ForegroundColor Cyan
        Write-Host ""
        
        # Display version information
        Write-Host "Bridge CLI Version Information:" -ForegroundColor Cyan
        & $BridgeExePath --version
        Write-Host ""
        
        # Set pipeline variable for Azure DevOps (if running in pipeline)
        if ($env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI) {
            Write-Host "##vso[task.setvariable variable=BRIDGE_CLI_PATH]$BridgeExePath"
            Write-Host "Pipeline variable BRIDGE_CLI_PATH set to: $BridgeExePath" -ForegroundColor Cyan
        }
        
    } else {
        throw "Bridge CLI executable not found at expected location: $BridgeExePath"
    }
    
} catch {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "ERROR: Installation Failed!" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""
    exit 1
}
