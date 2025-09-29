# Azure DevOps Integration Options Comparison

## Overview

This guide compares the two primary methods for integrating Black Duck security scanning into Azure DevOps pipelines.

---

## Integration Options

### Option 1: Security Scan Task (Azure DevOps Extension)

The Security Scan Task is a pre-built Azure DevOps extension available from the marketplace that provides a UI-driven configuration experience.

**Installation:**
```yaml
# Install from Azure DevOps Marketplace
# Search for "Black Duck Security Scan"
```

**Example Usage:**
```yaml
- task: BlackDuckSecurityScan@1
  inputs:
    BlackDuckServerUrl: '$(BLACKDUCK_URL)'
    BlackDuckApiToken: '$(BLACKDUCK_TOKEN)'
    ScanType: 'SCA'
    ProjectName: '$(Build.Repository.Name)'
    ProjectVersion: '$(Build.SourceBranchName)'
```

### Option 2: Bridge CLI Direct Integration (PowerShell/Bash)

Direct integration using Bridge CLI provides more control and flexibility through command-line execution.

**Installation:**
```yaml
- task: PowerShell@2
  displayName: 'Install Bridge CLI'
  inputs:
    filePath: '$(System.DefaultWorkingDirectory)/scripts/Install-BridgeCLI-Windows.ps1'
```

**Example Usage:**
```yaml
- task: PowerShell@2
  displayName: 'Black Duck Scan'
  inputs:
    filePath: '$(System.DefaultWorkingDirectory)/scripts/Run-BlackDuckSCA-Windows.ps1'
    arguments: >
      -BlackDuckUrl "$(BLACKDUCK_URL)"
      -BlackDuckToken "$(BLACKDUCK_TOKEN)"
      -ProjectName "$(Build.Repository.Name)"
      -ProjectVersion "$(Build.SourceBranchName)"
```

---

## Detailed Comparison

| Feature | Security Scan Task | Bridge CLI Direct |
|---------|-------------------|-------------------|
| **Setup Complexity** | ⭐⭐⭐⭐⭐ Easy | ⭐⭐⭐ Moderate |
| **Configuration** | UI-based in Azure DevOps | Script-based (PowerShell/Bash) |
| **Customization** | Limited to task parameters | Full control over all Bridge CLI options |
| **Version Control** | Task version managed by extension | Script version controlled in repository |
| **Marketplace Dependency** | Requires extension installation | No external dependencies |
| **Multi-Tool Support** | Separate tasks for SCA/Coverity | Single script for combined scans |
| **Learning Curve** | Low | Moderate to High |
| **Troubleshooting** | Limited visibility | Full diagnostic access |
| **Advanced Features** | Some features not exposed | All Bridge CLI features available |
| **Pipeline Portability** | Azure DevOps only | Portable to other CI/CD platforms |

---

## When to Use Each Approach

### Use Security Scan Task When:

✅ **Quick Setup Needed**
- You want to get scanning running quickly without scripting
- Team prefers UI-based configuration
- Limited scripting experience on the team

✅ **Standard Requirements**
- Your scanning needs fit within the task's parameters
- You don't need advanced Bridge CLI features
- Standard SCA or Coverity scanning is sufficient

✅ **Marketplace Access Available**
- Your organization allows Azure DevOps Marketplace extensions
- You can install and manage extensions easily

✅ **Simple Workflows**
- Single tool scanning (just SCA or just Coverity)
- No complex conditional logic needed
- Standard project/version naming schemes

**Example Scenario:**
> "We need to add Black Duck SCA scanning to 20 repositories quickly. All projects follow the same pattern, and we want developers to easily add scanning with minimal changes."

---

### Use Bridge CLI Direct Integration When:

✅ **Maximum Flexibility Required**
- You need access to advanced Bridge CLI parameters
- Custom scan configurations per project
- Complex conditional scanning logic

✅ **Combined Tool Scanning**
- Running both SCA and Coverity in a single scan
- Need unified reporting across multiple tools
- Want to optimize scan performance

✅ **Advanced Automation**
- Conditional scanning based on file changes
- Dynamic project/version naming logic
- Integration with custom tooling or workflows

✅ **Environment Constraints**
- Cannot install marketplace extensions
- Need to work across multiple CI/CD platforms
- Require full diagnostic and logging control

✅ **Version Control Everything**
- Want scanning configuration in source control
- Need to track changes to scanning logic
- Team prefers code-based configuration

✅ **Custom Error Handling**
- Need specific error handling logic
- Want to parse and act on scan results
- Require integration with other pipeline tools

