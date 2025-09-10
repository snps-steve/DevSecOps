# Single Azure DevOps Pipeline for WebGoat

A comprehensive Azure DevOps pipeline demonstrating Black Duck SCA and Coverity SAST integration for secure CI/CD workflows. This pipeline builds, scans, and deploys the WebGoat application to showcase enterprise security scanning capabilities.

## 🎯 Purpose

This repository provides a complete example of integrating security scanning tools into Azure DevOps pipelines, specifically designed for:

- **Black Duck SCA** (Software Composition Analysis) - Open source vulnerability detection
- **Coverity SAST** (Static Application Security Testing) - Source code vulnerability analysis  
- Production-ready deployment to self-hosted Kubernetes infrastructure

## 📦 Pipeline Structure

This is one large pipeline with multiple stages.

| Stage   | Stage Description       | Template File         | Description |
|---------|-------------------------|-----------------------|-----------------|
| Stage 1 | Build                   | `azure-pipelines.yml` | Compiles WebGoat using Java 23 and Maven |
| Stage 2 | Container               | `azure-pipelines.yml` | Builds and verifies Docker image |
| Stage 3 | Security                | `azure-pipelines.yml` | Runs Black Duck SCA and Coverity SAST scans |
| Stage 4 | Deploy                  | `azure-pipelines.yml` | Deploys to Kubernetes cluster |
| Stage 5 | Validate                | `azure-pipelines.yml` | Performs health checks and connectivity tests |

## 🏗️ Pipeline Architecture

```
┌───────────┐ ┌────────────────┐ ┌─────────────────────────┐ ┌──────────────┐ ┌────────────────┐
│ Build     │ │ Container      │ │ Security Scans          │ │ Deploy       │ │ Validate       │
│ (Java 23) │ │ (Docker Image) │ │ (Black Duck + Coverity) │ │ (Kubernetes) │ │ (Health Check) │
└───────────┘ └────────────────┘ └─────────────────────────┘ └──────────────┘ └────────────────┘
```

### Stage Breakdown

#### 1. **Build Stage**
- Compiles WebGoat using Java 23 and Maven
- Validates build environment
- Publishes artifacts for containerization and scanning

#### 2. **Container Stage**
- Builds Docker image using optimized Dockerfile
- Runs quick container test
- Saves image as TAR for scanning and deployment

#### 3. **Security Stage** (Parallel Execution)
- **Black Duck SCA Job**: Dependency vulnerability scanning
- **Coverity SAST Job**: Static code analysis
- Conditional logic for PR vs. main branch scanning

#### 4. **Deploy Stage**
- Transfers Docker image to Kubernetes node
- Applies deployment and service manifests
- Monitors rollout status

#### 5. **Validate Stage**
- Verifies pod readiness and health endpoints
- Performs external connectivity checks
- Prints summary with application URLs

## 🚀 Usage

1. Clone the repository:
   ```bash
   git clone https://github.com/snps-steve/DevSecOps/ADO/ADO-SecurityScan-Pipeline-WebGoat.git
   cd ADO-SecurityScan-Pipeline-WebGoat/
   ```

2. Modify the script where you find 'steve-pem'. Change it to whatever SSH key you need to use for your environment (this is what will be used to deploy the application if you use this pipeline script). 

3. Upload your SSH key as a secure file and give it the name you used in step 2. 

4. Configure variable groups in Azure DevOps (either the Project or Library). See Pipeline Configuration below.

5. Run the pipeline using the master file:
   ```yaml
   azure-pipelines.yml
   ```

## 🔧 Prerequisites

### Infrastructure Requirements

1. **Self-hosted Azure DevOps Agent**
   - Java 23 JDK installed
   - Maven wrapper (`mvnw`) support
   - Docker runtime
   - SSH access to Kubernetes server

2. **Kubernetes Cluster**
   - MicroK8s recommended
   - NodePort services enabled
   - Container registry access

3. **Security Tools**
   - Black Duck Hub instance
   - Coverity Connect server
   - Black Duck Security Scan Extension v2.2.0+ (install from the Marketplace)

## ⚙️ Pipeline Configuration

### Required Variable Groups

