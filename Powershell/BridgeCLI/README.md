# Azure DevOps Bridge CLI Integration Guide

This repository contains PowerShell scripts and examples for integrating Black Duck Bridge CLI with Azure DevOps pipelines for security scanning with Black Duck SCA and Coverity.

## 📋 Table of Contents

- [Overview](#-overview)
- [Prerequisites](#-prerequisites)
- [Quick Start](#-quick-start)
- [PowerShell Scripts](#-powershell-scripts)
- [Azure DevOps Pipeline Examples](#-azure-devops-pipeline-examples)
- [Configuration Guide](#-configuration-guide)
- [Official Documentation](#-official-documentation)
- [Troubleshooting](#-troubleshooting)

---

## 🎯 Overview

**Bridge CLI** is a unified command-line tool that integrates Black Duck SCA (Software Composition Analysis) and Coverity SAST (Static Application Security Testing) into your CI/CD pipelines. It provides:

- Single tool for multiple security products
- Native support for Azure DevOps with automated PR comments
- Flexible configuration through environment variables
- Support for both full scans and incremental PR scans

### Integration Options

1. **Security Scan Task** (Azure DevOps Extension)
   - Easiest to configure through UI
   - Pre-built task from Azure Marketplace
   - Internally uses Bridge CLI

2. **Bridge CLI Direct Integration** (This Repository)
   - More control and customization
   - Eliminates one layer of abstraction
   - Better for unified SCA + Coverity workflows
   - Works on both Windows and Linux agents

---

## ✅ Prerequisites

### Required Software

- **Azure DevOps Account** with pipeline permissions
- **PowerShell** (Windows) or **PowerShell Core** (Linux)
- **Black Duck Server** with API access token
- **Coverity Connect Server** with credentials (if using Coverity)

### Required Permissions

- Azure DevOps: Contribute to pull requests, Build service account
- Black Duck: API token with project creation/scanning permissions
- Coverity: User account with commit stream permissions

### Azure DevOps Agent Requirements

#### Windows Agents
- PowerShell 5.1 or later
- .NET Framework 4.7.2 or later
- Internet access to download Bridge CLI

#### Linux Agents
- PowerShell Core 7.0 or later
- `curl` and `unzip` utilities
- Internet access to download Bridge CLI

---

## 🚀 Quick Start

### Step 1: Download Scripts

Clone this repository or download the PowerShell scripts:

```bash
git clone https://github.com/snps-steve/DevSecOps/tree/main/Powershell/BridgeCLI
cd BridgeCLI
```

### Step 2: Install Bridge CLI (Windows)

#### Windows
```powershell
.\Windows\Install-BridgeCLI-Windows.ps1
```

### Step 2: Install Bridge CLI (Linux)

#### Linux (PowerShell Core)
```bash
pwsh ./Linux/Install-BridgeCLI-Linux.ps1
```

### Step 3: Run a Security Scan (Windows)

#### Black Duck SCA Scan
```powershell
.\Windows\Run-BlackDuckSCA-Windows.ps1 `
    -BlackDuckUrl "https://blackduck.example.com" `
    -BlackDuckToken "your-api-token" `
    -ProjectName "MyApplication" `
    -ProjectVersion "main"
```

#### Coverity Scan
```powershell
.\Windows\Run-Coverity-Windows.ps1 `
    -CoverityUrl "https://coverity.example.com" `
    -CoverityUser "admin" `
    -CoverityPassword "password" `
    -ProjectName "MyApplication" `
    -StreamName "MyApplication-main"
```

#### Combined SCA + Coverity Scan
```powershell
.\Windows\Run-Combined-SCA-Coverity-Windows.ps1 `
    -BlackDuckUrl "https://blackduck.example.com" `
    -BlackDuckToken "your-api-token" `
    -CoverityUrl "https://coverity.example.com" `
    -CoverityUser "admin" `
    -CoverityPassword "password" `
    -ProjectName "MyApplication" `
    -ProjectVersion "main" `
    -StreamName "MyApplication-main"
```
### Step 3: Run a Security Scan (Linux)

#### Black Duck SCA Scan
```powershell
.\Linux\Run-BlackDuckSCA-Linux.ps1 `
    -BlackDuckUrl "https://blackduck.example.com" `
    -BlackDuckToken "your-api-token" `
    -ProjectName "MyApplication" `
    -ProjectVersion "main"
```

#### Coverity Scan
```powershell
.\Linux\Run-Coverity-Linux.ps1 `
    -CoverityUrl "https://coverity.example.com" `
    -CoverityUser "admin" `
    -CoverityPassword "password" `
    -ProjectName "MyApplication" `
    -StreamName "MyApplication-main"
```

#### Combined SCA + Coverity Scan
```powershell
.\Linux\Run-Combined-SCA-Coverity-Linux.ps1 `
    -BlackDuckUrl "https://blackduck.example.com" `
    -BlackDuckToken "your-api-token" `
    -CoverityUrl "https://coverity.example.com" `
    -CoverityUser "admin" `
    -CoverityPassword "password" `
    -ProjectName "MyApplication" `
    -ProjectVersion "main" `
    -StreamName "MyApplication-main"
```
---

## 📜 PowerShell Scripts

### Installation Scripts

#### Install-BridgeCLI-Windows.ps1

Downloads and installs Bridge CLI on Windows agents.

**Parameters:**
- `InstallDirectory` (optional): Installation path (default: `$env:AGENT_TEMPDIRECTORY`)
- `BridgeVersion` (optional): Bridge CLI version (default: `latest`)

**Example:**
```powershell
.\Install-BridgeCLI-Windows.ps1 -InstallDirectory "C:\tools\bridge" -BridgeVersion "latest"
```

#### Install-BridgeCLI-Linux.ps1

Downloads and installs Bridge CLI on Linux agents using PowerShell Core.

**Parameters:**
- `InstallDirectory` (optional): Installation path (default: `$env:AGENT_TEMPDIRECTORY`)
- `BridgeVersion` (optional): Bridge CLI version (default: `latest`)

**Example:**
```bash
pwsh ./Install-BridgeCLI-Linux.ps1 -InstallDirectory "/tmp/bridge" -BridgeVersion "latest"
```

### Scan Scripts

#### Run-BlackDuckSCA-Windows.ps1

Executes Black Duck SCA scan using Bridge CLI.

**Parameters:**
- `BridgeCliPath`: Path to Bridge CLI executable
- `BlackDuckUrl`: Black Duck server URL
- `BlackDuckToken`: API authentication token
- `ProjectName`: Project name
- `ProjectVersion`: Version/branch name
- `ScanMode`: `full` or `pr` (default: `full`)
- `TrustAllCertificates`: Skip SSL verification (switch)

**Example:**
```powershell
.\Run-BlackDuckSCA-Windows.ps1 `
    -BlackDuckUrl "https://blackduck.example.com" `
    -BlackDuckToken "your-token" `
    -ProjectName "WebGoat" `
    -ProjectVersion "main" `
    -ScanMode "full"
```

#### Run-Coverity-Windows.ps1

Executes Coverity scan using Bridge CLI.

**Parameters:**
- `BridgeCliPath`: Path to Bridge CLI executable
- `CoverityUrl`: Coverity Connect server URL
- `CoverityUser`: Username for authentication
- `CoverityPassword`: Password for authentication
- `ProjectName`: Coverity project name
- `StreamName`: Coverity stream name
- `ScanMode`: `full` or `pr` (default: `full`)
- `LocalScan`: Use local scan mode (switch)
- `TrustAllCertificates`: Skip SSL verification (switch)

**Example:**
```powershell
.\Run-Coverity-Windows.ps1 `
    -CoverityUrl "https://coverity.example.com" `
    -CoverityUser "admin" `
    -CoverityPassword "password" `
    -ProjectName "WebGoat" `
    -StreamName "WebGoat-main" `
    -LocalScan
```

#### Run-Combined-SCA-Coverity-Windows.ps1

Executes both Black Duck SCA and Coverity scans in a single Bridge CLI invocation.

**Parameters:** Combined parameters from both SCA and Coverity scripts

**Example:**
```powershell
.\Run-Combined-SCA-Coverity-Windows.ps1 `
    -BlackDuckUrl "https://blackduck.example.com" `
    -BlackDuckToken "your-token" `
    -CoverityUrl "https://coverity.example.com" `
    -CoverityUser "admin" `
    -CoverityPassword "password" `
    -ProjectName "WebGoat" `
    -ProjectVersion "main" `
    -StreamName "WebGoat-main"
```

---

## 🔧 Azure DevOps Pipeline Examples

### Example 1: Black Duck SCA Scan (YAML)

```yaml
trigger:
  branches:
    include:
      - main
      - develop

pool:
  vmImage: 'windows-latest'

variables:
  - group: BlackDuck-Credentials  # Variable group with BLACKDUCK_URL and BLACKDUCK_TOKEN

steps:
  - task: PowerShell@2
    displayName: 'Install Bridge CLI'
    inputs:
      filePath: '$(System.DefaultWorkingDirectory)/scripts/Install-BridgeCLI-Windows.ps1'
      
  - task: PowerShell@2
    displayName: 'Black Duck SCA Scan'
    inputs:
      filePath: '$(System.DefaultWorkingDirectory)/scripts/Run-BlackDuckSCA-Windows.ps1'
      arguments: >
        -BlackDuckUrl "$(BLACKDUCK_URL)"
        -BlackDuckToken "$(BLACKDUCK_TOKEN)"
        -ProjectName "$(Build.Repository.Name)"
        -ProjectVersion "$(Build.SourceBranchName)"
        -ScanMode "full"
    continueOnError: true
```

### Example 2: Coverity Scan with PR Comments (YAML)

```yaml
trigger:
  branches:
    include:
      - main

pr:
  branches:
    include:
      - main

pool:
  vmImage: 'ubuntu-latest'

variables:
  - group: Coverity-Credentials

steps:
  - task: PowerShell@2
    displayName: 'Install Bridge CLI'
    inputs:
      filePath: '$(System.DefaultWorkingDirectory)/scripts/Install-BridgeCLI-Linux.ps1'
      pwsh: true
      
  - task: PowerShell@2
    displayName: 'Coverity Scan'
    condition: eq(variables['Build.Reason'], 'PullRequest')
    inputs:
      filePath: '$(System.DefaultWorkingDirectory)/scripts/Run-Coverity-Windows.ps1'
      arguments: >
        -CoverityUrl "$(COVERITY_URL)"
        -CoverityUser "$(COVERITY_USER)"
        -CoverityPassword "$(COVERITY_PASSWORD)"
        -ProjectName "$(Build.Repository.Name)"
        -StreamName "$(Build.Repository.Name)-$(System.PullRequest.TargetBranch)"
        -ScanMode "pr"
        -LocalScan
        -AzureToken "$(System.AccessToken)"
      pwsh: true
    env:
      SYSTEM_ACCESSTOKEN: $(System.AccessToken)
```

### Example 3: Combined SCA + Coverity Scan

```yaml
trigger:
  branches:
    include:
      - main

pool:
  name: 'Self-Hosted-Linux'  # Custom agent pool

variables:
  - group: Security-Scanning

steps:
  - checkout: self
    persistCredentials: true
    
  - task: PowerShell@2
    displayName: 'Install Bridge CLI'
    inputs:
      targetType: 'filePath'
      filePath: '$(System.DefaultWorkingDirectory)/scripts/Install-BridgeCLI-Linux.ps1'
      pwsh: true
      
  - task: Maven@3
    displayName: 'Build Application'
    inputs:
      mavenPomFile: 'pom.xml'
      goals: 'clean package'
      
  - task: PowerShell@2
    displayName: 'Security Scan (SCA + Coverity)'
    inputs:
      filePath: '$(System.DefaultWorkingDirectory)/scripts/Run-Combined-SCA-Coverity-Windows.ps1'
      arguments: >
        -BlackDuckUrl "$(BLACKDUCK_URL)"
        -BlackDuckToken "$(BLACKDUCK_TOKEN)"
        -CoverityUrl "$(COVERITY_URL)"
        -CoverityUser "$(COVERITY_USER)"
        -CoverityPassword "$(COVERITY_PASSWORD)"
        -ProjectName "$(Build.Repository.Name)"
        -ProjectVersion "$(Build.SourceBranchName)"
        -StreamName "$(Build.Repository.Name)-$(Build.SourceBranchName)"
      pwsh: true
    continueOnError: true
    timeoutInMinutes: 60
```

---

## ⚙️ Configuration Guide

### Azure DevOps Variable Groups

Create variable groups in Azure DevOps Library:

#### BlackDuck-Credentials
| Variable Name | Value | Secret? |
|--------------|-------|---------|
| BLACKDUCK_URL | https://your-blackduck-server.com | No |
| BLACKDUCK_TOKEN | your-api-token | Yes |

#### Coverity-Credentials
| Variable Name | Value | Secret? |
|--------------|-------|---------|
| COVERITY_URL | https://your-coverity-server.com | No |
| COVERITY_USER | service-account-username | No |
| COVERITY_PASSWORD | service-account-password | Yes |

### Pipeline Permissions for PR Comments

To enable automated PR comments, grant the build service account permission:

1. Go to **Project Settings** → **Repositories** → Select your repository
2. Click **Security** tab
3. Find **[Project Name] Build Service ([Organization Name])**
4. Set **Contribute to pull requests** to **Allow**

### Environment Variables Reference

#### Black Duck SCA Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `BRIDGE_BLACKDUCKSCA_URL` | Black Duck server URL | Yes |
| `BRIDGE_BLACKDUCKSCA_TOKEN` | API token | Yes |
| `DETECT_PROJECT_NAME` | Project name | Yes |
| `DETECT_PROJECT_VERSION_NAME` | Version/branch name | Yes |
| `BRIDGE_BLACKDUCKSCA_SCAN_FULL` | Full scan (true/false) | No |
| `BRIDGE_BLACKDUCKSCA_AUTOMATION_PRCOMMENT` | Enable PR comments | No |

#### Coverity Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `BRIDGE_COVERITY_CONNECT_URL` | Coverity server URL | Yes |
| `BRIDGE_COVERITY_CONNECT_USER_NAME` | Username | Yes |
| `BRIDGE_COVERITY_CONNECT_USER_PASSWORD` | Password | Yes |
| `BRIDGE_COVERITY_CONNECT_PROJECT_NAME` | Project name | Yes |
| `BRIDGE_COVERITY_CONNECT_STREAM_NAME` | Stream name | Yes |
| `BRIDGE_COVERITY_LOCAL` | Local scan mode | No |
| `BRIDGE_COVERITY_AUTOMATION_PRCOMMENT` | Enable PR comments | No |

---

## 📚 Official Documentation

### Bridge CLI Documentation

- **Bridge CLI Overview**: https://documentation.blackduck.com/bundle/bridge/page/documentation/c_overview.html
- **Complete List of Bridge Commands**: https://documentation.blackduck.com/bundle/bridge/page/documentation/c_complete-list-of-bridge-commands.html
- **Using Bridge with Black Duck**: https://documentation.blackduck.com/bundle/bridge/page/documentation/c_using-bridge-with-black-duck.html
- **Using Bridge with Coverity**: https://documentation.blackduck.com/bundle/bridge/page/documentation/c_using-bridge-with-coverity-connect.html

### Azure DevOps Integration

- **Azure DevOps + Black Duck SCA**: https://documentation.blackduck.com/bundle/bridge/page/documentation/c_azure-with-blackduck.html
- **Azure DevOps + Coverity**: https://documentation.blackduck.com/bundle/bridge/page/documentation/c_azure-with-coverity.html

### Product Documentation

- **Black Duck Detect Properties**: https://documentation.blackduck.com/bundle/detect/page/properties/all-properties.html
- **Coverity Analysis Commands**: https://documentation.blackduck.com/bundle/coverity-docs/page/commands/topics/coverity_analysis_commands.html
- **CI Integration Cookbook**: https://community.blackduck.com/s/article/The-Ultimate-CI-Integration-Guide17630746
- **Coverity in Azure DevOps**: https://community.blackduck.com/s/article/ADO---Coverity17630074

### Download Locations

- **Bridge CLI (Windows)**: https://repo.blackduck.com/bds-integrations-release/com/blackduck/integration/bridge/binaries/bridge-cli-thin-client/latest/bridge-cli-win64.zip
- **Bridge CLI (Linux)**: https://repo.blackduck.com/bds-integrations-release/com/blackduck/integration/bridge/binaries/bridge-cli-thin-client/latest/bridge-cli-linux64.zip
- **All Bridge CLI Versions**: https://repo.blackduck.com/bds-integrations-release/com/blackduck/integration/bridge/binaries/bridge-cli-thin-client/

### Example Repositories

- **Chuck Aude's ADO Examples**: https://dev.azure.com/chuckaude/_git/hello-java?path=/ado
  - [bd-bridge-cli.yml](https://dev.azure.com/chuckaude/_git/hello-java?path=/ado/bd-bridge-cli.yml)
  - [coverity-bridge-cli.yml](https://dev.azure.com/chuckaude/_git/hello-java?path=/ado/coverity-bridge-cli.yml)
  - [bd-bridge-cli-win64.yml](https://dev.azure.com/chuckaude/_git/hello-java?path=/ado/bd-bridge-cli-win64.yml)

---

## 🔍 Troubleshooting

### Common Issues

#### Issue: Bridge CLI Not Found

**Error Message:**
```
Bridge CLI not found. Please install Bridge CLI first or provide valid path.
```

**Solution:**
1. Ensure the installation script ran successfully
2. Check that `BRIDGE_CLI_PATH` variable is set
3. Verify the Bridge CLI executable exists at the specified path

#### Issue: Authentication Failed (Black Duck)

**Error Message:**
```
Failed to authenticate with Black Duck server
```

**Solution:**
1. Verify `BLACKDUCK_TOKEN` is correct and not expired
2. Check Black Duck server URL is accessible from agent
3. Ensure token has necessary permissions for project creation/scanning

#### Issue: Coverity Connection Failed

**Error Message:**
```
Unable to connect to Coverity Connect server
```

**Solution:**
1. Verify Coverity server URL is correct and accessible
2. Check username/password credentials
3. Ensure user has commit stream permissions
4. Verify stream exists in Coverity Connect

#### Issue: PR Comments Not Appearing

**Problem:** Scans run successfully but no comments appear on pull requests

**Solution:**
1. Verify build service account has "Contribute to pull requests" permission
2. Check `SYSTEM_ACCESSTOKEN` is passed to the script
3. Ensure `BRIDGE_AZURE_USER_TOKEN` environment variable is set
4. Verify Azure DevOps organization and project names are correct

#### Issue: Scan Timeout

**Error Message:**
```
Scan exceeded time limit
```

**Solution:**
1. Increase `timeoutInMinutes` in Azure DevOps task
2. For large codebases, consider incremental scanning
3. Use `LocalScan` mode for Coverity PR scans
4. Check network connectivity and bandwidth

### Debug Mode

Enable detailed logging by setting:

```powershell
$env:INCLUDE_DIAGNOSTICS = "true"
```

Check Bridge CLI version:

```powershell
.\bridge-cli --version
```

Test connectivity manually:

```powershell
# Black Duck
Invoke-WebRequest -Uri "https://your-blackduck-server.com" -Method Head

# Coverity
Invoke-WebRequest -Uri "https://your-coverity-server.com" -Method Head
```

### Getting Help

- **Black Duck Support Portal**: https://support.blackduck.com
- **Community Forums**: https://community.blackduck.com
- **Technical Documentation**: https://documentation.blackduck.com

---

## 📝 Best Practices

1. **Use Variable Groups**: Store credentials in Azure DevOps Library variable groups
2. **Enable PR Scans**: Configure lightweight PR scans for faster feedback
3. **Full Scans on Main**: Run comprehensive scans on main/master branch
4. **Set Timeouts**: Configure appropriate timeout values for large projects
5. **Use Local Mode**: Enable local mode for Coverity PR scans for faster results
6. **Monitor Scan Duration**: Track scan times and optimize as needed
7. **Regular Updates**: Keep Bridge CLI updated to latest version
8. **Test in Non-Production**: Validate configuration changes in test environments first

---

## 📄 License

This documentation and scripts are provided as examples for Black Duck customers.

---

## 🤝 Contributing

For questions, feedback, or contributions related to this training material, please contact your Black Duck representative or technical account manager.

---

**Last Updated:** September 2025  
**Version:** 1.0  
**Maintained By:** Steve R. Smith, TAM and NAM TAM Team Lead
