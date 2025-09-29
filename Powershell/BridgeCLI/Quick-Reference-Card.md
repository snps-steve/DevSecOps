# Bridge CLI Quick Reference Card

## 🚀 Installation Commands

### Windows
```powershell
# Download and install
.\Windows\Install-BridgeCLI-Windows.ps1

# With custom path
.\Windows\Install-BridgeCLI-Windows.ps1 -InstallDirectory "C:\tools\bridge"
```

### Linux (PowerShell Core)
```bash
# Download and install
pwsh ./Linux/Install-BridgeCLI-Linux.ps1

# With custom path
pwsh ./Linux/Install-BridgeCLI-Linux.ps1 -InstallDirectory "/opt/bridge"
```

---

## 🔍 Basic Scan Commands

### Black Duck SCA Scan

**Windows:**
```powershell
.\Windows\Run-BlackDuckSCA-Windows.ps1 `
    -BlackDuckUrl "https://blackduck.example.com" `
    -BlackDuckToken "YOUR_TOKEN" `
    -ProjectName "MyApp" `
    -ProjectVersion "main"
```

**Linux:**
```bash
pwsh ./Linux/Run-BlackDuckSCA-Linux.ps1 `
    -BlackDuckUrl "https://blackduck.example.com" `
    -BlackDuckToken "YOUR_TOKEN" `
    -ProjectName "MyApp" `
    -ProjectVersion "main"
```

### Coverity Scan

**Windows:**
```powershell
.\Windows\Run-Coverity-Windows.ps1 `
    -CoverityUrl "https://coverity.example.com" `
    -CoverityUser "username" `
    -CoverityPassword "password" `
    -ProjectName "MyApp" `
    -StreamName "MyApp-main"
```

**Linux:**
```bash
pwsh ./Linux/Run-Coverity-Linux.ps1 `
    -CoverityUrl "https://coverity.example.com" `
    -CoverityUser "username" `
    -CoverityPassword "password" `
    -ProjectName "MyApp" `
    -StreamName "MyApp-main"
```

### Combined SCA + Coverity

**Windows:**
```powershell
.\Windows\Run-Combined-SCA-Coverity-Windows.ps1 `
    -BlackDuckUrl "https://blackduck.example.com" `
    -BlackDuckToken "YOUR_TOKEN" `
    -CoverityUrl "https://coverity.example.com" `
    -CoverityUser "username" `
    -CoverityPassword "password" `
    -ProjectName "MyApp" `
    -ProjectVersion "main" `
    -StreamName "MyApp-main"
```

**Linux:**
```bash
pwsh ./Linux/Run-Combined-SCA-Coverity-Linux.ps1 `
    -BlackDuckUrl "https://blackduck.example.com" `
    -BlackDuckToken "YOUR_TOKEN" `
    -CoverityUrl "https://coverity.example.com" `
    -CoverityUser "username" `
    -CoverityPassword "password" `
    -ProjectName "MyApp" `
    -ProjectVersion "main" `
    -StreamName "MyApp-main"
```

---

## 🎯 Scan Modes

### Full Scan (Main Branch)
```powershell
-ScanMode "full"
```

### Pull Request Scan
```powershell
-ScanMode "pr" -AzureToken "$(System.AccessToken)"
```

### Coverity Local Scan (Faster)
```powershell
-LocalScan
```

---

## 🔐 Required Environment Variables

### Black Duck SCA
```powershell
$env:BRIDGE_BLACKDUCKSCA_URL = "https://blackduck.example.com"
$env:BRIDGE_BLACKDUCKSCA_TOKEN = "your-api-token"
$env:DETECT_PROJECT_NAME = "MyApp"
$env:DETECT_PROJECT_VERSION_NAME = "main"
```

### Coverity
```powershell
$env:BRIDGE_COVERITY_CONNECT_URL = "https://coverity.example.com"
$env:BRIDGE_COVERITY_CONNECT_USER_NAME = "username"
$env:BRIDGE_COVERITY_CONNECT_USER_PASSWORD = "password"
$env:BRIDGE_COVERITY_CONNECT_PROJECT_NAME = "MyApp"
$env:BRIDGE_COVERITY_CONNECT_STREAM_NAME = "MyApp-main"
```