Create these variable groups in Azure DevOps Library:

#### `AWS-Credentials`
| Variable | Description | Example |
|----------|-------------|---------|
| `AWS_ACCESS_KEY_ID` | AWS Access Key | `[secure]` |
| `AWS_ACCOUNT_ID` | AWS Account ID | `000000000000` |
| `AWS_SECRET_ACCESS_KEY` | AWS Secret Access Key | `[secure]` |

#### `blackduck-sca-variables`
| Variable | Description | Example |
|----------|-------------|---------|
| `BLACKDUCK_API_TOKEN` | API authentication token | `[secure]` |
| `BLACKDUCK_URL` | Black Duck Hub URL | `https://blackduck.company.com` |
| `BRIDGECLI_LINUX64` | URL for Bridge | `https://repo.blackduck.com/artifactory/bds-integrations-release/com/blackduck/integration/bridge/binaries/bridge-cli-bundle/latest/bridge-cli-bundle-linux64.zip` |

#### `coverity-variables`  
| Variable | Description | Example |
|----------|-------------|---------|
| `BRIDGECLI_LINUX64` | URL for Bridge | `https://repo.blackduck.com/artifactory/bds-integrations-release/com/blackduck/integration/bridge/binaries/bridge-cli-bundle/latest/bridge-cli-bundle-linux64.zip` |
| `COV_USER` | Coverity username | `[secure]` |
| `COVERITY_PASSPHRASE` | Coverity password | `[secure]` |
| `COVERITY_URL` | Coverity Connect URL | `https://coverity.company.com` |

### Infrastructure Variables

Update these variables in the pipeline YAML:

```yaml
variables:
  - name: K8S_SERVER_IP
    value: "172.31.17.121"     # Private IP for SSH
  - name: K8S_PUBLIC_IP  
    value: "44.253.226.227"    # Public IP for web access
  - name: WEBGOAT_NODEPORT
    value: "30080"             # WebGoat NodePort
  - name: WEBWOLF_NODEPORT
    value: "30090"             # WebWolf NodePort
```

### SSH Configuration

1. Upload your SSH private key as a secure file named `steve-pem`
2. Ensure the key has access to your Kubernetes server
3. Update the SSH username if different from `ubuntu`

## 🔒 Security Scanning Features

### Black Duck SCA Integration

**Full Scan (main/develop branches):**
- Complete dependency analysis
- Vulnerability database matching
- Policy violation reporting
- Risk assessment dashboard

**Pull Request Scan:**
- Incremental scanning for faster feedback
- Automated PR comments with findings
- SARIF report generation for GitHub Advanced Security
- Build status integration

**Key Environment Variables:**
```yaml
env:
  DETECT_PROJECT_NAME: $(PROJECT_NAME)
  DETECT_PROJECT_VERSION_NAME: $(PROJECT_VERSION)
  DETECT_SELF_UPDATE_DISABLED: "true"
  DETECT_TOOLS: "SIGNATURE_SCAN"
```

### Coverity SAST Integration

**Full Scan (main/develop branches):**
- Complete static analysis of source code
- Security defect detection
- Quality metrics collection
- Stream-based reporting

**Pull Request Scan:**
- Incremental analysis for new/changed code
- Automated PR feedback
- Policy gate enforcement
- Developer-friendly reporting

**Key Configuration:**
```yaml
inputs:
  COVERITY_PROJECT_NAME: $(PROJECT_NAME)
  COVERITY_STREAM_NAME: $(PROJECT_NAME)-$(PROJECT_VERSION)
  coverity_local: true
  mark_build_status: 'SucceededWithIssues'
```

## 🚀 Deployment Features

### Docker Image Creation
- Multi-stage optimized Dockerfile
- Java 23 runtime with eclipse-temurin base
- Security-hardened container configuration
- Health check endpoints included

### Kubernetes Deployment
- Zero-downtime deployment strategy
- Resource limits and requests configured
- NodePort services for external access
- Comprehensive health monitoring

### WebGoat Application Access

After successful deployment:

- **WebGoat**: `http://[K8S_PUBLIC_IP]:30080/WebGoat/`
- **WebWolf**: `http://[K8S_PUBLIC_IP]:30090/WebWolf/`

