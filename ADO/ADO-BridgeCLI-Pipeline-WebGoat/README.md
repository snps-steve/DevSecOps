# Singular Bridge CLI Security Pipeline

A modern Azure DevOps pipeline demonstrating direct Bridge CLI integration for Black Duck SCA, Black Duck Secure Container (BDSC), and Coverity SAST. This pipeline builds, scans, deploys, and validates the WebGoat application using native CLI tools for maximum flexibility and DevSecOps best practices.

## 🎯 Purpose
This repository provides a full DevSecOps example for integrating security scanning into Azure DevOps pipelines without using the Security Scan marketplace extension. It includes:
- Black Duck SCA – Open source dependency vulnerability detection
- Black Duck Secure Container (BDSC) – Container image security scanning
- Coverity SAST – Static code analysis for security and quality
- Bridge CLI Direct Integration – No Azure DevOps extension required
- Kubernetes Deployment & Validation – Automated deployment and health checks

## 🏗 Pipeline Architecture
```
┌──────────────┐ ┌──────────────────┐ ┌──────────────────────┐ ┌───────────────┐ ┌───────────────┐
│  Build       │ │  Container       │ │  Security Scans      │ │  Deploy       │ │  Validate      │
│  (Java 23)   │ │  (Docker Image)  │ │  (Bridge CLI)        │ │  (Kubernetes) │ │  (Health Check)│
└──────────────┘ └──────────────────┘ └──────────────────────┘ └───────────────┘ └───────────────┘
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
Add these to your pipeline YAML:
```yaml
variables:
  - name: PROJECT_NAME
    value: $(Build.Repository.Name)
  - name: PROJECT_VERSION
    value: $(Build.SourceBranchName)
  - name: K8S_SERVER_IP
    value: "172.31.17.121"
  - name: K8S_PUBLIC_IP
    value: "44.253.226.227"
  - name: WEBGOAT_NODEPORT
    value: "30080"
  - name: WEBWOLF_NODEPORT
    value: "30090"
```

## ✅ Pipeline Execution
### Automatic Triggers
- Push to `main` or `develop` → Full scans
- Pull Request → Incremental scans with PR comments

### Manual Execution
```bash
az pipelines run --name "WebGoat-SecurityPipeline" --branch main
```

## 🔗 Application Access
- WebGoat: `http://[K8S_PUBLIC_IP]:30080/WebGoat/`
- WebWolf: `http://[K8S_PUBLIC_IP]:30090/WebWolf/`
Default credentials: `user/password`

---
Maintainer: Steve R. Smith  
Pipeline Version: 3.0  
Last Updated: September 9, 2025
