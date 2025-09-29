<#
.SYNOPSIS
    Executes Coverity scan using Bridge CLI on Windows
    
.DESCRIPTION
    This script runs a Coverity static analysis scan using the Bridge CLI.
    It supports both full scans and pull request scans with automated PR comments.
    
.PARAMETER BridgeCliPath
    Path to the Bridge CLI executable (default: from BRIDGE_CLI_PATH environment variable)
    
.PARAMETER CoverityUrl
    URL of the Coverity Connect server
    
.PARAMETER CoverityUser
    Username for Coverity Connect authentication
    
.PARAMETER CoverityPassword
    Password for Coverity Connect authentication
    
.PARAMETER ProjectName
    Name of the Coverity project
    
.PARAMETER StreamName
    Name of the Coverity stream
    
.PARAMETER ScanMode
    Scan mode: 'full' or 'pr' (default: full)
    
.PARAMETER LocalScan
    Use local scan mode (faster, suitable for PR scans)
    
.EXAMPLE
    .\Run-Coverity-Windows.ps1 -CoverityUrl "https://coverity.example.com" -CoverityUser "admin" -CoverityPassword "password" -ProjectName "MyApp" -StreamName "MyApp-main"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$BridgeCliPath = $env:BRIDGE_CLI_PATH,
    
    [Parameter(Mandatory=$true)]
    [string]$CoverityUrl,
    
    [Parameter(Mandatory=$true)]
    [string]$CoverityUser,
    
    [Parameter(Mandatory=$true)]
    [string]$CoverityPassword,
    
    [Parameter(Mandatory=$true)]
    [string]$ProjectName,
    
    [Parameter(Mandatory=$true)]
    [string]$StreamName,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet('full', 'pr')]
    [string]$ScanMode = 'full',
    
    [Parameter(Mandatory=$false)]
    [switch]$LocalScan,
    
    [Parameter(Mandatory=$false)]
    [string]$AzureToken = $env:SYSTEM_ACCESSTOKEN,
    
    [Parameter(Mandatory=$false)]
    [switch]$TrustAllCertificates
)

$ErrorActionPreference = "Continue"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Coverity Scan - Windows" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

try {
    # Validate Bridge CLI path
    if (-not $BridgeCliPath -or -not (Test-Path -Path $BridgeCliPath)) {
        throw "Bridge CLI not found. Please install Bridge CLI first or provide valid path."
    }
    
    Write-Host "Bridge CLI Path: $BridgeCliPath" -ForegroundColor Green
    Write-Host "Coverity URL: $CoverityUrl" -ForegroundColor Green
    Write-Host "Project Name: $ProjectName" -ForegroundColor Green
    Write-Host "Stream Name: $StreamName" -ForegroundColor Green
    Write-Host "Scan Mode: $ScanMode" -ForegroundColor Green
    Write-Host "Local Scan: $($LocalScan.IsPresent)" -ForegroundColor Green
    Write-Host ""
    
    # Set common environment variables
    $env:BRIDGE_COVERITY_CONNECT_URL = $CoverityUrl
    $env:BRIDGE_COVERITY_CONNECT_USER_NAME = $CoverityUser
    $env:BRIDGE_COVERITY_CONNECT_USER_PASSWORD = $CoverityPassword
    $env:BRIDGE_COVERITY_CONNECT_PROJECT_NAME = $ProjectName
    $env:BRIDGE_COVERITY_CONNECT_STREAM_NAME = $StreamName
    
    # Set local scan mode if specified
    if ($LocalScan) {
        $env:BRIDGE_COVERITY_LOCAL = "true"
        Write-Host "Using local scan mode (faster analysis)" -ForegroundColor Cyan
    }
    
    # Configure scan mode specific settings
    if ($ScanMode -eq 'pr') {
        Write-Host "Configuring Pull Request Scan..." -ForegroundColor Yellow
        $env:BRIDGE_COVERITY_AUTOMATION_PRCOMMENT = "true"
        
        # Azure DevOps PR Configuration
        if ($env:BUILD_REASON -eq 'PullRequest') {
            $env:BRIDGE_AZURE_USER_TOKEN = $AzureToken
            $env:BRIDGE_AZURE_ORGANIZATION_NAME = ($env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI -split '/' | Where-Object { $_ -ne '' })[-1]
            $env:BRIDGE_AZURE_REPOSITORY_NAME = $env:BUILD_REPOSITORY_NAME
            $env:BRIDGE_AZURE_PROJECT_NAME = $env:SYSTEM_TEAMPROJECT
            $env:BRIDGE_AZURE_REPOSITORY_BRANCH_NAME = $env:SYSTEM_PULLREQUEST_SOURCEBRANCH
            $env:BRIDGE_AZURE_REPOSITORY_PULL_NUMBER = $env:SYSTEM_PULLREQUEST_PULLREQUESTID
            $env:BRIDGE_AZURE_API_VERSION = "7.0"
            $env:BRIDGE_AZURE_API_URL = "https://dev.azure.com"
            
            Write-Host "PR Number: $env:SYSTEM_PULLREQUEST_PULLREQUESTID" -ForegroundColor Cyan
            Write-Host "Source Branch: $env:SYSTEM_PULLREQUEST_SOURCEBRANCH" -ForegroundColor Cyan
        }
        
        # For PR scans, always use local mode
        $env:BRIDGE_COVERITY_LOCAL = "true"
    }
    
    Write-Host ""
    
    # Test Coverity connectivity
    Write-Host "Testing Coverity Connect connectivity..." -ForegroundColor Yellow
    try {
        $response = Invoke-WebRequest -Uri $CoverityUrl -Method Head -TimeoutSec 30 -UseBasicParsing -ErrorAction SilentlyContinue
        Write-Host "Connectivity test: SUCCESS" -ForegroundColor Green
    } catch {
        Write-Host "Warning: Connectivity test failed - $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "Continuing with scan..." -ForegroundColor Yellow
    }
    Write-Host ""
    
    # Build Bridge CLI arguments
    $bridgeArgs = @(
        '--stage', 'connect'
    )
    
    if ($TrustAllCertificates) {
        $bridgeArgs += 'network.ssl.trustAll=true'
    }
    
    # Execute Bridge CLI
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host "Starting Coverity Scan..." -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host ""
    
    $process = Start-Process -FilePath $BridgeCliPath `
                            -ArgumentList $bridgeArgs `
                            -NoNewWindow `
                            -Wait `
                            -PassThru
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    
    if ($process.ExitCode -eq 0) {
        Write-Host "Coverity Scan Completed Successfully!" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
        Write-Host ""
        exit 0
    } else {
        Write-Host "Coverity Scan Failed!" -ForegroundColor Yellow
        Write-Host "Exit Code: $($process.ExitCode)" -ForegroundColor Yellow
        Write-Host "========================================" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Note: Scan may have completed with findings. Check Coverity Connect for results." -ForegroundColor Yellow
        exit $process.ExitCode
    }
    
} catch {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "ERROR: Scan Failed!" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
}
