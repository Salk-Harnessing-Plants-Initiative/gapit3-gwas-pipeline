# RunAI Quick Reference for GAPIT3

Quick command reference for running GAPIT3 GWAS analysis with RunAI CLI.

## Project Info

- **Project name**: `talmo-lab`
- **Kubernetes namespace**: `runai-talmo-lab`
- **Image**: `ghcr.io/salk-harnessing-plants-initiative/gapit3-gwas-pipeline:sha-bc10fc8-test`
- **Data path**: `/hpi/hpi_dev/users/eberrigan/20251107_GAPIT_pipeline_tests/data`
- **Output path**: `/hpi/hpi_dev/users/eberrigan/20251107_GAPIT_pipeline_tests/outputs`

## Quick Commands

### Submit Single Trait Job

```bash
runai workspace submit gapit3-trait-<INDEX> \
  --project talmo-lab \
  --image ghcr.io/salk-harnessing-plants-initiative/gapit3-gwas-pipeline:sha-bc10fc8-test \
  --cpu-core-request 12 \
  --cpu-memory-request 32G \
  --host-path path=/hpi/hpi_dev/users/eberrigan/20251107_GAPIT_pipeline_tests/data,mount=/data,mount-propagation=HostToContainer \
  --host-path path=/hpi/hpi_dev/users/eberrigan/20251107_GAPIT_pipeline_tests/outputs,mount=/outputs,mount-propagation=HostToContainer,readwrite \
  --environment OPENBLAS_NUM_THREADS=12 \
  --environment OMP_NUM_THREADS=12 \
  --command -- /scripts/entrypoint.sh run-single-trait \
    --trait-index <INDEX> \
    --config /config/config.yaml \
    --output-dir /outputs \
    --models BLINK,FarmCPU \
    --threads 12
```

Replace `<INDEX>` with the trait column number (2-187).

### List All Workloads

```bash
runai workspace list
```

Filter to GAPIT3 jobs only:
```bash
runai workspace list | grep gapit3
```

### Check Specific Workspace

```bash
runai workspace describe <WORKSPACE_NAME> -p talmo-lab
```

Example:
```bash
runai workspace describe gapit3-trait-2 -p talmo-lab
```

### View Logs

```bash
runai workload logs workspace <WORKSPACE_NAME> -p talmo-lab --follow
```

Example:
```bash
runai workload logs workspace gapit3-trait-2 -p talmo-lab --follow
```

### Delete Workspace

```bash
runai workload delete workspace <WORKSPACE_NAME> -p talmo-lab
```

Example:
```bash
runai workload delete workspace gapit3-trait-2 -p talmo-lab
```

## Common Workflows

### Test Single Trait

```bash
# Submit test job
runai workspace submit gapit3-trait-2-test \
  --project talmo-lab \
  --image ghcr.io/salk-harnessing-plants-initiative/gapit3-gwas-pipeline:sha-bc10fc8-test \
  --cpu-core-request 12 \
  --cpu-memory-request 32G \
  --host-path path=/hpi/hpi_dev/users/eberrigan/20251107_GAPIT_pipeline_tests/data,mount=/data,mount-propagation=HostToContainer \
  --host-path path=/hpi/hpi_dev/users/eberrigan/20251107_GAPIT_pipeline_tests/outputs,mount=/outputs,mount-propagation=HostToContainer,readwrite \
  --environment OPENBLAS_NUM_THREADS=12 \
  --environment OMP_NUM_THREADS=12 \
  --command -- /scripts/entrypoint.sh run-single-trait \
    --trait-index 2 \
    --config /config/config.yaml \
    --output-dir /outputs \
    --models BLINK,FarmCPU \
    --threads 12

# Monitor
runai workspace list | grep gapit3-trait-2-test

# View logs
runai workload logs workspace gapit3-trait-2-test -p talmo-lab --follow

# Check results
ls -lh /hpi/hpi_dev/users/eberrigan/20251107_GAPIT_pipeline_tests/outputs/

# Clean up
runai workload delete workspace gapit3-trait-2-test -p talmo-lab
```

