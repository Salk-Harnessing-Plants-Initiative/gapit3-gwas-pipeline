## Why

Currently, GWAS pipeline workflows require manual intervention after completion to:
1. Monitor workflow status until done
2. Validate outputs (Filter files for all traits, all models complete)
3. Run aggregation on the cluster
4. Upload results to Box

This prevents unattended execution and requires users to be present when workflows complete. For long-running workflows (18-24 hours), this is impractical.

## What Changes

- Add new autonomous monitoring script (`scripts/autonomous-pipeline-monitor.sh`) that runs as a background process in WSL
- Script executes these phases sequentially:
  1. **Monitor**: Poll Argo workflow status until completion or failure
  2. **Validate**: Count Filter files and verify expected trait count
  3. **Aggregate**: Submit standalone aggregation workflow to cluster via Argo
  4. **Upload**: Trigger rclone sync to Box using PowerShell

## Impact

- Affected specs: New `automation` capability (no existing specs affected)
- Affected code:
  - New: `scripts/autonomous-pipeline-monitor.sh`
  - Uses existing: `cluster/argo/workflows/gapit3-aggregation-standalone.yaml`
  - Uses existing: Argo CLI for workflow status
  - Uses existing: rclone configuration for Box uploads (via PowerShell.exe from WSL)
  - Uses existing: Filter file detection pattern from `/manage-workflow` command

## Design Decisions

### Background Process Approach
The script runs as a detached WSL bash process (using `nohup`) that persists even if the terminal session ends. This is simpler than:
- Setting up a cron job (requires cron configuration)
- Using a Kubernetes CronJob (requires cluster access)
- Running a daemon service (requires systemd configuration)

### Polling Strategy
- Check workflow status every 5 minutes
- Maximum wait time: 48 hours (configurable via `--timeout`)
- Immediate exit if workflow fails

### Validation Checks (reusing patterns from manage-workflow.md)
1. **Filter file detection**: Count `GAPIT.Association.Filter_GWAS_results.csv` files
2. **Expected trait count**: Compare to `--expected-traits` parameter
3. **Success threshold**: Allow partial success (e.g., 95% complete)

### Aggregation on Cluster (not local)
Aggregation runs on the cluster via the existing `gapit3-aggregation-standalone.yaml` workflow:
- No R installation required locally
- Uses same Docker image as pipeline
- Results written to same output directory

### Box Upload via PowerShell
Since rclone is installed on Windows (not WSL), the script calls PowerShell from WSL:
```bash
powershell.exe -NoProfile -Command "& 'C:\Users\Elizabeth\Desktop\rclone_exe\rclone.exe' copy --update ..."
```

### Logging
All output logged to `$OUTPUT_DIR/pipeline_monitor.log` with timestamps.

## References

- Existing monitoring: `.claude/commands/check-workflow.md`
- Aggregation workflow: `cluster/argo/workflows/gapit3-aggregation-standalone.yaml`
- Aggregation command: `.claude/commands/aggregate-results.md`
- Upload command: `.claude/commands/upload-to-box.md`
- Validation pattern: `.claude/commands/manage-workflow.md` (Filter file detection)
