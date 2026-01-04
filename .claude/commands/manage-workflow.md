# Manage GWAS Workflow

Comprehensive workflow management for Argo-based GWAS pipelines. This command automates the full workflow lifecycle: assessment, cleanup, retry, and monitoring.

## Usage

```
/manage-workflow <workflow-name> [options]
```

### Arguments
- `workflow-name`: The Argo workflow name (e.g., `gapit3-gwas-parallel-6hjx8`)

### Options
- `--dry-run`: Preview actions without executing (read-only)
- `--auto`: Proceed without confirmations (for automation)
- `--skip-cleanup`: Skip the cleanup phase
- `--skip-retry`: Skip retry generation (assessment only)

## Phases

### Phase 1: Assessment
Fetch workflow status and categorize task outcomes:

```bash
# Get workflow status (use this exact pattern for WSL)
wsl -e bash -c "export KUBECONFIG=~/.kube/kubeconfig-runai-talmo-lab.yaml && argo get <workflow> -n runai-talmo-lab"
```

**Failure Categories:**
| Category | Detection | Remediation |
|----------|-----------|-------------|
| OOMKilled | Exit code 137, "OOMKilled" in message | Use high-memory template (96Gi/16 CPU) |
| Stuck | PodInitializing > 10 minutes | Stop workflow, retry |
| Timeout | DeadlineExceeded | Increase deadline or investigate |
| Error | Other failures | Check pod logs for details |

**Trait Index Extraction:**
- From parallel tasks: `run-all-traits(3:5)` → trait index 5
- From retry tasks: `retry-trait-5` → trait index 5

### Phase 2: Cleanup
Stop stalled workflows and clean incomplete outputs:

```bash
# Stop stalled workflow
wsl -e bash -c "export KUBECONFIG=~/.kube/kubeconfig-runai-talmo-lab.yaml && argo stop <workflow> -n runai-talmo-lab"
```

**Output Directory Inspection:**
- Windows paths: `Z:\users\eberrigan\<dataset>\outputs\trait_NNN_*`
- Uses **Filter file** (`GAPIT.Association.Filter_GWAS_results.csv`) as definitive completion signal
- GAPIT only creates Filter file after ALL models complete successfully
- Traits with partial outputs (GWAS_Results but no Filter) are correctly detected as incomplete
- Show what will be deleted before proceeding
- Require explicit confirmation

### Phase 3: Retry
Generate and submit retry workflow for failed traits:

```bash
# Generate retry workflow with high-memory and aggregation
wsl -e bash -c "export KUBECONFIG=~/.kube/kubeconfig-runai-talmo-lab.yaml && cd /mnt/c/repos/gapit3-gwas-pipeline && ./scripts/retry-argo-traits.sh \
  --workflow <original-workflow> \
  --traits <comma-separated-list> \
  --highmem \
  --aggregate \
  --submit"
```

**Parameters Propagated:**
- SNP FDR threshold (e.g., `snp-fdr=0.05`)
- Models, paths, image from original workflow
- Uses high-memory template for OOM failures

### Phase 4: Monitoring
Track retry workflow until completion:

```bash
# Check retry progress
wsl -e bash -c "export KUBECONFIG=~/.kube/kubeconfig-runai-talmo-lab.yaml && argo get <retry-workflow> -n runai-talmo-lab"
```

**Report:**
- Progress: X/Y tasks complete
- Status: Running, Succeeded, Failed
- Aggregation: collect-results task status

## Troubleshooting

### Argo Workflow Access

**KUBECONFIG not found:**
```bash
# Verify KUBECONFIG exists
wsl -e bash -c "ls -la ~/.kube/kubeconfig-runai-talmo-lab.yaml"

# Expected: -rw------- 1 user user XXXX date kubeconfig-runai-talmo-lab.yaml
```

**Authentication failures:**
Always use this pattern (explicit KUBECONFIG export):
```bash
wsl -e bash -c "export KUBECONFIG=~/.kube/kubeconfig-runai-talmo-lab.yaml && <command>"
```

**Common errors:**
- `error: no configuration has been provided` → KUBECONFIG not set
- `wsl: Processing /etc/fstab with mount -a failed` → Harmless warning, ignore

