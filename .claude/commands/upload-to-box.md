# Upload GWAS Results to Box

Upload completed GWAS pipeline results to Box cloud storage via rclone.

## Usage

```
/upload-to-box [dataset_name] [--dry-run] [--dest "custom/path"]
```

**Arguments:**
- `dataset_name` - Name of the dataset folder (e.g., `20251208_Elohim_Bello_iron_deficiency_GAPIT_GWAS`). If omitted, uses the current working dataset from CLAUDE.md.
- `--dry-run` - Preview the command without executing
- `--dest` - Custom Box destination (default: `Phenotyping_team_GH/sleap-roots-pipeline-results`)

## Prerequisites

1. **rclone installed** at `C:\Users\Elizabeth\Desktop\rclone_exe\rclone.exe`
2. **Box remote configured** as `box:` in rclone config
3. **Network drive accessible** at `\\multilab-na.ad.salk.edu\hpi_dev\users\eberrigan\`

## Execution Steps

### 1. Validate Source Path

First, verify the source directory exists:

```powershell
# Check if directory exists
Test-Path "\\multilab-na.ad.salk.edu\hpi_dev\users\eberrigan\$DATASET_NAME"
```

If the path does not exist, report error and stop.

### 2. Verify rclone Installation

```powershell
# Check rclone exists
Test-Path "C:\Users\Elizabeth\Desktop\rclone_exe\rclone.exe"

# Verify Box remote is configured
& "C:\Users\Elizabeth\Desktop\rclone_exe\rclone.exe" listremotes
# Should show: box:
```

### 3. Execute Upload

Run from the Desktop directory:

```powershell
cd C:\Users\Elizabeth\Desktop

& "C:\Users\Elizabeth\Desktop\rclone_exe\rclone.exe" copy --update -P `
  "\\multilab-na.ad.salk.edu\hpi_dev\users\eberrigan\$DATASET_NAME" `
  "box:Phenotyping_team_GH/sleap-roots-pipeline-results/$DATASET_NAME"
```

**Flags explained:**
- `copy` - Copy files from source to dest, skipping already copied
- `--update` - Skip files that are newer on destination (safe resume)
- `-P` - Show progress with transfer statistics

### 4. Verify Upload (Optional)

After upload completes, verify integrity:

```powershell
& "C:\Users\Elizabeth\Desktop\rclone_exe\rclone.exe" check `
  "\\multilab-na.ad.salk.edu\hpi_dev\users\eberrigan\$DATASET_NAME" `
  "box:Phenotyping_team_GH/sleap-roots-pipeline-results/$DATASET_NAME"
```

## Example Commands

### Upload specific dataset
```powershell
cd C:\Users\Elizabeth\Desktop

& "C:\Users\Elizabeth\Desktop\rclone_exe\rclone.exe" copy --update -P `
  "\\multilab-na.ad.salk.edu\hpi_dev\users\eberrigan\20251208_Elohim_Bello_iron_deficiency_GAPIT_GWAS" `
  "box:Phenotyping_team_GH/sleap-roots-pipeline-results/20251208_Elohim_Bello_iron_deficiency_GAPIT_GWAS"
```

### Dry-run (preview without uploading)
```powershell
& "C:\Users\Elizabeth\Desktop\rclone_exe\rclone.exe" copy --update -P --dry-run `
  "\\multilab-na.ad.salk.edu\hpi_dev\users\eberrigan\20251208_Elohim_Bello_iron_deficiency_GAPIT_GWAS" `
  "box:Phenotyping_team_GH/sleap-roots-pipeline-results/20251208_Elohim_Bello_iron_deficiency_GAPIT_GWAS"
```

### Upload to custom destination
```powershell
& "C:\Users\Elizabeth\Desktop\rclone_exe\rclone.exe" copy --update -P `
  "\\multilab-na.ad.salk.edu\hpi_dev\users\eberrigan\20251208_Elohim_Bello_iron_deficiency_GAPIT_GWAS" `
  "box:Phenotyping_team_GH/custom-folder/20251208_Elohim_Bello_iron_deficiency_GAPIT_GWAS"
```

## Progress Output

During upload, you'll see real-time statistics:

```
Transferred:   	   15.234 GiB / 45.678 GiB, 33%, 25.432 MiB/s, ETA 20m15s
Transferred:        1234 / 5678, 22%
Elapsed time:     10m30.5s
Transferring:
 * outputs/trait_042.../GAPIT.Manhattan.png: 45% done, 12.3 MiB/s
```

## Resuming Interrupted Uploads

If upload is interrupted, simply re-run the same command. The `--update` flag ensures:
- Files already uploaded are skipped
- Partially uploaded files are completed
- No duplicate uploads occur

## Troubleshooting

### "rclone not found"
Verify rclone exists at the expected location:
```powershell
Test-Path "C:\Users\Elizabeth\Desktop\rclone_exe\rclone.exe"
```

### "Box remote not configured"
Configure Box remote:
```powershell
& "C:\Users\Elizabeth\Desktop\rclone_exe\rclone.exe" config
# Follow prompts to add "box" remote
```

### "Source directory not found"
Check network connectivity and path:
```powershell
# Test network drive access
Test-Path "\\multilab-na.ad.salk.edu\hpi_dev\users\eberrigan"

# List available datasets
Get-ChildItem "\\multilab-na.ad.salk.edu\hpi_dev\users\eberrigan" | Select-Object Name
```

### "Authentication failed"
Re-authorize Box:
```powershell
& "C:\Users\Elizabeth\Desktop\rclone_exe\rclone.exe" config reconnect box:
```

### Slow upload speeds
Check network and try limiting bandwidth:
```powershell
# Limit to 50 MiB/s to avoid network saturation
& "C:\Users\Elizabeth\Desktop\rclone_exe\rclone.exe" copy --update -P --bwlimit 50M `
  "\\multilab-na.ad.salk.edu\hpi_dev\users\eberrigan\$DATASET_NAME" `
  "box:Phenotyping_team_GH/sleap-roots-pipeline-results/$DATASET_NAME"
```

## Related Commands

- `/validate-data` - Validate data before pipeline run
- `/generate-pipeline-summary` - Generate summary report after pipeline completes
- `/aggregate-results` - Aggregate GWAS results before uploading