### Azure DevOps PR Comments
```powershell
$env:BRIDGE_AZURE_USER_TOKEN = "$(System.AccessToken)"
$env:BRIDGE_AZURE_ORGANIZATION_NAME = "your-org"
$env:BRIDGE_AZURE_REPOSITORY_NAME = "$(Build.Repository.Name)"
$env:BRIDGE_AZURE_PROJECT_NAME = "$(System.TeamProject)"
$env:BRIDGE_AZURE_REPOSITORY_PULL_NUMBER = "$(System.PullRequest.PullRequestId)"
```

---

## 📝 Azure DevOps YAML Snippets

### Install Bridge CLI Task
```yaml
- task: PowerShell@2
  displayName: 'Install Bridge CLI'
  inputs:
    filePath: '$(System.DefaultWorkingDirectory)/scripts/Install-BridgeCLI-Windows.ps1'
```

### Black Duck Scan Task
```yaml
- task: PowerShell@2
  displayName: 'Black Duck SCA Scan'
  inputs:
    filePath: '$(System.DefaultWorkingDirectory)/scripts/Run-BlackDuckSCA-Windows.ps1'
    arguments: >
      -BlackDuckUrl "$(BLACKDUCK_URL)"
      -BlackDuckToken "$(BLACKDUCK_TOKEN)"
      -ProjectName "$(Build.Repository.Name)"
      -ProjectVersion "$(Build.SourceBranchName)"
  continueOnError: true
```

### Conditional PR Scan
```yaml
- task: PowerShell@2
  displayName: 'Security Scan (PR)'
  condition: eq(variables['Build.Reason'], 'PullRequest')
  inputs:
    filePath: './scripts/Run-Combined-SCA-Coverity-Windows.ps1'
    arguments: >
      -ScanMode "pr"
      -AzureToken "$(System.AccessToken)"
  env:
    SYSTEM_ACCESSTOKEN: $(System.AccessToken)
```

---

## 🔧 Common Parameters

| Parameter | Description | Values |
|-----------|-------------|--------|
| `-BridgeCliPath` | Path to Bridge CLI | Auto-detected |
| `-ScanMode` | Type of scan | `full` or `pr` |
| `-ProjectName` | Project identifier | String |
| `-ProjectVersion` | Version/branch | String |
| `-StreamName` | Coverity stream | String |
| `-LocalScan` | Fast Coverity scan | Switch |
| `-TrustAllCertificates` | Skip SSL verify | Switch |

---

## 🐛 Troubleshooting Commands

### Check Bridge CLI Version
```powershell
.\bridge-cli --version
```

### Test Connectivity
```powershell
# Black Duck
Invoke-WebRequest -Uri "https://blackduck.example.com" -Method Head

# Coverity
Invoke-WebRequest -Uri "https://coverity.example.com" -Method Head
```

### Enable Debug Logging
```powershell
$env:INCLUDE_DIAGNOSTICS = "true"
```

### Check Environment Variables
```powershell
Get-ChildItem Env: | Where-Object { $_.Name -like "BRIDGE_*" }
```

---

## 📦 Download URLs

### Bridge CLI Binaries
- **Windows**: https://repo.blackduck.com/bds-integrations-release/com/blackduck/integration/bridge/binaries/bridge-cli-thin-client/latest/bridge-cli-win64.zip
- **Linux**: https://repo.blackduck.com/bds-integrations-release/com/blackduck/integration/bridge/binaries/bridge-cli-thin-client/latest/bridge-cli-linux64.zip

### Documentation
- **Bridge CLI**: https://documentation.blackduck.com/bundle/bridge/
- **All Properties**: https://documentation.blackduck.com/bundle/bridge/page/documentation/c_complete-list-of-bridge-commands.html
- **Azure Integration**: https://documentation.blackduck.com/bundle/bridge/page/documentation/c_azure-with-blackduck.html

---

## ⚡ Common Scenarios

### Scenario 1: First Time Setup

**Windows:**
```powershell
# 1. Install Bridge CLI
.\Windows\Install-BridgeCLI-Windows.ps1

# 2. Run a test scan
.\Windows\Run-BlackDuckSCA-Windows.ps1 `
    -BlackDuckUrl "https://your-bd-server.com" `
    -BlackDuckToken "YOUR_TOKEN" `
    -ProjectName "TestProject" `
    -ProjectVersion "test"
```

**Linux:**
```bash
# 1. Install Bridge CLI
pwsh ./Linux/Install-BridgeCLI-Linux.ps1

# 2. Run a test scan
pwsh ./Linux/Run-BlackDuckSCA-Linux.ps1 `
    -BlackDuckUrl "https://your-bd-server.com" `
    -BlackDuckToken "YOUR_TOKEN" `
    -ProjectName "TestProject" `
    -ProjectVersion "test"
```

