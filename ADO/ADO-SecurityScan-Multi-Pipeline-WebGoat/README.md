# Modular Azure DevOps Pipeline for WebGoat

This repository demonstrates a modular Azure DevOps pipeline for building, scanning, and deploying the WebGoat application using Kubernetes. The pipeline is split into five logical stages:

## 🎯 Purpose

This repository provides a complete example of integrating security scanning tools into Azure DevOps pipelines, specifically designed for:

- **Black Duck SCA** (Software Composition Analysis) - Open source vulnerability detection
- **Coverity SAST** (Static Application Security Testing) - Source code vulnerability analysis  
- Production-ready deployment to self-hosted Kubernetes infrastructure

## 📦 Pipeline Structure

This is a set of 6 different pipelines, each with a specific purpose.

| Stage   | Stage Description       | Template File         | Description |
|---------|-------------------------|-----------------------|-----------------|
| Stage 0 | Master                  | `azure-pipelines.yml` | Master Pipeline |
| Stage 1 | Build                   | `build.yml`           | Compiles WebGoat using Java 23 and Maven |
| Stage 2 | Container               | `container.yml`       | Builds and verifies Docker image |
| Stage 3 | Security                | `security.yml`        | Runs Black Duck SCA and Coverity SAST scans |
| Stage 4 | Deploy                  | `deploy.yml`          | Deploys to Kubernetes cluster |
| Stage 5 | Validate                | `validate.yml`        | Performs health checks and connectivity tests |

## 🏗️ Pipeline Architecture

```
┌───────────┐ ┌────────────────┐ ┌─────────────────────────┐ ┌──────────────┐ ┌────────────────┐
│ Build     │ │ Container      │ │ Security Scans          │ │ Deploy       │ │ Validate       │
│ (Java 23) │ │ (Docker Image) │ │ (Black Duck + Coverity) │ │ (Kubernetes) │ │ (Health Check) │
└───────────┘ └────────────────┘ └─────────────────────────┘ └──────────────┘ └────────────────┘
```

### Stage Breakdown

#### 0. **Master Pipeline**
- Manages the 5 stages.
  
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
   git clone https://github.com/snps-steve/DevSecOps/ADO/ADO-SecurityScan-Multi-Pipeline-WebGoat.git
   cd ADO-SecurityScan-Multi-Pipeline-WebGoat/
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

## 🔄 Execution Flow

Each stage depends on the previous one using `dependsOn`:
- `container.yml` depends on `BuildWebGoat`
- `security.yml` depends on `BuildWebGoat` and `BuildContainer`
- `deploy.yml` depends on `BuildContainer` and `SecurityScans`
- `validate.yml` depends on `DeployKubernetes`

## 📊 Pipeline Execution Example

Here's what a successful modular pipeline execution looks like in Azure DevOps:

![Azure DevOps Pipeline Execution](https://raw.githubusercontent.com/snps-steve/ADO-SecurityScan-Multi-Pipeline-WebGoat/main/pipeline-execution-screenshot.png)

**Key Execution Metrics:**
- **Stage 1: Build WebGoat** - 1m 11s (Fast Java 23 + Maven build)
- **Stage 2: Build/Verify Container** - 1m 21s (Docker image creation)
- **Stage 3: Execute Security Scans** - 23m 49s (Comprehensive SCA + SAST analysis)
- **Stage 4: Deploy via Kubernetes** - 6m 13s (Container deployment)
- **Stage 5: Validation** - 9m 28s (Health checks and connectivity tests)

**Total Pipeline Time:** ~42 minutes with comprehensive security scanning

**Artifacts Generated:**
- Stage 1: WebGoat source code and JAR
- Stage 2: Container image (tar file)
- Stage 3: Security scan results and reports
- All stages: Pipeline logs and debugging information

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
├── azure-pipelines.yml    # Master pipeline orchestrator
├── build.yml              # Stage 1: Build WebGoat source
├── container.yml          # Stage 2: Create Docker container
├── security.yml           # Stage 3: Security scans (BD SCA + Coverity)
├── deploy.yml             # Stage 4: Kubernetes deployment
├── validate.yml           # Stage 5: Health checks and validation
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

## 🔧 Customization

Each template accepts parameters for flexibility:

```yaml
# Example: Custom dependency configuration
- template: security.yml
  parameters:
    dependsOn: [BuildWebGoat, BuildContainer]
```

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
```

## 🎓 Training Scenarios

This modular pipeline supports various training scenarios:

1. **Security Scan Deep Dive**: Focus only on `security.yml` for detailed scan configuration
2. **Container Security**: Examine how `BDSC` and `binary scans` work together
3. **CI/CD Integration**: Show how security fits into the overall pipeline flow, see how the discrete pipelines interact with each other
4. **Tool Comparison**: Compare Black Duck SCA vs Coverity SAST results
5. **Pipeline Optimization**: Demonstrate parallel vs sequential scan execution

## 🔗 References

- [Black Duck Security Scan Extension](https://marketplace.visualstudio.com/items?itemName=synopsys-task.synopsys-security-scan-task)
- [WebGoat Project](https://github.com/WebGoat/WebGoat)
- [Azure DevOps YAML Schema](https://docs.microsoft.com/en-us/azure/devops/pipelines/yaml-schema)
- [Kubernetes NodePort Services](https://kubernetes.io/docs/concepts/services-networking/service/#nodeport)

---
**Repository**: ADO-SecurityScan-Multi-Pipeline-WebGoat  
**Maintained by**: Steve R. Smith  
**Purpose**: Azure DevOps Black Duck Pipeline Integration Training using the Security Scan Task 
**Audience**: Black Duck Customer Development teams implementing DevSecOps practices
**Last Updated**: September 10, 2025  
