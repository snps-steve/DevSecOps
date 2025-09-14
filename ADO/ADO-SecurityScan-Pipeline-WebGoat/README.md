# Single Azure DevOps Security Scan Pipeline for WebGoat

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

## 📁 File Structure

```
├── azure-pipelines.yml    # Pipelinescript
└── README.md              # This documentation
```

## 🎯 Training Benefits

### **For Development Teams**
- **Modular Learning**: Focus on specific pipeline stages independently
- **Clear Separation**: Security scanning isolated from build/deploy concerns
- **Practical Examples**: Real-world integration patterns with actual tools

### **For Security Teams**
- **Security Focus**: Dedicated `security.yml` template for easy review
- **Tool Integration**: Both SCA and SAST scanning examples
- **Result Integration**: Multiple ways to consume security scan results

### **For DevOps Teams**
- **Template Reuse**: Individual stages can be reused across projects
- **Maintenance**: Easier to update specific pipeline components
- **Debugging**: Isolate issues to specific pipeline stages

## 📊 Security Scan Configuration

### **Black Duck SCA Settings**
```yaml
# Source code scanning
DETECT_TOOLS: "DETECTOR,SIGNATURE_SCAN"
DETECT_EXCLUDED_DIRECTORIES: ".git,node_modules,vendor,.idea,.vscode,test,tests,spec,specs"

# Container scanning  
DETECT_TOOLS: "CONTAINER_SCAN"
DETECT_CONTAINER_SCAN_FILE_PATH: "$(Build.SourcesDirectory)/webgoat-$(Build.BuildId).tar"
```

### **Coverity SAST Settings**
```yaml
COVERITY_PROJECT_NAME: $(PROJECT_NAME)
COVERITY_STREAM_NAME: $(PROJECT_NAME)-$(PROJECT_VERSION)
coverity_local: true
mark_build_status: 'SucceededWithIssues'

## 🎓 Training Scenarios

This pipeline supports various training scenarios:

1. **Security Scan Deep Dive**: Focus on `azure-pipelines.yml` for detailed scan configuration
2. **Container Security**: Examine how `BDSC` and `binary scans` work together
3. **CI/CD Integration**: Show how security fits into the overall pipeline flow
4. **Tool Comparison**: Compare Black Duck SCA vs Coverity SAST results
5. **Pipeline Optimization**: Demonstrate parallel vs sequential scan execution

## 🔗 References

- [Black Duck Security Scan Extension](https://marketplace.visualstudio.com/items?itemName=synopsys-task.synopsys-security-scan-task)
- [WebGoat Project](https://github.com/WebGoat/WebGoat)
- [Azure DevOps YAML Schema](https://docs.microsoft.com/en-us/azure/devops/pipelines/yaml-schema)
- [Kubernetes NodePort Services](https://kubernetes.io/docs/concepts/services-networking/service/#nodeport)

---

**Repository**: ADO-SecurityScan-Pipeline-WebGoat 
**Maintained by**: Steve R. Smith
**Purpose**: Azure DevOps Black Duck Pipeline Integration Training using the Security Scan Task  
**Audience**: Black Duck Customer Development teams implementing DevSecOps practices
**Last Updated**: September 10, 2025   
