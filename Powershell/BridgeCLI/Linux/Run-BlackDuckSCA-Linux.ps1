<#
.SYNOPSIS
    Executes Black Duck SCA scan using Bridge CLI on Linux
    
.DESCRIPTION
    This script runs a Black Duck SCA security scan using the Bridge CLI.
    It supports both full scans and pull request scans with automated PR comments.
    Designed for PowerShell Core on Linux.
    
.PARAMETER BridgeCliPath
    Path to the Bridge CLI executable (default: from BRIDGE_CLI_PATH environment variable)
    
.PARAMETER BlackDuckUrl
    URL of the Black Duck server
    
.PARAMETER BlackDuckToken
    API token for Black Duck authentication
    
.PARAMETER ProjectName
    Name of the project to scan
    
.PARAMETER ProjectVersion
    Version/branch name for the project
    
.PARAMETER ScanMode
    Scan mode: 'full' or 'pr' (default: full)
    
.EXAMPLE
    pwsh ./Run-BlackDuckSCA-Linux.ps1 -BlackDuckUrl "https://blackduck.example.com" -BlackDuckToken "your-token" -ProjectName "MyApp" -ProjectVersion "main"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$BridgeCliPath = $env:BRIDGE_CLI_PATH,
    
    [Parameter(Mandatory=$true)]
    [string]$BlackDuckUrl,
    
    [Parameter(Mandatory=$true)]
    [string]$BlackDuckToken,
    
    [Parameter(Mandatory=$true)]
    [string]$ProjectName,
    
    [Parameter(Mandatory=$true)]
    [string]$ProjectVersion,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet('full', 'pr')]
    [string]$ScanMode = 'full',
    
    [Parameter(Mandatory=$false)]
    [string]$AzureToken = $env:SYSTEM_ACCESSTOKEN,
    
    [Parameter(Mandatory=$false)]
    [switch]$TrustAllCertificates
)

$ErrorActionPreference = "Continue"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Black Duck SCA Scan - Linux" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

try {
    # Validate Bridge CLI path
    if (-not $BridgeCliPath -or -not (Test-Path -Path $BridgeCliPath)) {
        throw "Bridge CLI not found. Please install Bridge CLI first or provide valid path."
    }
    
    Write-Host "Bridge CLI Path: $BridgeCliPath" -ForegroundColor Green
    Write-Host "Black Duck URL: $BlackDuckUrl" -ForegroundColor Green
    Write-Host "Project Name: $ProjectName" -ForegroundColor Green
    Write-Host "Project Version: $ProjectVersion" -ForegroundColor Green
    Write-Host "Scan Mode: $ScanMode" -ForegroundColor Green
    Write-Host ""
    
    # Set common environment variables
    $env:BRIDGE_BLACKDUCKSCA_URL = $BlackDuckUrl
    $env:BRIDGE_BLACKDUCKSCA_TOKEN = $BlackDuckToken
    $env:DETECT_PROJECT_NAME = $ProjectName
    $env:DETECT_PROJECT_VERSION_NAME = $ProjectVersion
    $env:DETECT_CODE_LOCATION_NAME = "$ProjectName-$ProjectVersion"
    $env:DETECT_BLACKDUCK_TIMEOUT = "900"
    $env:DETECT_API_TIMEOUT = "300000"
    $env:BLACKDUCK_TIMEOUT = "900"
    $env:INCLUDE_DIAGNOSTICS = "true"
    
    # Configure scan mode specific settings
    if ($ScanMode -eq 'pr') {
        Write-Host "Configuring Pull Request Scan..." -ForegroundColor Yellow
        $env:BRIDGE_BLACKDUCKSCA_SCAN_FULL = "false"
        $env:BRIDGE_BLACKDUCKSCA_AUTOMATION_PRCOMMENT = "true"
        
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
    } else {
        Write-Host "Configuring Full Scan..." -ForegroundColor Yellow
        $env:BRIDGE_BLACKDUCKSCA_SCAN_FULL = "true"
    }
    
    Write-Host ""
    
    # Test Black Duck connectivity using curl
    Write-Host "Testing Black Duck connectivity..." -ForegroundColor Yellow
    try {
        $curlTest = curl -I -s -m 30 $BlackDuckUrl 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Connectivity test: SUCCESS" -ForegroundColor Green
        } else {
            Write-Host "Warning: Connectivity test failed" -ForegroundColor Yellow
            Write-Host "Continuing with scan..." -ForegroundColor Yellow
        }
    } catch {
        Write-Host "Warning: Connectivity test failed - $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "Continuing with scan..." -ForegroundColor Yellow
    }
    Write-Host ""
    
    # Build Bridge CLI arguments
    $bridgeArgs = @(
        '--stage', 'blackducksca'
    )
    
    if ($TrustAllCertificates) {
        $bridgeArgs += 'network.ssl.trustAll=true'
    }
    
    # Make Bridge CLI executable
    chmod +x $BridgeCliPath 2>&1 | Out-Null
    
    # Execute Bridge CLI
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host "Starting Black Duck SCA Scan..." -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host ""
    
    # Use bash -c to execute with timeout
    $command = "timeout 1800 '$BridgeCliPath' " + ($bridgeArgs -join ' ')
    $exitCode = bash -c $command
    $exitCode = $LASTEXITCODE
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    
    if ($exitCode -eq 0) {
        Write-Host "Black Duck SCA Scan Completed Successfully!" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
        Write-Host ""
        exit 0
    } else {
        Write-Host "Black Duck SCA Scan Failed!" -ForegroundColor Yellow
        Write-Host "Exit Code: $exitCode" -ForegroundColor Yellow
        Write-Host "========================================" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Note: Scan may have completed with findings. Check Black Duck server for results." -ForegroundColor Yellow
        exit $exitCode
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
