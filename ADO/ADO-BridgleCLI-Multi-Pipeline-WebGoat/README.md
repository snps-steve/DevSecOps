# WebGoat Modular Security Pipeline (Template-Based Architecture)

A comprehensive Azure DevOps pipeline collection demonstrating **both** Security Scan Task and Bridge CLI integration approaches for Black Duck SCA, BDSC, and Coverity SAST. This modular template system builds, scans, deploys, and validates the WebGoat application using reusable YAML templates designed for DevSecOps training and enterprise adoption.

## 🎯 Purpose
This repository provides **dual DevSecOps integration examples** comparing marketplace extensions vs direct CLI tools. Perfect for training sessions and enterprise teams evaluating integration approaches:

- **Security Scan Task Integration** – Azure DevOps marketplace extension (BlackDuckSecurityScan@2.2.0)
- **Bridge CLI Direct Integration** – Native CLI tools with maximum flexibility
- **Black Duck SCA** – Open source dependency vulnerability detection (both approaches)
- **Black Duck Secure Container (BDSC)** – Container image security scanning (both approaches)
- **Coverity SAST** – Static code analysis for security and quality (both approaches)
- **Modular Template Architecture** – Reusable stages for enterprise adoption
- **Training-Ready Examples** – Side-by-side comparison for 1.5-hour technical sessions

## 🏗 Modular Pipeline Architecture
```
Master Pipeline (azure-pipelines.yml)
├── Stage 1: build.yml          (Java 23 compilation)
├── Stage 2: container.yml      (Docker image creation)
├── Stage 3: security.yml       (Bridge CLI OR Security Scan Task)
├── Stage 4: deploy.yml         (Kubernetes deployment)
└── Stage 5: validate.yml       (Health checks & validation)

Integration Options:
┌─────────────────────┐  OR  ┌─────────────────────┐
│  Security Scan Task │      │  Bridge CLI Direct  │
│  (Marketplace Ext)  │      │  (Native CLI)       │
└─────────────────────┘      └─────────────────────┘
```

## 🛠 Azure DevOps Setup
### 1. Variable Groups
Create these in Azure DevOps → Pipelines → Library:

#### `blackduck-sca-variables`
| Variable              | Description              | Example                          |
|----------------------|--------------------------|----------------------------------|
| `BLACKDUCK_URL`      | Black Duck Hub URL       | `https://blackduck.company.com`  |
| `BLACKDUCK_API_TOKEN`| API authentication token | `[secure]`                        |

#### `coverity-variables`
| Variable              | Description              | Example                          |
|----------------------|--------------------------|----------------------------------|
| `COVERITY_URL`       | Coverity Connect URL     | `https://coverity.company.com`   |
| `COV_USER`           | Coverity username        | `build-user`                     |
| `COVERITY_PASSPHRASE`| Coverity password        | `[secure]`                        |

### 2. Secure Files
Upload your SSH private key as a secure file named `steve-pem`.
- Ensure it has access to your Kubernetes node.
- Update SSH username if different from `ubuntu`.

### 3. Pipeline Variables
Add these to your master pipeline YAML:
```yaml
variables:
  - group: blackduck-sca-variables
  - group: coverity-variables
  - name: PROJECT_NAME
    value: $(Build.Repository.Name)
  - name: PROJECT_VERSION
    value: $(Build.SourceBranchName)
  - name: BRIDGE_CLI_VERSION
    value: "latest"
  - name: K8S_SERVER_IP
    value: "172.31.17.121"
  - name: K8S_PUBLIC_IP
    value: "44.253.226.227"
  - name: WEBGOAT_NODEPORT
    value: "30080"
  - name: WEBWOLF_NODEPORT
    value: "30090"
```

## 📋 Template Usage
### Creating Your Pipeline
1. **Copy all 6 YAML files** to your repository root
2. **Choose your security integration approach:**
   - Use `security.yml` (provided) for **Bridge CLI** approach
   - Modify `security.yml` for **Security Scan Task** approach
3. **Create new pipeline** pointing to `azure-pipelines.yml`

### Template Dependencies
```yaml
# Example: Using modular templates
stages:
- template: build.yml
- template: container.yml
  parameters:
    dependsOn: BuildWebGoat
- template: security.yml
  parameters:
    dependsOn: [BuildWebGoat, BuildContainer]
```

## ✅ Pipeline Execution
### Automatic Triggers
- Push to `main` or `develop` → Full security scans with deployment
- Pull Request → Incremental scans with PR comments (Security Scan Task version)

### Manual Execution
```bash
# Run complete pipeline
az pipelines run --name "WebGoat-ModularPipeline" --branch main

# Run individual stages (for testing)
az pipelines run --name "WebGoat-ModularPipeline" --branch main --variables stage=build
```

### Training Session Usage
**Duration:** 1.5 hours technical session
- **Phase 1 (30 min):** Security Scan Task deep dive
- **Phase 2 (45 min):** Bridge CLI integration comparison
- **Phase 3 (15 min):** Results analysis and Q&A

## 🔗 Application Access
After successful deployment:
- **WebGoat:** `http://[K8S_PUBLIC_IP]:30080/WebGoat/`
- **WebWolf:** `http://[K8S_PUBLIC_IP]:30090/WebWolf/`

Default credentials: `user/password`

## 🔍 Security Results
Results appear in multiple locations:
- **Extensions Tab** → Security scan summaries
- **Tests Tab** → SARIF integration
- **Pipeline Artifacts** → Detailed reports
- **PR Comments** → Automated security feedback (Security Scan Task only)

## 🎓 Training Benefits
- **Direct Comparison** → Security Scan Task vs Bridge CLI side-by-side
- **Modular Learning** → Each stage demonstrates specific DevSecOps concepts
- **Enterprise Ready** → Templates can be adopted individually or as complete solution
- **Practical Examples** → Real application (WebGoat) with actual security findings
- **Flexible Deployment** → Works with any Kubernetes environment

---
**Training Repository:** WebGoat Azure DevOps Bridge CLI Integration  
**Pipeline Version:** 4.0 (Modular Templates)  
**Last Updated:** September 14, 2025  
**Maintainer:** Steve R. Smith
