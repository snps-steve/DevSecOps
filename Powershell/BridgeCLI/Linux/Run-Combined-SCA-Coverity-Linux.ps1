<#
.SYNOPSIS
    Executes both Black Duck SCA and Coverity scans using Bridge CLI on Linux
    
.DESCRIPTION
    This script runs both Black Duck SCA and Coverity scans in sequence using the Bridge CLI.
    It supports both full scans and pull request scans with automated PR comments.
    Designed for PowerShell Core on Linux.
    
.EXAMPLE
    pwsh ./Run-Combined-SCA-Coverity-Linux.ps1 -BlackDuckUrl "https://bd.example.com" -BlackDuckToken "token" -CoverityUrl "https://cov.example.com" -CoverityUser "admin" -CoverityPassword "pass" -ProjectName "MyApp" -ProjectVersion "main" -StreamName "MyApp-main"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$BridgeCliPath = $env:BRIDGE_CLI_PATH,
    
    # Black Duck Parameters
    [Parameter(Mandatory=$true)]
    [string]$BlackDuckUrl,
    
    [Parameter(Mandatory=$true)]
    [string]$BlackDuckToken,
    
    # Coverity Parameters
    [Parameter(Mandatory=$true)]
    [string]$CoverityUrl,
    
    [Parameter(Mandatory=$true)]
    [string]$CoverityUser,
    
    [Parameter(Mandatory=$true)]
    [string]$CoverityPassword,
    
    # Common Parameters
    [Parameter(Mandatory=$true)]
    [string]$ProjectName,
    
    [Parameter(Mandatory=$true)]
    [string]$ProjectVersion,
    
    [Parameter(Mandatory=$true)]
    [string]$StreamName,
    
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
Write-Host "Combined SCA + Coverity Scan - Linux" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

try {
    # Validate Bridge CLI path
    if (-not $BridgeCliPath -or -not (Test-Path -Path $BridgeCliPath)) {
        throw "Bridge CLI not found. Please install Bridge CLI first or provide valid path."
    }
    
    Write-Host "Bridge CLI Path: $BridgeCliPath" -ForegroundColor Green
    Write-Host "Project Name: $ProjectName" -ForegroundColor Green
    Write-Host "Project Version: $ProjectVersion" -ForegroundColor Green
    Write-Host "Scan Mode: $ScanMode" -ForegroundColor Green
    Write-Host ""
    
    # Set Black Duck environment variables
    $env:BRIDGE_BLACKDUCKSCA_URL = $BlackDuckUrl
    $env:BRIDGE_BLACKDUCKSCA_TOKEN = $BlackDuckToken
    $env:DETECT_PROJECT_NAME = $ProjectName
    $env:DETECT_PROJECT_VERSION_NAME = $ProjectVersion
    $env:DETECT_CODE_LOCATION_NAME = "$ProjectName-$ProjectVersion"
    $env:DETECT_BLACKDUCK_TIMEOUT = "900"
    $env:DETECT_API_TIMEOUT = "300000"
    $env:BLACKDUCK_TIMEOUT = "900"
    
    # Set Coverity environment variables
    $env:BRIDGE_COVERITY_CONNECT_URL = $CoverityUrl
    $env:BRIDGE_COVERITY_CONNECT_USER_NAME = $CoverityUser
    $env:BRIDGE_COVERITY_CONNECT_USER_PASSWORD = $CoverityPassword
    $env:BRIDGE_COVERITY_CONNECT_PROJECT_NAME = $ProjectName
    $env:BRIDGE_COVERITY_CONNECT_STREAM_NAME = $StreamName
    
    # Common settings
    $env:INCLUDE_DIAGNOSTICS = "true"
    
    # Configure scan mode specific settings
    if ($ScanMode -eq 'pr') {
        Write-Host "Configuring Pull Request Scan..." -ForegroundColor Yellow
        
        # Black Duck PR settings
        $env:BRIDGE_BLACKDUCKSCA_SCAN_FULL = "false"
        $env:BRIDGE_BLACKDUCKSCA_AUTOMATION_PRCOMMENT = "true"
        
        # Coverity PR settings
        $env:BRIDGE_COVERITY_AUTOMATION_PRCOMMENT = "true"
        $env:BRIDGE_COVERITY_LOCAL = "true"
        
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
        }
    } else {
        Write-Host "Configuring Full Scan..." -ForegroundColor Yellow
        $env:BRIDGE_BLACKDUCKSCA_SCAN_FULL = "true"
    }
    
    Write-Host ""
    
    # Build Bridge CLI arguments for combined scan
    $bridgeArgs = @(
        '--stage', 'blackducksca',
        '--stage', 'connect'
    )
    
    if ($TrustAllCertificates) {
        $bridgeArgs += 'network.ssl.trustAll=true'
    }
    
    # Make Bridge CLI executable
    chmod +x $BridgeCliPath 2>&1 | Out-Null
    
    # Execute Bridge CLI with both stages
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host "Starting Combined Security Scan..." -ForegroundColor Yellow
    Write-Host "  - Black Duck SCA" -ForegroundColor Yellow
    Write-Host "  - Coverity SAST" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host ""
    
    # Use bash -c to execute with timeout
    $command = "timeout 1800 '$BridgeCliPath' " + ($bridgeArgs -join ' ')
    $exitCode = bash -c $command
    $exitCode = $LASTEXITCODE
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    
    if ($exitCode -eq 0) {
        Write-Host "Combined Security Scan Completed Successfully!" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "Review scan results:" -ForegroundColor Cyan
        Write-Host "  Black Duck: $BlackDuckUrl" -ForegroundColor Cyan
        Write-Host "  Coverity: $CoverityUrl" -ForegroundColor Cyan
        Write-Host ""
        exit 0
    } else {
        Write-Host "Combined Security Scan Completed with Issues!" -ForegroundColor Yellow
        Write-Host "Exit Code: $exitCode" -ForegroundColor Yellow
        Write-Host "========================================" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Note: Check both Black Duck and Coverity servers for detailed results." -ForegroundColor Yellow
        exit $exitCode
    }
    
} catch {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "ERROR: Combined Scan Failed!" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
}
