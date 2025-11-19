# Cleanup Completed Jobs

Clean up completed, failed, or orphaned RunAI jobs and Argo workflows.

**WARNING**: This command deletes jobs and associated resources. Always verify what will be deleted before proceeding.

## Safe Command (Recommended)

```bash
# Interactive cleanup with confirmation and dry-run preview
./scripts/cleanup-runai.sh
```

## Safety Guardrails

### 1. Always Preview First (Dry Run)
```bash
# See what WOULD be deleted without actually deleting
./scripts/cleanup-runai.sh --dry-run

# Output shows:
Would delete:
  gapit3-trait-002 (Succeeded, completed 2h ago)
  gapit3-trait-003 (Succeeded, completed 2h ago)
  gapit3-trait-089 (Failed, OOMKilled)
Total: 3 jobs (0 running, 2 completed, 1 failed)

WARNING: This will permanently delete these jobs and their logs.
```

### 2. Never Delete Running Jobs
```bash
# The script ALWAYS excludes running jobs by default
./scripts/cleanup-runai.sh --all

# Explicitly protect running jobs
./scripts/cleanup-runai.sh --exclude-running --all
```

### 3. Verify Results Backed Up
```bash
# BEFORE cleanup, ensure results are aggregated
./scripts/aggregate-runai-results.sh

# Verify aggregation succeeded
ls -lh outputs/aggregated_results/summary_table.csv

# Then safe to cleanup
./scripts/cleanup-runai.sh --completed --yes
```

### 4. Clean by Category Only
```bash
# Clean ONLY completed jobs (safest)
./scripts/cleanup-runai.sh --completed

# Clean ONLY failed jobs
./scripts/cleanup-runai.sh --failed

# Avoid --all unless you're certain
```

### 5. Age-Based Cleanup (Extra Safe)
```bash
# Only delete jobs older than 24 hours
./scripts/cleanup-runai.sh --older-than 24h

# Only delete jobs older than 7 days
./scripts/cleanup-runai.sh --older-than 7d
```

## Command Options

### Interactive Mode (Safest - Default)
```bash
./scripts/cleanup-runai.sh

# Prompts:
Found 102 completed jobs
Found 3 failed jobs
Found 0 running jobs

What would you like to clean up?
1) Completed jobs only
2) Failed jobs only
3) Both completed and failed
4) Show detailed list first
5) Cancel
Select option:
```

### Batch Mode with Confirmation
```bash
# Requires explicit confirmation even with --yes
./scripts/cleanup-runai.sh --completed --yes

# Shows summary and asks: "Type 'DELETE' to confirm:"
```

### Dry Run (Always Safe)
```bash
# Preview without deleting ANYTHING
./scripts/cleanup-runai.sh --dry-run
./scripts/cleanup-runai.sh --all --dry-run
./scripts/cleanup-runai.sh --failed --dry-run
```

## Argo Workflows Cleanup

### Safe Argo Cleanup
```bash
# List workflows first
argo list

# Delete specific workflow only
argo delete <workflow-name>

# Delete completed workflows older than 7 days
argo delete --completed --older 7d

# Preview what would be deleted
argo delete --completed --dry-run
```

### Dangerous Argo Commands (Avoid)
```bash
# DO NOT USE without extreme caution:
# argo delete --all          # Deletes EVERYTHING including running
# kubectl delete ns argo      # Deletes entire namespace
```

## Step-by-Step Safe Cleanup Workflow

### Step 1: Check Status
```bash
# See what's running vs completed
./scripts/monitor-runai-jobs.sh

# Count by status
runai list jobs | grep gapit3 | awk '{print $3}' | sort | uniq -c
```

### Step 2: Aggregate Results
```bash
# Backup all results FIRST
./scripts/aggregate-runai-results.sh

# Verify aggregation
cat outputs/aggregated_results/summary_table.csv | wc -l
# Should show expected trait count + 1 (header)
```

### Step 3: Dry Run
```bash
# Preview deletions
./scripts/cleanup-runai.sh --completed --dry-run

# Review output carefully
```