### Kubernetes Access

**Cannot connect to cluster:**
```bash
# Check cluster connectivity
wsl -e bash -c "export KUBECONFIG=~/.kube/kubeconfig-runai-talmo-lab.yaml && kubectl cluster-info"
```

**Solutions:**
- Verify VPN connection if required
- Check KUBECONFIG file exists and is valid
- Verify namespace `runai-talmo-lab` exists

**Common errors:**
- `Unable to connect to the server` → Network/VPN issue
- `forbidden: User cannot list resource` → RBAC permissions issue
- `workflowtaskresults.argoproj.io is forbidden (exit code 64)` → Known RBAC limitation, workflow may still have succeeded

### GPU Cluster Access (RunAI)

**Pods stuck in Pending/PodInitializing:**
```bash
# Check node availability
wsl -e bash -c "export KUBECONFIG=~/.kube/kubeconfig-runai-talmo-lab.yaml && kubectl get nodes"

# Check pod events
wsl -e bash -c "export KUBECONFIG=~/.kube/kubeconfig-runai-talmo-lab.yaml && kubectl describe pod <pod-name> -n runai-talmo-lab | tail -30"
```

**Solutions:**
- PodInitializing > 10 min: Stop workflow, retry - likely cluster scheduling issue
- Insufficient memory: Use `--highmem` flag (96Gi instead of 64Gi)
- Node selector issues: Check RunAI quota and node affinity

**Resource requirements:**
| Template | Memory Request | Memory Limit | CPU Request | CPU Limit |
|----------|----------------|--------------|-------------|-----------|
| Normal   | 64Gi           | 72Gi         | 12          | 16        |
| High-mem | 96Gi           | 104Gi        | 16          | 20        |

### Data Access (NFS/hostPath)

**Path mapping:**
| Context | Base Path | Example |
|---------|-----------|---------|
| Windows (PowerShell) | `Z:\users\eberrigan\...` | `Z:\users\eberrigan\20251122_...\outputs` |
| WSL (bash) | `/mnt/hpi_dev/users/eberrigan/...` | `/mnt/hpi_dev/users/eberrigan/20251122_...\outputs` |
| GPU Cluster (Argo) | `/hpi/hpi_dev/users/eberrigan/...` | `/hpi/hpi_dev/users/eberrigan/20251122_...\outputs` |

**Verify paths exist:**
```bash
# From WSL
wsl -e bash -c "ls -la /mnt/hpi_dev/users/eberrigan/<dataset>"

# Check NFS mount
wsl -e bash -c "mount | grep hpi_dev"
```

**Common errors:**
- `MountVolume.SetUp failed` → NFS server unreachable or path doesn't exist
- `hostPath type check failed` → Directory doesn't exist on the node
- Permission denied → Check file ownership matches container user

### WorkflowTemplate Issues

**Template not found:**
```bash
# Check installed templates
wsl -e bash -c "export KUBECONFIG=~/.kube/kubeconfig-runai-talmo-lab.yaml && kubectl get workflowtemplates -n runai-talmo-lab"

# Install templates
wsl -e bash -c "export KUBECONFIG=~/.kube/kubeconfig-runai-talmo-lab.yaml && kubectl apply -f /mnt/c/repos/gapit3-gwas-pipeline/cluster/argo/workflow-templates/ -n runai-talmo-lab"
```

## Examples

### Interactive Assessment and Retry

```bash
/manage-workflow gapit3-gwas-parallel-6hjx8
```

1. Claude fetches workflow status
2. Reports: "Found 5 failures: 1 OOMKilled (trait 5), 4 stuck (traits 28, 30, 31, 32)"
3. Asks: "Stop stalled workflow? [y/n]"
4. Asks: "Generate retry with high-memory? [y/n]"
5. Submits retry workflow, reports name
6. Monitors until complete

### Dry Run (Preview Only)

```bash
/manage-workflow gapit3-gwas-parallel-6hjx8 --dry-run
```

Shows what would be done without executing:
- [DRY RUN] Would stop workflow
- [DRY RUN] Would cleanup 0 incomplete directories
- [DRY RUN] Would submit retry for traits: 5, 28, 30, 31, 32

