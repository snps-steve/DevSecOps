1. Set up the pipeline with credentials
Before the scan, you need to set environment variables with your credentials. Your CI/CD system should handle these as secure variables. The Powershell script then accesses these variables. 
powershell
# Set environment variables from your CI/CD system's secure store
# Replace with your actual variable names (e.g., in Azure DevOps, use $(variableName))
$Env:BRIDGE_COVERITY_CONNECT_USER_NAME = "$(CoverityUsername)"
$Env:BRIDGE_COVERITY_CONNECT_USER_PASSWORD = "$(CoverityPassword)"
$Env:BRIDGE_COVERITY_CONNECT_URL = "$(CoverityUrl)"
$Env:BRIDGE_BLACKDUCK_TOKEN = "$(BlackduckApiToken)"
$Env:BRIDGE_BLACKDUCK_URL = "$(BlackduckUrl)"

Write-Host "Credentials loaded from secure variables."
Use code with caution.

2. Create the configuration file
The most robust way to configure Bridge CLI is with a coverity.yaml file. This file can be checked into your repository. 
coverity.yaml
yaml
version: "1.0"
capture:
  build:
    clean-command: "mvn clean"
    build-command: "mvn -B -DskipTests package"

analyze:
  mode: "default"

commit:
  connect:
    stream: "my-app-stream"
    project: "my-app-project"

blackduck:
  url: "${env.BRIDGE_BLACKDUCK_URL}"
  token: "${env.BRIDGE_BLACKDUCK_TOKEN}"

# Optional: Add parameters to configure Detect within Bridge
detect:
  scan:
    full: true
Use code with caution.

3. Write the Powershell script
The Powershell script downloads the Bridge CLI and runs the scan. This script can be saved as run-bridge-scan.ps1. 
powershell
# --- run-bridge-scan.ps1 ---

# Define the download and install locations
$bridgeUrl = "https://sig-repo.synopsys.com/artifactory/bds-integrations-release/blackduck-bridge-cli/latest/bridge-cli-windows.zip"
$installPath = "$PSScriptRoot\bridge-cli"
$zipPath = "$PSScriptRoot\bridge-cli.zip"

# Download the Bridge CLI executable
try {
    Write-Host "Downloading Bridge CLI..."
    Invoke-WebRequest -Uri $bridgeUrl -OutFile $zipPath
    Expand-Archive -Path $zipPath -DestinationPath $installPath -Force
    Remove-Item $zipPath
}
catch {
    throw "Failed to download or extract Bridge CLI: $_"
}

# Define the executable path
$bridgeCliExecutable = "$installPath\bridge-cli-bundle-windows\bridge-cli.exe"

# Set Powershell execution policy for the process
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process

# --- Execute the Bridge CLI ---
# This command performs both SCA and Coverity scans using the coverity.yaml
# The '-c' flag specifies the configuration file.
# The 'connect' stage ensures integration with Coverity Connect, while SCA is handled via the blackduck and detect sections in the YAML.
# Bridge automatically runs the correct tools (Detect and Coverity CLI) based on the stages and configuration.
try {
    Write-Host "Starting combined Black Duck SCA and Coverity scan..."
    & $bridgeCliExecutable --stage connect --stage blackducksca -c "./coverity.yaml"
}
catch {
    throw "Bridge CLI scan failed: $_"
}

Write-Host "Bridge CLI scan completed."
Use code with caution.

4. Integrate into a CI/CD pipeline
A pipeline (e.g., Azure DevOps) would use a PowerShell@2 task to execute the script. The task is configured to handle credentials and call your run-bridge-scan.ps1. 
azure-pipelines.yml example
yaml
# ... (standard trigger and pool configuration) ...

variables:
- group: Synopsys-Credentials # Contains CoverityUsername, CoverityPassword, BlackduckApiToken, etc.

steps:
- task: PowerShell@2
  displayName: 'Run Black Duck SCA and Coverity Scan'
  inputs:
    targetType: 'filePath'
    filePath: 'run-bridge-scan.ps1'
    arguments: ''
