# ============================================================
# Bridge CLI - Black Duck SCA Scan (PowerShell)
# ============================================================
# This script performs a Black Duck SCA scan using Bridge CLI
# Supports both PR scans and full scans
# ============================================================

param(
    [string]$BridgePath = "$env:AGENT_TEMPDIRECTORY\bridge-cli-bundle-win64\bridge-cli.exe",
    [string]$BlackDuckUrl = $env:BLACKDUCK_URL,
    [string]$BlackDuckToken = $env:BLACKDUCK_API_TOKEN,
    [string]$ProjectName = $env:BUILD_REPOSITORY_NAME,
    [string]$ProjectVersion = $env:BUILD_SOURCEBRANCHNAME,
    [bool]$IsPullRequest = ($env:BUILD_REASON -eq "PullRequest")
)

$ErrorActionPreference = "Continue"  # Continue on error for scans

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Black Duck SCA Scan with Bridge CLI" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Validate required parameters
if (-not $BlackDuckUrl) {
    Write-Host "✗ BLACKDUCK_URL is not set" -ForegroundColor Red
    exit 1
}

if (-not $BlackDuckToken) {
    Write-Host "✗ BLACKDUCK_API_TOKEN is not set" -ForegroundColor Red
    exit 1
}

Write-Host "`nScan Configuration:" -ForegroundColor Yellow
Write-Host "  Project Name: $ProjectName"
Write-Host "  Project Version: $ProjectVersion"
Write-Host "  Black Duck URL: $BlackDuckUrl"
Write-Host "  Scan Type: $(if ($IsPullRequest) { 'Pull Request Scan' } else { 'Full Scan' })"

# Set Bridge CLI environment variables
$env:BRIDGE_BLACKDUCKSCA_URL = $BlackDuckUrl
$env:BRIDGE_BLACKDUCKSCA_TOKEN = $BlackDuckToken
$env:DETECT_PROJECT_NAME = $ProjectName
$env:DETECT_PROJECT_VERSION_NAME = $ProjectVersion
$env:DETECT_CODE_LOCATION_NAME = "$ProjectName-$ProjectVersion"

# Configure scan type
if ($IsPullRequest) {
    Write-Host "`nConfiguring Pull Request scan..." -ForegroundColor Yellow
    $env:BRIDGE_BLACKDUCKSCA_SCAN_FULL = "false"
    $env:BRIDGE_BLACKDUCKSCA_AUTOMATION_PRCOMMENT = "true"
    
    # Azure DevOps PR-specific configuration
    $env:BRIDGE_AZURE_USER_TOKEN = $env:AZURE_PERSONAL_ACCESS_TOKEN
    $env:BRIDGE_AZURE_ORGANIZATION_NAME = $env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI -replace 'https://dev.azure.com/', '' -replace '/', ''
    $env:BRIDGE_AZURE_REPOSITORY_NAME = $env:BUILD_REPOSITORY_NAME
    $env:BRIDGE_AZURE_PROJECT_NAME = $env:SYSTEM_TEAMPROJECT
    $env:BRIDGE_AZURE_REPOSITORY_BRANCH_NAME = $env:SYSTEM_PULLREQUEST_SOURCEBRANCH
    $env:BRIDGE_AZURE_REPOSITORY_PULL_NUMBER = $env:SYSTEM_PULLREQUEST_PULLREQUESTID
    $env:BRIDGE_AZURE_API_VERSION = "7.0"
    $env:BRIDGE_AZURE_API_URL = "https://dev.azure.com"
} else {
    Write-Host "`nConfiguring full scan..." -ForegroundColor Yellow
    $env:BRIDGE_BLACKDUCKSCA_SCAN_FULL = "true"
    
    # Optional: Configure Fix PR settings for full scans
    $env:BRIDGE_BLACKDUCKSCA_FIXPR_ENABLED = "true"
    $env:BRIDGE_BLACKDUCKSCA_FIXPR_MAXCOUNT = "5"
    $env:BRIDGE_BLACKDUCKSCA_FIXPR_FILTER_SEVERITIES = "CRITICAL,HIGH"
}

# Additional Black Duck configuration
$env:DETECT_BLACKDUCK_TIMEOUT = "900"
$env:DETECT_API_TIMEOUT = "300000"
$env:BLACKDUCK_TIMEOUT = "900"
$env:INCLUDE_DIAGNOSTICS = "true"

# Test connectivity
Write-Host "`nTesting Black Duck connectivity..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri $BlackDuckUrl -Method Head -TimeoutSec 30 -UseBasicParsing
    Write-Host "✓ Connectivity test passed" -ForegroundColor Green
} catch {
    Write-Host "⚠ Warning: Connectivity test failed - $($_.Exception.Message)" -ForegroundColor Yellow
}

# Run Bridge CLI scan
Write-Host "`nExecuting Black Duck SCA scan..." -ForegroundColor Yellow
Write-Host "Command: $BridgePath --stage blackducksca" -ForegroundColor Gray

try {
    & $BridgePath --stage blackducksca
    $exitCode = $LASTEXITCODE
    
    if ($exitCode -eq 0) {
        Write-Host "`n✓ Black Duck SCA scan completed successfully!" -ForegroundColor Green
    } else {
        Write-Host "`n⚠ Black Duck SCA scan completed with exit code: $exitCode" -ForegroundColor Yellow
    }
} catch {
    Write-Host "`n✗ Black Duck SCA scan failed: $_" -ForegroundColor Red
    exit 1
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Scan Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