**Example Scenario:**
> "We run both SCA and Coverity scans, need custom logic to determine when to scan, and want to parse results to block deployments based on specific criteria. We also need the same scripts to work in GitHub Actions in the future."

---

## Architecture Comparison

### Security Scan Task Architecture

```
Azure DevOps Pipeline
    ↓
Security Scan Task (Extension)
    ↓
Bridge CLI (bundled)
    ↓
Detect / Coverity Native Tools
    ↓
Black Duck / Coverity Server
```

**Layers:** 4

### Bridge CLI Direct Architecture

```
Azure DevOps Pipeline
    ↓
PowerShell/Bash Script
    ↓
Bridge CLI
    ↓
Detect / Coverity Native Tools
    ↓
Black Duck / Coverity Server
```

**Layers:** 3 (eliminates one abstraction layer)

---

## Configuration Examples

### Example 1: Black Duck SCA Scan

#### Security Scan Task
```yaml
- task: BlackDuckSecurityScan@1
  displayName: 'Black Duck SCA Scan'
  inputs:
    BlackDuckServerUrl: '$(BLACKDUCK_URL)'
    BlackDuckApiToken: '$(BLACKDUCK_TOKEN)'
    ScanType: 'SCA'
    ProjectName: '$(Build.Repository.Name)'
    ProjectVersion: '$(Build.SourceBranchName)'
    ScanFull: true
    DetectArgs: '--detect.detector.buildless=true'
```

#### Bridge CLI Direct
```yaml
- task: PowerShell@2
  displayName: 'Black Duck SCA Scan'
  inputs:
    filePath: './scripts/Run-BlackDuckSCA-Windows.ps1'
    arguments: >
      -BlackDuckUrl "$(BLACKDUCK_URL)"
      -BlackDuckToken "$(BLACKDUCK_TOKEN)"
      -ProjectName "$(Build.Repository.Name)"
      -ProjectVersion "$(Build.SourceBranchName)"
      -ScanMode "full"
  env:
    DETECT_DETECTOR_BUILDLESS: 'true'
```

### Example 2: Coverity Scan

#### Security Scan Task
```yaml
- task: CoveritySecurityScan@1
  displayName: 'Coverity Scan'
  inputs:
    CoverityServerUrl: '$(COVERITY_URL)'
    CoverityUsername: '$(COVERITY_USER)'
    CoverityPassword: '$(COVERITY_PASSWORD)'
    ProjectName: '$(Build.Repository.Name)'
    StreamName: '$(Build.Repository.Name)-main'
```

#### Bridge CLI Direct
```yaml
- task: PowerShell@2
  displayName: 'Coverity Scan'
  inputs:
    filePath: './scripts/Run-Coverity-Windows.ps1'
    arguments: >
      -CoverityUrl "$(COVERITY_URL)"
      -CoverityUser "$(COVERITY_USER)"
      -CoverityPassword "$(COVERITY_PASSWORD)"
      -ProjectName "$(Build.Repository.Name)"
      -StreamName "$(Build.Repository.Name)-main"
      -LocalScan
```

### Example 3: Combined SCA + Coverity (Only Available with Bridge CLI Direct)

```yaml
# NOT POSSIBLE with Security Scan Task - requires two separate tasks

# Bridge CLI Direct
- task: PowerShell@2
  displayName: 'Combined Security Scan'
  inputs:
    filePath: './scripts/Run-Combined-SCA-Coverity-Windows.ps1'
    arguments: >
      -BlackDuckUrl "$(BLACKDUCK_URL)"
      -BlackDuckToken "$(BLACKDUCK_TOKEN)"
      -CoverityUrl "$(COVERITY_URL)"
      -CoverityUser "$(COVERITY_USER)"
      -CoverityPassword "$(COVERITY_PASSWORD)"
      -ProjectName "$(Build.Repository.Name)"
      -ProjectVersion "$(Build.SourceBranchName)"
      -StreamName "$(Build.Repository.Name)-$(Build.SourceBranchName)"
```

---

## Performance Considerations

### Security Scan Task
- **Overhead:** Additional task wrapper layer
- **Download:** Extension downloads Bridge CLI if not cached
- **Execution:** Standard performance, slight overhead from task wrapper

### Bridge CLI Direct
- **Overhead:** Minimal, direct CLI execution
- **Download:** Script-controlled download, can be cached strategically
- **Execution:** Direct execution, no wrapper overhead
- **Combined Scans:** Can run SCA + Coverity in single invocation, reducing setup time

**Performance Gain:** Combined scans with Bridge CLI Direct can be 10-15% faster than running two separate tasks.

---

## Maintenance and Updates