Default credentials: `user/password` (for training purposes)

## 📋 Usage Instructions

### 1. Repository Setup
```bash
git clone https://github.com/WebGoat/WebGoat.git
cd WebGoat
# Copy azure-pipelines.yml to your repository
```

### 2. Configure Variable Groups
- Navigate to Azure DevOps → Pipelines → Library
- Create required variable groups with security tool credentials
- Mark sensitive values as secrets

### 3. Install Security Scan Extension
```bash
# Install from Azure DevOps Marketplace
az devops extension install --extension-name BlackDuckSecurityScan --publisher-name synopsys-task
```

### 4. Pipeline Execution

**Automatic Triggers:**
- Push to `main` or `develop` → Full security scans
- Pull request creation → Incremental security scans

**Manual Execution:**
```bash
az pipelines run --name "WebGoat-SecurityPipeline" --branch main
```

## 🔍 Security Scan Results

### Black Duck SCA Results
- **Hub Dashboard**: Comprehensive vulnerability management
- **Policy Violations**: License and security policy enforcement  
- **Risk Reports**: Executive-level risk assessment
- **SARIF Output**: Integration with code scanning tools

### Coverity SAST Results
- **Connect Dashboard**: Defect tracking and workflow
- **Stream Analysis**: Code quality metrics over time
- **Policy Views**: Customizable quality gates
- **PR Integration**: Developer-focused feedback

## 🛠️ Troubleshooting

### Common Issues

#### Build Failures
```bash
# Java version verification
java -version
./mvnw -v

# Check Maven wrapper permissions
chmod +x ./mvnw
```

#### Security Scan Failures
```bash
# Verify connectivity
curl -k $BLACKDUCK_URL/api/tokens/authenticate
curl -k $COVERITY_URL/api/ping

# Check agent capabilities
az pipelines agent list --pool-name "Self-Hosted ADO Agent"
```

#### Deployment Issues
```bash
# Verify Kubernetes connectivity
kubectl cluster-info
kubectl get nodes

# Check NodePort availability
kubectl get services -o wide
```

### Debug Commands

**Pipeline Debugging:**
```yaml
# Add to pipeline for troubleshooting
- script: |
    echo "=== Environment Debug ==="
    env | grep -E "(BLACKDUCK|COVERITY|K8S)" | sort
    docker info
    kubectl version --client
  displayName: 'Debug Environment'
```

## 📚 Training Notes

### Key Learning Objectives
1. **Security Scan Task Configuration** - Hands-on setup and configuration
2. **Pipeline Integration Patterns** - Best practices for CI/CD security
3. **Result Interpretation** - Understanding scan outputs and remediation
4. **Policy Management** - Configuring organizational security policies

### Extension vs. CLI Comparison

| Aspect | Security Scan Extension | Bridge CLI / Native Tools |
|--------|------------------------|---------------------------|
| **Setup** | Azure marketplace install | Manual tool installation |
| **Configuration** | Task-based YAML | Environment variables |
| **Authentication** | Built-in token management | Manual credential handling |
| **Reporting** | Integrated Azure DevOps | External dashboard only |
| **PR Integration** | Native Azure DevOps | Custom webhook setup |

### Best Practices Demonstrated
- Parallel security job execution for faster pipelines
- Conditional scanning logic for different branch types
- Secure credential management using variable groups
- Container security with non-root user configuration
- Infrastructure as Code with Kubernetes manifests

## 🔗 References

- [Black Duck Security Scan Extension](https://marketplace.visualstudio.com/items?itemName=synopsys-task.synopsys-security-scan-task)
- [WebGoat Project](https://github.com/WebGoat/WebGoat)
- [Azure DevOps YAML Schema](https://docs.microsoft.com/en-us/azure/devops/pipelines/yaml-schema)
- [Kubernetes NodePort Services](https://kubernetes.io/docs/concepts/services-networking/service/#nodeport)

---

**Repository**: WebGoat Security Pipeline Demo  
**Maintained by**: Steve R. Smith
**Last Updated**: September 5, 2025  
**Pipeline Version**: 2.0 
