## Why

After GWAS pipeline completion, users routinely upload results to Box cloud storage using rclone. This manual process requires remembering the correct command syntax, path mappings, and verifying uploads succeed. A Claude command would standardize this workflow, reduce errors, and provide upload progress feedback.

## What Changes

- **ADDED**: `/upload-to-box` Claude command for uploading pipeline results to Box via rclone
- Path validation ensures the source directory exists before upload
- Automatic path translation from Windows UNC paths to the expected format
- Upload verification with progress monitoring and error handling
- Dry-run mode for previewing commands without execution
- Support for both current working dataset and explicit paths

## Impact

- Affected specs: `claude-commands`
- Affected code: `.claude/commands/upload-to-box.md` (new file)
- Dependencies: rclone must be installed and configured with Box remote