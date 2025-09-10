# Modular Azure DevOps Pipeline for WebGoat

This repository demonstrates a modular Azure DevOps pipeline for building, scanning, and deploying the WebGoat application using Kubernetes. The pipeline is split into five logical stages:

## 🎯 Purpose

This repository provides a complete example of integrating security scanning tools into Azure DevOps pipelines, specifically designed for:

- **Black Duck SCA** (Software Composition Analysis) - Open source vulnerability detection
- **Coverity SAST** (Static Application Security Testing) - Source code vulnerability analysis  
- **Software Risk Manager** integration capabilities
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
   git clone https://github.com/your-org/webgoat-pipeline-demo.git
   cd webgoat-pipeline-demo
   ```

2. Configure variable groups in Azure DevOps Library:
   - `AWS-Credentials`
      - AWS_ACCESS_KEY_ID (secret)
      - AWS_ACCOUNT_ID
      - AWS_SECRET_ACCESS_KEY (secret)    
   - `blackduck-sca-variables`
      - BLACKDUCK_API_TOKEN (secret)
      - BLACKDUCK_URL
      - BRIDGECLI_LINUX64   
   - `coverity-variables`
      - BRIDGECLI_LINUX
      - COV_USER (secret)
      - COVERITY_PASSPHRASE (secret)
      - COVERITY_URL 

4. Upload your SSH key as a secure file named `steve-pem`.

5. Run the pipeline using the master file:
   ```yaml
   azure-pipelines.yml
   ```

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

## 🛡️ Security Integration Benefits

This modular approach provides several advantages for DevSecOps training:

### **Black Duck SCA Integration**
- **Source Analysis**: Package manager and signature scanning of Java dependencies
- **Container Analysis**: BDSC (Black Duck Secure Container) scanning of final Docker image
- **Results Integration**: SARIF reports automatically published to Azure DevOps Security tab

### **Coverity SAST Integration** 
- **Static Analysis**: Comprehensive code quality and security vulnerability detection
- **Pull Request Integration**: Automated PR comments for early feedback
- **Policy Enforcement**: Configurable policy views for different scan contexts

### **Pipeline Integration Features**
- **Parallel Scanning**: Security scans run concurrently for faster feedback
- **Fail-Safe Deployment**: Deployment proceeds even if security scans fail
- **Rich Reporting**: Results appear in Extensions tab, Tests tab, and Pipeline artifacts
- **Flexible Gating**: Builds marked "succeeded with issues" rather than failed

## 📁 File Structure

```
├── azure-pipelines.yml    # Master pipeline orchestrator
├── build.yml             # Stage 1: Build WebGoat source
├── container.yml         # Stage 2: Create Docker container
├── security.yml          # Stage 3: Security scans (BD SCA + Coverity)
├── deploy.yml            # Stage 4: Kubernetes deployment
├── validate.yml          # Stage 5: Health checks and validation
└── README.md             # This documentation
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
2. **Container Security**: Examine how `container.yml` and `security.yml` work together
3. **CI/CD Integration**: Show how security fits into the overall pipeline flow
4. **Tool Comparison**: Compare Black Duck SCA vs Coverity SAST results
5. **Pipeline Optimization**: Demonstrate parallel vs sequential scan execution

---
**Maintained by**: Steve R. Smith  
**Purpose**: Azure DevOps Black Duck Pipeline Integration Training  
**Audience**: Development teams implementing DevSecOps practices
