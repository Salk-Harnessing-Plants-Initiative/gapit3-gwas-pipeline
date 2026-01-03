## ADDED Requirements

### Requirement: Box Upload Command

The system SHALL provide a `/upload-to-box` Claude command that uploads completed GWAS pipeline results to Box cloud storage via rclone (located at `C:\Users\Elizabeth\Desktop\rclone_exe\rclone.exe`), with path validation and progress monitoring.

#### Scenario: Upload with explicit dataset path
- **GIVEN** user has completed a GWAS pipeline run at `\\multilab-na.ad.salk.edu\hpi_dev\users\eberrigan\20251208_Elohim_Bello_iron_deficiency_GAPIT_GWAS`
- **WHEN** user invokes `/upload-to-box 20251208_Elohim_Bello_iron_deficiency_GAPIT_GWAS`
- **THEN** system validates the source path exists on the network drive
- **AND** constructs the rclone command with correct source and destination paths
- **AND** executes from Desktop directory: `"C:\Users\Elizabeth\Desktop\rclone_exe\rclone.exe" copy --update -P "\\multilab-na.ad.salk.edu\hpi_dev\users\eberrigan\20251208_..." box:"Phenotyping_team_GH/sleap-roots-pipeline-results/20251208_..."`
- **AND** displays upload progress with transfer statistics
- **AND** reports completion status (files transferred, total size, duration)

#### Scenario: Upload with default dataset from CLAUDE.md
- **GIVEN** CLAUDE.md specifies current working dataset as `20251122_Elohim_Bello_iron_deficiency_GAPIT_GWAS`
- **WHEN** user invokes `/upload-to-box` without arguments
- **THEN** system uses the current working dataset from CLAUDE.md context
- **AND** proceeds with upload as if dataset name was explicitly provided

#### Scenario: Validate source path exists before upload
- **GIVEN** user provides a dataset name that does not exist on the network drive
- **WHEN** user invokes `/upload-to-box nonexistent_dataset`
- **THEN** system checks if `\\multilab-na.ad.salk.edu\hpi_dev\users\eberrigan\nonexistent_dataset` exists
- **AND** reports error: "Source directory not found: [path]"
- **AND** suggests verifying the dataset name and network connectivity
- **AND** does NOT attempt the rclone upload

#### Scenario: Dry-run mode previews upload without executing
- **GIVEN** user wants to verify the command before executing
- **WHEN** user invokes `/upload-to-box 20251208_... --dry-run`
- **THEN** system displays the full rclone command that would be executed
- **AND** shows source and destination paths
- **AND** does NOT execute the upload
- **AND** labels output clearly as "[DRY RUN]"

#### Scenario: Verify rclone is available at known location
- **GIVEN** rclone is installed at `C:\Users\Elizabeth\Desktop\rclone_exe\rclone.exe`
- **WHEN** user invokes `/upload-to-box`
- **THEN** system checks if rclone exists at the known location
- **AND** if not found, reports: "rclone not found at C:\Users\Elizabeth\Desktop\rclone_exe\rclone.exe"
- **AND** provides setup instructions for Box remote configuration

#### Scenario: Handle upload interruption gracefully
- **GIVEN** network issues or user cancellation may interrupt upload
- **WHEN** upload is interrupted
- **THEN** system reports partial progress (files transferred so far)
- **AND** informs user they can re-run command to resume (--update flag skips existing files)
- **AND** does not leave corrupted files on destination

#### Scenario: Verify upload completion
- **GIVEN** rclone upload completes without errors
- **WHEN** upload finishes
- **THEN** system reports: "Upload complete: X files, Y GB transferred"
- **AND** optionally runs `rclone check` to verify file integrity
- **AND** provides Box web link to the uploaded folder

#### Scenario: Support custom destination folder
- **GIVEN** user wants to upload to a different Box location
- **WHEN** user invokes `/upload-to-box 20251208_... --dest "Phenotyping_team_GH/custom-folder"`
- **THEN** system uses the custom destination instead of default `sleap-roots-pipeline-results`
- **AND** validates destination format is valid Box path

#### Scenario: Show transfer statistics during upload
- **GIVEN** large datasets may take significant time to upload
- **WHEN** upload is in progress
- **THEN** system displays real-time progress via rclone's `-P` flag
- **AND** shows: current file, transfer speed, ETA, total progress percentage
- **AND** updates progress in terminal without flooding output