### Scenario 2: PR Scanning with Comments
```yaml
# In azure-pipelines.yml
- task: PowerShell@2
  condition: eq(variables['Build.Reason'], 'PullRequest')
  inputs:
    filePath: './scripts/Run-Combined-SCA-Coverity-Windows.ps1'
    arguments: >
      -BlackDuckUrl "$(BLACKDUCK_URL)"
      -BlackDuckToken "$(BLACKDUCK_TOKEN)"
      -CoverityUrl "$(COVERITY_URL)"
      -CoverityUser "$(COVERITY_USER)"
      -CoverityPassword "$(COVERITY_PASSWORD)"
      -ProjectName "$(Build.Repository.Name)"
      -ProjectVersion "$(System.PullRequest.TargetBranch)"
      -StreamName "$(Build.Repository.Name)-$(System.PullRequest.TargetBranch)"
      -ScanMode "pr"
      -AzureToken "$(System.AccessToken)"
  env:
    SYSTEM_ACCESSTOKEN: $(System.AccessToken)
```

### Scenario 3: Separate SCA and Coverity Scans
```yaml
# Black Duck SCA
- task: PowerShell@2
  displayName: 'Black Duck SCA'
  inputs:
    filePath: './scripts/Run-BlackDuckSCA-Windows.ps1'
    arguments: >
      -BlackDuckUrl "$(BLACKDUCK_URL)"
      -BlackDuckToken "$(BLACKDUCK_TOKEN)"
      -ProjectName "$(Build.Repository.Name)"
      -ProjectVersion "$(Build.SourceBranchName)"

# Coverity SAST
- task: PowerShell@2
  displayName: 'Coverity SAST'
  inputs:
    filePath: './scripts/Run-Coverity-Windows.ps1'
    arguments: >
      -CoverityUrl "$(COVERITY_URL)"
      -CoverityUser "$(COVERITY_USER)"
      -CoverityPassword "$(COVERITY_PASSWORD)"
      -ProjectName "$(Build.Repository.Name)"
      -StreamName "$(Build.Repository.Name)-$(Build.SourceBranchName)"
```

---

## 🎓 Best Practices

### ✅ DO
- Store credentials in Azure DevOps variable groups
- Use `continueOnError: true` for scans
- Set appropriate timeout values (30-60 minutes)
- Enable PR comments for faster feedback
- Use local mode for Coverity PR scans
- Version control your scanning scripts
- Test in non-production first

### ❌ DON'T
- Hardcode credentials in scripts
- Block builds on scan failures (use policy gates instead)
- Skip certificate validation in production
- Run full scans on every PR (use incremental)
- Commit Bridge CLI binaries to repository
- Run scans without proper error handling

---

## 🔑 Azure DevOps Variable Groups

### Create Variable Group: BlackDuck-Credentials
```
BLACKDUCK_URL = https://blackduck.example.com
BLACKDUCK_TOKEN = your-api-token (secret)
```

### Create Variable Group: Coverity-Credentials
```
COVERITY_URL = https://coverity.example.com
COVERITY_USER = service-account
COVERITY_PASSWORD = password (secret)
```

### Use in Pipeline
```yaml
variables:
  - group: BlackDuck-Credentials
  - group: Coverity-Credentials
```

---

## 📊 Exit Codes

| Exit Code | Meaning | Action |
|-----------|---------|--------|
| `0` | Success | Continue pipeline |
| `1` | Fatal error | Review logs |
| `2` | Policy violation | Check scan results |
| `3` | Timeout | Increase timeout or optimize scan |

---

## 🆘 Quick Help

### Script Help
```powershell
Get-Help .\Windows\Run-BlackDuckSCA-Windows.ps1 -Full
```

### Bridge CLI Help
```powershell
.\bridge-cli --help
```

### Support Resources
- **Documentation**: https://documentation.blackduck.com
- **Community**: https://community.blackduck.com
- **Support**: https://support.blackduck.com

---

## 📱 Contact Information

For technical questions about this training:
- Contact your Black Duck Technical Account Manager
- Visit Black Duck Community Forums
- Reference the main README.md in this repository

---

**Quick Reference Version:** 1.0  
**Last Updated:** September 2025  
**Maintained By:** Steve R. Smith, TAM and NAM TAM Team Lead
