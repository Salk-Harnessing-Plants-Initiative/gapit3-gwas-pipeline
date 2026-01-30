# Check Workflow Status

Quick status check for Argo workflows. Provides workflow status, task progress, and recent logs.

## Usage

```
/check-workflow <workflow-name>
```

If no workflow name is provided, list recent workflows.

## What to Check

### 1. Workflow Status

```bash
wsl -e bash -c "export KUBECONFIG=~/.kube/kubeconfig-runai-talmo-lab.yaml && argo get <workflow> -n runai-talmo-lab"
```

Report:
- Status: Running, Succeeded, Failed, Stopped
- Duration
- Progress: X/Y tasks complete
- Task breakdown by status (Running, Pending, Completed, Failed)

### 2. Pod Status

```bash
wsl -e bash -c "export KUBECONFIG=~/.kube/kubeconfig-runai-talmo-lab.yaml && kubectl get pods -n runai-talmo-lab -l workflows.argoproj.io/workflow=<workflow> -o wide"
```

Report:
- Which pods are Running vs Pending
- Which nodes they're scheduled on
- Any pods stuck in unusual states

### 3. Recent Logs (if running)

```bash
wsl -e bash -c "export KUBECONFIG=~/.kube/kubeconfig-runai-talmo-lab.yaml && argo logs <workflow> -n runai-talmo-lab --follow=false" 2>&1 | tail -50
```

Report:
- Current processing stage (data loading, BLINK, FarmCPU, MLM, etc.)
- Any errors or warnings
- Progress indicators (SNP counts, iteration numbers)

### 4. List Recent Workflows (if no name provided)

```bash
wsl -e bash -c "export KUBECONFIG=~/.kube/kubeconfig-runai-talmo-lab.yaml && argo list -n runai-talmo-lab"
```

## Quick Summary Format

Provide a concise summary like:

```
Workflow: gapit3-gwas-retry-6hjx8-44tfk
Status: Running (1h 20m)
Progress: 2/5 complete

Tasks:
  - trait-5:  Running (MLM model, 70% through SNP scan)
  - trait-30: Running (FarmCPU model)
  - trait-31: Succeeded
  - trait-28: Pending (waiting for resources)
  - trait-32: Pending (waiting for resources)

Next: trait-28 will start when a running task completes
```

## Failure Detection

If any tasks failed, report:
- Which traits failed
- Failure reason (OOMKilled, Error, Timeout)
- Recommended action

## Related Commands

- `/manage-workflow` - Full workflow management (cleanup, retry, aggregation)
- `/monitor-jobs` - RunAI job monitoring dashboard
