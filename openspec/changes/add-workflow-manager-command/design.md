## Context

Users running large-scale GWAS analyses (186 traits) encounter various failure modes:
- OOMKilled: Memory exhaustion during MLM model fitting
- Stuck pods: Kubernetes scheduling issues (PodInitializing forever)
- Timeouts: Long-running analyses exceeding deadlines
- Mount failures: NFS/hostPath unavailability

Currently, handling these failures requires manual intervention with multiple CLI tools and scripts. This command automates the entire cycle.

## Goals / Non-Goals

### Goals
- Provide a single command to manage workflow lifecycle
- Intelligently categorize failures and recommend appropriate remediation
- Automate retry workflow generation with correct parameters
- Include aggregation in retry workflow for complete results
- Support both interactive and automated operation modes

### Non-Goals
- Modify cluster infrastructure or scheduling policies
- Handle non-Argo workflow systems (RunAI-only is separate)
- Provide real-time streaming logs (use `/monitor-jobs` for that)
- Auto-scale cluster resources

## Decisions

### Decision: Use slash command (not shell script)
- **Why**: Slash commands leverage Claude's reasoning to handle edge cases, provide explanations, and adapt to varying scenarios
- **Alternative**: Shell script would be more rigid and harder to maintain
- **Trade-off**: Requires Claude Code invocation, but provides better UX

### Decision: Phase-based execution with confirmations
- **Why**: Destructive operations (stop, cleanup) need user awareness
- **Alternative**: Fully automated with no confirmations
- **Trade-off**: Slower for experienced users, but safer for all

### Decision: Leverage existing `retry-argo-traits.sh`
- **Why**: Script already handles parameter extraction, YAML generation, submission
- **Alternative**: Reimplement in the command
- **Trade-off**: Dependency on script, but DRY principle and tested code

### Decision: WSL invocation pattern for Windows
- **Why**: Users are on Windows, cluster tools require Linux environment
- **Pattern**: `wsl -e bash -c "export KUBECONFIG=~/.kube/kubeconfig-runai-talmo-lab.yaml && <command>"`
- **Alternative**: Require users to be in WSL terminal
- **Trade-off**: More verbose commands, but works from any terminal

## Implementation Details

### Phase 1: Assessment

```bash
# Get workflow status
wsl -e bash -c "export KUBECONFIG=~/.kube/kubeconfig-runai-talmo-lab.yaml && argo get <workflow> -n runai-talmo-lab" 2>&1

# Parse output to identify:
# - Total tasks, completed, failed
# - OOMKilled: Look for "OOMKilled (exit code 137)" in MESSAGE column
# - Stuck: Look for "PodInitializing" with duration > 10 minutes
# - Extract trait index from task name: run-all-traits(3:5) -> trait index 5
```

### Phase 2: Cleanup

```bash
# Stop stalled workflow
wsl -e bash -c "export KUBECONFIG=~/.kube/kubeconfig-runai-talmo-lab.yaml && argo stop <workflow> -n runai-talmo-lab" 2>&1

# Check for incomplete output directories (Windows path)
# For each failed trait, check: Z:\users\eberrigan\...\outputs\trait_NNN_*
# If directory exists but incomplete, mark for cleanup
```

### Phase 3: Retry

```bash
# Generate and submit retry workflow
wsl -e bash -c "export KUBECONFIG=~/.kube/kubeconfig-runai-talmo-lab.yaml && cd /mnt/c/repos/gapit3-gwas-pipeline && ./scripts/retry-argo-traits.sh \
  --workflow <original-workflow> \
  --traits <comma-separated-trait-list> \
  --highmem \
  --aggregate \
  --submit" 2>&1

# Capture submitted workflow name from output
```

### Phase 4: Monitoring

```bash
# Poll workflow status
wsl -e bash -c "export KUBECONFIG=~/.kube/kubeconfig-runai-talmo-lab.yaml && argo get <retry-workflow> -n runai-talmo-lab" 2>&1

# Check for:
# - Status: Running, Succeeded, Failed
# - Progress: X/Y tasks complete
# - collect-results task status (aggregation)
```

### Failure Categorization Logic

```python
def categorize_failure(task_output):
    if "OOMKilled" in task_output or "exit code 137" in task_output:
        return "OOMKilled", "Use --highmem template"
    elif "PodInitializing" in task_output:
        duration = parse_duration(task_output)
        if duration > timedelta(minutes=10):
            return "Stuck", "Stop workflow, check cluster resources"
    elif "DeadlineExceeded" in task_output:
        return "Timeout", "Increase activeDeadlineSeconds or investigate"
    else:
        return "Error", "Check pod logs for details"
```

### Trait Index Extraction

Task names follow pattern: `run-all-traits(N:M)` where M is the trait index.

```python
import re
def extract_trait_index(task_name):
    match = re.search(r'run-all-traits\(\d+:(\d+)\)', task_name)
    if match:
        return int(match.group(1))
    # For retry tasks: retry-trait-5
    match = re.search(r'retry-trait-(\d+)', task_name)
    if match:
        return int(match.group(1))
    return None
```

## Risks / Trade-offs

