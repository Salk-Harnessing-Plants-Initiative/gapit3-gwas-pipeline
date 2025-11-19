# Monitor GWAS Jobs

Monitor RunAI jobs or Argo workflows with real-time status updates.

## RunAI Jobs Dashboard

```bash
# Interactive dashboard with auto-refresh
./scripts/monitor-runai-jobs.sh
```

## Quick Status Check

```bash
# List all GAPIT3 jobs
runai list jobs | grep gapit3

# Show detailed status for specific job
runai describe job gapit3-trait-2

# Get logs from running job
runai logs gapit3-trait-2
```

## Argo Workflows

```bash
# List all workflows
argo list

# Watch specific workflow
argo watch <workflow-name>

# Get workflow status
argo get <workflow-name>

# View logs for specific step
argo logs <workflow-name> -c main

# Follow logs in real-time
argo logs -f <workflow-name>
```

## Monitor Script Features

The `monitor-runai-jobs.sh` script provides:

### Real-time Dashboard
```bash
./scripts/monitor-runai-jobs.sh

# Output:
═══════════════════════════════════════════════════════════
GAPIT3 GWAS Job Monitor
Updated: 2025-01-15 14:23:45
═══════════════════════════════════════════════════════════

SUMMARY:
  Running:    45 jobs
  Completed:  102 jobs
  Failed:     3 jobs
  Total:      150 jobs

RUNNING JOBS:
  gapit3-trait-012  Running  12m   16/32 GB  8/12 CPU
  gapit3-trait-045  Running  8m    24/32 GB  11/12 CPU
  ...

FAILED JOBS:
  gapit3-trait-089  Failed   Error: OOMKilled
  gapit3-trait-134  Failed   Error: ImagePullBackOff
  ...

Press Ctrl+C to exit. Refreshing every 10s...
```

### Export Status
```bash
# Save status to file
./scripts/monitor-runai-jobs.sh --export status.json

# Generate summary report
./scripts/monitor-runai-jobs.sh --summary > summary.txt
```

## Filter by Status

```bash
# Show only running jobs
runai list jobs | grep -E "gapit3.*Running"

# Show only failed jobs
runai list jobs | grep -E "gapit3.*Failed"

# Show only completed jobs
runai list jobs | grep -E "gapit3.*Succeeded"
```

## Check Specific Trait

```bash
# Monitor single trait
TRAIT=45
runai describe job gapit3-trait-$(printf "%03d" $TRAIT)
runai logs gapit3-trait-$(printf "%03d" $TRAIT) --follow
```

## Performance Metrics

```bash
# Show resource usage for all jobs
runai list jobs -o wide | grep gapit3

# Get detailed metrics
kubectl top pods -l job-name=gapit3-trait-002
```

## Job Timeline

```bash
# Show when jobs started/finished
argo get <workflow-name> -o json | jq '.status.nodes[] | {name: .displayName, phase: .phase, startedAt: .startedAt, finishedAt: .finishedAt}'
```

## Troubleshooting Failed Jobs

```bash
# View error logs
runai logs gapit3-trait-089 --tail=100

# Check events
kubectl describe pod -l job-name=gapit3-trait-089

# Common errors:
# - OOMKilled → Increase memory
# - ImagePullBackOff → Check GHCR access
# - Error → Check logs for R/GAPIT errors
```

## Automated Alerts

Set up notifications for job completion:

```bash
# Watch until all complete
while true; do
  RUNNING=$(runai list jobs | grep -c "gapit3.*Running")
  if [ "$RUNNING" -eq 0 ]; then
    echo "All jobs completed!" | mail -s "GWAS Pipeline Done" $USER@example.com
    break
  fi
  sleep 60
done
```

## Export Results After Monitoring

Once jobs complete:

```bash
# Aggregate results
./scripts/aggregate-runai-results.sh

# Or use command
/aggregate-results
```

## Watch Multiple Jobs

```bash
# Terminal multiplexer (tmux/screen) for parallel monitoring
tmux new-session \; \
  send-keys 'runai logs gapit3-trait-002 --follow' C-m \; \
  split-window -v \; \
  send-keys 'runai logs gapit3-trait-045 --follow' C-m \; \
  split-window -v \; \
  send-keys './scripts/monitor-runai-jobs.sh' C-m
```

## Related Commands

- `/submit-test-workflow` - Submit jobs to monitor
- `/aggregate-results` - Collect results after completion
- `/cleanup-jobs` - Clean up completed jobs