### Assessment Only

```bash
/manage-workflow gapit3-gwas-parallel-6hjx8 --skip-cleanup --skip-retry
```

Only reports workflow status and failure analysis.

### Fully Automated

```bash
/manage-workflow gapit3-gwas-parallel-6hjx8 --auto
```

Proceeds through all phases without confirmation prompts.

## Decision Tree

```
Workflow Status?
├── All tasks succeeded
│   └── Check aggregation (collect-results task)
│       ├── Aggregation ran → "Complete! No action needed"
│       └── Aggregation missing → "Run standalone aggregation" (see below)
├── Has failures
│   ├── OOMKilled failures → Use --highmem template
│   ├── Stuck pods (>10min) → Stop workflow first
│   ├── Timeout failures → Recommend investigation
│   └── Other errors → Show logs, recommend investigation
└── Still running
    └── "Workflow still in progress. Monitor with: argo watch <workflow>"
```

### Standalone Aggregation Command

When aggregation is missing (workflow stopped before `collect-results` ran):

```bash
# Submit standalone aggregation workflow
argo submit cluster/argo/workflows/gapit3-aggregation-standalone.yaml \
  -p output-hostpath="/hpi/hpi_dev/users/YOUR_USERNAME/outputs" \
  -p batch-id="gapit3-gwas-parallel-XXXXX" \
  -n runai-talmo-lab
```

Or from Windows via WSL:
```bash
wsl -e bash -c "export KUBECONFIG=~/.kube/kubeconfig-runai-talmo-lab.yaml && argo submit /mnt/c/repos/gapit3-gwas-pipeline/cluster/argo/workflows/gapit3-aggregation-standalone.yaml -p output-hostpath='/hpi/hpi_dev/users/YOUR_USERNAME/outputs' -p batch-id='gapit3-gwas-parallel-XXXXX' -n runai-talmo-lab"
```

## Related Commands

- `/monitor-jobs` - Real-time job monitoring dashboard
- `/cleanup-jobs` - Manual cleanup of completed/failed jobs
- `/aggregate-results` - Standalone results aggregation
- `/submit-test-workflow` - Submit new workflows

## Completeness Detection

### Dual Detection Approach

This command uses two complementary detection methods to identify incomplete traits:

1. **Workflow Status Detection** - Extracts failed traits from Argo workflow status (tasks marked ✖)
2. **Directory-Based Detection** - Inspects output directories for missing Filter files

Both methods are needed because:
- **Workflow-only detection misses "running-when-stopped" traits**: When a workflow is stopped mid-execution (`argo stop`), traits that were running get terminated but aren't marked as failed
- **Directory-only detection might not have access to workflow metadata**: The directory approach provides a reliable fallback

### Filter File as Completion Signal

The `GAPIT.Association.Filter_GWAS_results.csv` file is the **definitive completion signal**:

- GAPIT creates this file only after **ALL models** complete successfully
- A trait with GWAS_Results files but no Filter file is **incomplete** (partial output from interrupted run)
- A trait with Filter file is considered **complete** (all models finished)

### Detection Logic

```
For each trait directory:
├── No directory exists
│   └── Status: MISSING (needs retry)
├── Directory exists but no Filter file
│   └── Status: INCOMPLETE (needs retry)
│       └── Note: GWAS_Results may exist (from partial run)
└── Filter file exists
    └── Status: COMPLETE (no action needed)
```

### Why This Matters

When a workflow is stopped mid-execution:
1. Some traits were "Running" at stop time
2. These create partial outputs (GWAS_Results for early models like BLINK)
3. The old detection (checking GWAS_Results) would miss these as "incomplete"
4. The new detection (checking Filter file) correctly identifies them for retry

## Implementation Notes

This command is a Claude Code slash command that uses reasoning to:
1. Intelligently categorize failures based on exit codes and messages
2. Determine appropriate remediation (high-memory, retry, investigate)
3. Adapt to varying scenarios (all complete, partial failures, stuck pods)
4. Provide clear explanations and recommendations

The command leverages existing infrastructure:
- `scripts/retry-argo-traits.sh` for retry workflow generation
- `argo` CLI for workflow operations
- `kubectl` for Kubernetes operations