### Step 4: Cleanup Completed Only
```bash
# Delete only completed jobs
./scripts/cleanup-runai.sh --completed --yes
```

### Step 5: Handle Failed Jobs Separately
```bash
# List failed jobs to investigate
runai list jobs | grep "gapit3.*Failed"

# Check why they failed
runai logs gapit3-trait-089 --tail=50

# Decide: retry or delete
# Retry: ./scripts/retry-failed-traits.sh
# Delete: ./scripts/cleanup-runai.sh --failed --yes
```

### Step 6: Verify
```bash
# Check remaining jobs
runai list jobs | grep gapit3

# Should only see running jobs (if any)
```

## Selective Cleanup (Advanced)

### Clean Specific Trait Range
```bash
# Delete jobs for traits 1-50 ONLY (completed/failed only)
for i in {1..50}; do
  JOB="gapit3-trait-$(printf "%03d" $i)"
  STATUS=$(runai list jobs | grep "^$JOB" | awk '{print $3}')
  if [[ "$STATUS" == "Succeeded" || "$STATUS" == "Failed" ]]; then
    echo "Deleting $JOB ($STATUS)"
    runai delete job $JOB
  else
    echo "Skipping $JOB ($STATUS - not completed/failed)"
  fi
done
```

### Clean by Failure Reason
```bash
# Delete only OOMKilled jobs (safe to retry with more memory)
./scripts/cleanup-runai.sh --filter OOMKilled

# Delete only ImagePullBackOff jobs (safe to retry after fixing image)
./scripts/cleanup-runai.sh --filter ImagePullBackOff
```

### Preserve Recent Jobs
```bash
# Keep jobs from last 6 hours, delete older completed
./scripts/cleanup-runai.sh --completed --keep-recent 6h
```

## Emergency Rollback

If you deleted jobs by accident:

```bash
# Check if logs still exist in kubectl
kubectl get pods | grep gapit3

# Retrieve logs from terminated pods (if still available)
kubectl logs <pod-name> > recovered-logs.txt

# Results files should still exist in outputs/ directory
ls outputs/trait_*/
```

## Protection Features in cleanup-runai.sh

The script includes these safety features:

1. **No silent deletion**: Always shows what will be deleted
2. **Running job protection**: Never deletes running jobs unless --force-running flag used
3. **Confirmation prompts**: Requires explicit confirmation for batch mode
4. **Dry-run mode**: Test deletions without executing
5. **Age filters**: Only delete jobs older than threshold
6. **Status filters**: Only delete specific status types
7. **Detailed logging**: Records all deletions to log file
8. **Count verification**: Shows counts before/after deletion

## Environment Variable Safety Checks

```bash
# Require explicit confirmation via environment variable for --all
CONFIRM_DELETE_ALL=yes ./scripts/cleanup-runai.sh --all --yes

# Without env var, --all will fail with safety error
```

## Related Commands

- `/monitor-jobs` - Check job status before cleanup
- `/aggregate-results` - **ALWAYS run this before cleanup**

## When NOT to Cleanup

Do NOT cleanup if:
- Jobs are still running
- Results not yet aggregated
- Investigating failures
- Within 24h of submission (give time to review)
- Not sure what jobs do

Safe to cleanup when:
- All jobs completed or failed
- Results aggregated and verified
- Logs reviewed for failed jobs
- More than 24h after completion
- Disk space needed

## Troubleshooting

### "Permission denied" errors
```bash
# Check RBAC permissions
kubectl auth can-i delete jobs
./scripts/check-argo-permissions.sh
```

### Jobs won't delete (stuck)
```bash
# Check job status
kubectl describe job gapit3-trait-002

# Force delete if necessary (last resort)
kubectl delete job gapit3-trait-002 --force --grace-period=0
```

### Accidentally deleted important job
```bash
# Check if output files still exist
ls outputs/trait_*/

# Resubmit single trait if needed
runai submit gapit3-trait-002 \
  --image ghcr.io/.../gapit3:latest \
  --environment TRAIT_INDEX=2 \
  ...
```