### Submit Multiple Traits

```bash
# Submit traits 2, 3, 4 for testing
for trait in 2 3 4; do
  runai workspace submit gapit3-trait-$trait \
    --project talmo-lab \
    --image ghcr.io/salk-harnessing-plants-initiative/gapit3-gwas-pipeline:sha-bc10fc8-test \
    --cpu-core-request 12 \
    --cpu-memory-request 32G \
    --host-path path=/hpi/hpi_dev/users/eberrigan/20251107_GAPIT_pipeline_tests/data,mount=/data,mount-propagation=HostToContainer \
    --host-path path=/hpi/hpi_dev/users/eberrigan/20251107_GAPIT_pipeline_tests/outputs,mount=/outputs,mount-propagation=HostToContainer,readwrite \
    --environment OPENBLAS_NUM_THREADS=12 \
    --environment OMP_NUM_THREADS=12 \
    --command -- /scripts/entrypoint.sh run-single-trait \
      --trait-index $trait \
      --config /config/config.yaml \
      --output-dir /outputs \
      --models BLINK,FarmCPU \
      --threads 12
  sleep 2
done
```

### Monitor Progress

```bash
# Watch all GAPIT3 jobs
watch -n 10 'runai workspace list | grep gapit3'

# Count statuses
runai workspace list | grep gapit3 | awk '{print $4}' | sort | uniq -c
```

### Clean Up Failed Jobs

```bash
# List failed workspaces
runai workspace list | grep gapit3 | grep -E "Failed|Error"

# Delete all failed GAPIT3 workspaces
runai workspace list | grep gapit3 | grep -E "Failed|Error" | awk '{print $1}' | \
  xargs -I {} runai workload delete workspace {} -p talmo-lab
```

## Troubleshooting

### Job stuck in "Initializing"

```bash
# Get detailed status
runai workspace describe <WORKSPACE_NAME> -p talmo-lab

# Check pod events via kubectl
export KUBECONFIG=~/.kube/kubeconfig-runai-talmo-lab.yaml
kubectl get pods -n runai-talmo-lab | grep <WORKSPACE_NAME>
kubectl describe pod <POD_NAME> -n runai-talmo-lab
```

### Can't see logs

```bash
# Check if pod is running
runai workspace describe <WORKSPACE_NAME> -p talmo-lab

# Alternative: Use kubectl
kubectl logs -n runai-talmo-lab <POD_NAME> --follow
```

### Image pull errors

Check image exists and is accessible:
```bash
docker pull ghcr.io/salk-harnessing-plants-initiative/gapit3-gwas-pipeline:sha-bc10fc8-test
```

## Helper Scripts

For batch operations, use the helper scripts:

```bash
# Submit all 186 traits with concurrency control
./scripts/submit-all-traits-runai.sh

# Monitor progress with live dashboard
./scripts/monitor-runai-jobs.sh --watch
```

## Key Differences from Old RunAI CLI

| Old Command | New Command |
|-------------|-------------|
| `runai submit` | `runai workspace submit` |
| `runai list jobs` | `runai workspace list` |
| `runai describe job` | `runai workspace describe` |
| `runai logs` | `runai workload logs workspace` |
| `runai delete job` | `runai workload delete workspace` |
| `--cpu 12` | `--cpu-core-request 12` |
| `--memory 32G` | `--cpu-memory-request 32G` |
| `--host-path /path:/mount:ro` | `--host-path path=/path,mount=/mount,mount-propagation=HostToContainer` |
| `--project runai-talmo-lab` | `--project talmo-lab` |

## Additional Resources

- Full guide: [MANUAL_RUNAI_EXECUTION.md](MANUAL_RUNAI_EXECUTION.md)
- RBAC issue: [RBAC_PERMISSIONS_ISSUE.md](RBAC_PERMISSIONS_ISSUE.md)
- RunAI docs: https://docs.run.ai/