### Risk: Automated cleanup deletes wanted data
- **Mitigation**: Always show what will be deleted, require confirmation
- **Mitigation**: Support `--dry-run` to preview without action

### Risk: Retry workflow fails again with same error
- **Mitigation**: Use high-memory template for OOM failures
- **Mitigation**: Claude can detect repeated failures and recommend investigation

### Risk: WSL command failures
- **Mitigation**: Check for common errors (KUBECONFIG not found, WSL not running)
- **Mitigation**: Provide clear error messages with resolution steps

## Troubleshooting Guidance

The slash command should include built-in troubleshooting for common issues.

### Argo Workflow Access

**Problem**: `argo` command not found or authentication fails
```bash
# Check: WSL has argo installed
wsl -e bash -c "which argo"

# Check: KUBECONFIG exists
wsl -e bash -c "ls -la ~/.kube/kubeconfig-runai-talmo-lab.yaml"
```

**Solution**: Always use explicit KUBECONFIG pattern:
```bash
wsl -e bash -c "export KUBECONFIG=~/.kube/kubeconfig-runai-talmo-lab.yaml && <command>"
```

**Common errors**:
- `error: no configuration has been provided` - KUBECONFIG not set
- `wsl: Processing /etc/fstab with mount -a failed` - Harmless warning, ignore

### Kubernetes Access

**Problem**: kubectl/argo can't connect to cluster
```bash
# Check: Can reach cluster API
wsl -e bash -c "export KUBECONFIG=~/.kube/kubeconfig-runai-talmo-lab.yaml && kubectl cluster-info"

# Check: Correct namespace
wsl -e bash -c "export KUBECONFIG=~/.kube/kubeconfig-runai-talmo-lab.yaml && kubectl get pods -n runai-talmo-lab"
```

**Solutions**:
- Verify VPN connection if required
- Check KUBECONFIG file exists and is valid
- Verify namespace `runai-talmo-lab` exists

**Common errors**:
- `Unable to connect to the server` - Network/VPN issue
- `forbidden: User cannot list resource` - RBAC permissions issue
- `workflowtaskresults.argoproj.io is forbidden (exit code 64)` - Known RBAC limitation

### GPU Cluster Access (RunAI)

**Problem**: Pods stuck in Pending or PodInitializing
```bash
# Check: Node availability
wsl -e bash -c "export KUBECONFIG=~/.kube/kubeconfig-runai-talmo-lab.yaml && kubectl get nodes"

# Check: Pod events
wsl -e bash -c "export KUBECONFIG=~/.kube/kubeconfig-runai-talmo-lab.yaml && kubectl describe pod <pod-name> -n runai-talmo-lab | tail -30"
```

**Solutions**:
- **PodInitializing > 10 min**: Stop workflow and retry - cluster scheduling issue
- **Insufficient memory**: Use high-memory template (96Gi instead of 64Gi)
- **Node selector issues**: Check RunAI quota and node affinity

**Resource requirements**:
| Template | Memory Request | Memory Limit | CPU Request | CPU Limit |
|----------|----------------|--------------|-------------|-----------|
| Normal   | 64Gi           | 72Gi         | 12          | 16        |
| High-mem | 96Gi           | 104Gi        | 16          | 20        |

### Data Access (NFS/hostPath)

**Problem**: Volume mount failures or missing data
```bash
# Windows paths
Z:\users\eberrigan\<dataset>\outputs

# WSL paths (for checking from bash)
/mnt/hpi_dev/users/eberrigan/<dataset>/outputs

# Cluster paths (in workflow YAML)
/hpi/hpi_dev/users/eberrigan/<dataset>/outputs
```

**Path mapping**:
| Context | Base Path |
|---------|-----------|
| Windows (PowerShell/CMD) | `Z:\users\eberrigan\...` |
| WSL (bash) | `/mnt/hpi_dev/users/eberrigan/...` |
| GPU Cluster (Argo/RunAI) | `/hpi/hpi_dev/users/eberrigan/...` |

**Common errors**:
- `MountVolume.SetUp failed` - NFS server unreachable or path doesn't exist
- `hostPath type check failed` - Directory doesn't exist on the node
- Permission denied - Check file ownership matches container user

**Solutions**:
- Verify path exists: `wsl -e bash -c "ls -la /mnt/hpi_dev/users/eberrigan/<dataset>"`
- Check NFS mount: `wsl -e bash -c "mount | grep hpi_dev"`
- Ensure output directory is writable

### WorkflowTemplate Issues

**Problem**: Template not found or validation errors
```bash
# Check: Templates installed
wsl -e bash -c "export KUBECONFIG=~/.kube/kubeconfig-runai-talmo-lab.yaml && kubectl get workflowtemplates -n runai-talmo-lab"
```

**Solutions**:
```bash
# Install templates
wsl -e bash -c "export KUBECONFIG=~/.kube/kubeconfig-runai-talmo-lab.yaml && kubectl apply -f /mnt/c/repos/gapit3-gwas-pipeline/cluster/argo/workflow-templates/ -n runai-talmo-lab"
```

## Open Questions

1. Should we support email/Slack notifications on completion?
2. Should we track retry history to prevent infinite retry loops?
3. Should we integrate with output directory inspection for more accurate incomplete trait detection?