### Security Scan Task
- ✅ Auto-updates through Azure DevOps marketplace
- ✅ Centralized maintenance by extension publisher
- ⚠️ May break pipelines on major version updates
- ⚠️ Limited control over update timing

### Bridge CLI Direct
- ✅ Full control over Bridge CLI version
- ✅ Test updates in non-production first
- ✅ Version pinning available
- ⚠️ Manual update process required
- ⚠️ Team responsible for keeping scripts current

---

## Hybrid Approach

You can use both approaches in different scenarios:

### Recommended Hybrid Strategy

**Use Security Scan Task for:**
- Development/feature branches
- Quick PR scans
- Standard projects with simple requirements

**Use Bridge CLI Direct for:**
- Main/release branches requiring combined scans
- Projects with custom scanning logic
- Production deployments with specific security gates

**Example Hybrid Pipeline:**
```yaml
# PR Scans - Use Task for simplicity
- task: BlackDuckSecurityScan@1
  condition: eq(variables['Build.Reason'], 'PullRequest')
  inputs:
    ScanType: 'SCA'
    # ... standard configuration

# Main Branch - Use Bridge CLI for advanced features
- task: PowerShell@2
  condition: eq(variables['Build.SourceBranch'], 'refs/heads/main')
  inputs:
    filePath: './scripts/Run-Combined-SCA-Coverity-Windows.ps1'
    # ... advanced configuration
```

---

## Migration Path

### From Security Scan Task → Bridge CLI Direct

1. **Capture Current Configuration**
   - Document all task parameters
   - Note any custom Detect/Coverity arguments
   - Review PR comment configuration

2. **Create Scripts**
   - Use provided PowerShell scripts as templates
   - Map task parameters to script parameters
   - Add any custom logic needed

3. **Test in Non-Production**
   - Run scripts in test pipelines
   - Verify scan results match task results
   - Confirm PR comments work correctly

4. **Gradual Rollout**
   - Start with one repository
   - Expand to similar projects
   - Eventually migrate all pipelines

5. **Deprecate Task**
   - Remove Security Scan Task references
   - Update documentation
   - Train team on new approach

---

## Recommendations by Team Size

### Small Teams (< 10 developers)
**Recommendation:** Start with Security Scan Task
- Faster initial setup
- Less maintenance overhead
- Easier for occasional users

### Medium Teams (10-50 developers)
**Recommendation:** Hybrid Approach
- Task for standard projects
- Scripts for advanced needs
- Gradual migration to scripts

### Large Teams (50+ developers)
**Recommendation:** Bridge CLI Direct
- Standardized across all projects
- Version-controlled configuration
- Maximum flexibility for diverse needs
- Platform independence if needed

---

## Decision Matrix

Use this matrix to determine the best approach for your use case:

| Your Requirement | Security Scan Task | Bridge CLI Direct |
|-----------------|:------------------:|:-----------------:|
| Quick setup | ✅ Best | ⚠️ Acceptable |
| Combined SCA + Coverity | ❌ Not Available | ✅ Best |
| Advanced customization | ⚠️ Limited | ✅ Best |
| Version control config | ⚠️ Limited | ✅ Best |
| No marketplace access | ❌ Not Possible | ✅ Best |
| Minimal scripting | ✅ Best | ❌ Not Suitable |
| Multiple CI/CD platforms | ❌ Azure only | ✅ Best |
| Complex conditional logic | ⚠️ Limited | ✅ Best |
| Simple workflows | ✅ Best | ⚠️ Overkill |
| Full diagnostics needed | ⚠️ Limited | ✅ Best |

**Legend:**
- ✅ Best choice for this requirement
- ⚠️ Works but has limitations
- ❌ Not suitable or not possible

---

## Conclusion

Both integration methods have their place in Azure DevOps pipelines:

- **Choose Security Scan Task** for simplicity and quick adoption
- **Choose Bridge CLI Direct** for flexibility, combined scanning, and advanced use cases
- **Use a Hybrid Approach** to get benefits of both

For the customer training scenario (SCA + Coverity + Software Risk Manager with advanced requirements), **Bridge CLI Direct integration** is recommended as it provides:

1. Combined scanning capabilities
2. Maximum flexibility for custom workflows  
3. Full diagnostic access for troubleshooting
4. Version-controlled configuration
5. Foundation for future multi-platform support

---

## Additional Resources

- [Bridge CLI Documentation](https://documentation.blackduck.com/bundle/bridge/)
- [Security Scan Task Documentation](https://documentation.blackduck.com/bundle/bridge/page/documentation/c_azure-with-blackduck.html)
- [CI Integration Best Practices](https://community.blackduck.com/s/article/The-Ultimate-CI-Integration-Guide17630746)
