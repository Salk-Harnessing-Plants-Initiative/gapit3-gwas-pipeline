# Submit RunAI Test Job

Submit a single-trait GWAS test job to RunAI using the correct CLI v2 syntax.

## Usage

```
/submit-runai-test
```

Provide the following when prompted:
- Data path (Windows path, e.g., `Z:\users\eberrigan\...`)
- Trait index (default: 2)
- SNP_FDR value (optional, e.g., 0.05)

## RunAI CLI v2 Key Points

### Workspace vs Training

| Type | Behavior | Use Case |
|------|----------|----------|
| `runai workspace submit` | Does NOT auto-terminate | Interactive/batch jobs |
| `runai training submit` | Auto-terminates on completion | Training runs |

This pipeline uses **workspace** because jobs need manual cleanup after completion.

### Correct Syntax

```bash
# IMPORTANT: Use MSYS_NO_PATHCONV=1 in Git Bash to prevent path mangling
MSYS_NO_PATHCONV=1 runai workspace submit <job-name> \
    --project talmo-lab \
    --image ghcr.io/salk-harnessing-plants-initiative/gapit3-gwas-pipeline:feat-add-ci-testing-workflows-test \
    --cpu-core-request 12 \
    --cpu-memory-request 32G \
    --host-path path=/hpi/hpi_dev/users/<user>/<dataset>/data,mount=/data,mount-propagation=HostToContainer \
    --host-path path=/hpi/hpi_dev/users/<user>/<dataset>/outputs,mount=/outputs,mount-propagation=HostToContainer,readwrite \
    --environment TRAIT_INDEX=2 \
    --environment DATA_PATH=/data \
    --environment OUTPUT_PATH=/outputs \
    --environment GENOTYPE_FILE=/data/genotype/<file>.hmp.txt \
    --environment PHENOTYPE_FILE=/data/phenotype/<file>.txt \
    --environment ACCESSION_IDS_FILE=/data/metadata/ids_gwas.txt \
    --environment MODELS=BLINK,FarmCPU \
    --environment PCA_COMPONENTS=3 \
    --environment SNP_THRESHOLD=0.00000001 \
    --environment SNP_FDR=0.05 \
    --environment MAF_FILTER=0.05 \
    --environment OPENBLAS_NUM_THREADS=12 \
    --environment OMP_NUM_THREADS=12 \
    --command -- /scripts/entrypoint.sh run-single-trait
```

### Common Mistakes to Avoid

| Wrong | Correct | Why |
|-------|---------|-----|
| `--pvc` | `--host-path` | No PVCs configured; use host-path mounts |
| `--config /config/config.yaml` | Environment variables | config.yaml removed; use env vars |
| `runai training submit` | `runai workspace submit` | Repo uses workspace pattern |
| `/hpi/...` in Git Bash | `MSYS_NO_PATHCONV=1` prefix | Prevents path mangling |

## Path Mapping

| Windows | Cluster |
|---------|---------|
| `Z:\users\eberrigan\...` | `/hpi/hpi_dev/users/eberrigan/...` |

## Example: Iron Traits Dataset with FDR

```bash
MSYS_NO_PATHCONV=1 runai workspace submit gapit3-fdr-test-trait2 \
    --project talmo-lab \
    --image ghcr.io/salk-harnessing-plants-initiative/gapit3-gwas-pipeline:feat-add-ci-testing-workflows-test \
    --cpu-core-request 12 \
    --cpu-memory-request 32G \
    --host-path path=/hpi/hpi_dev/users/eberrigan/20251208_Elohim_Bello_iron_deficiency_GAPIT_GWAS/data,mount=/data,mount-propagation=HostToContainer \
    --host-path path=/hpi/hpi_dev/users/eberrigan/20251208_Elohim_Bello_iron_deficiency_GAPIT_GWAS/outputs,mount=/outputs,mount-propagation=HostToContainer,readwrite \
    --environment TRAIT_INDEX=2 \
    --environment DATA_PATH=/data \
    --environment OUTPUT_PATH=/outputs \
    --environment GENOTYPE_FILE=/data/genotype/acc_snps_filtered_maf_perl_edited_diploid.hmp.txt \
    --environment PHENOTYPE_FILE=/data/phenotype/iron_traits_edited.txt \
    --environment ACCESSION_IDS_FILE=/data/metadata/ids_gwas.txt \
    --environment MODELS=BLINK,FarmCPU \
    --environment PCA_COMPONENTS=3 \
    --environment SNP_THRESHOLD=0.00000001 \
    --environment SNP_FDR=0.05 \
    --environment MAF_FILTER=0.05 \
    --environment OPENBLAS_NUM_THREADS=12 \
    --environment OMP_NUM_THREADS=12 \
    --command -- /scripts/entrypoint.sh run-single-trait
```

## Monitoring

After submission:

```bash
# Check job status
runai workspace describe gapit3-fdr-test-trait2 -p talmo-lab

# Follow logs
runai workspace logs gapit3-fdr-test-trait2 -p talmo-lab --follow

# List all jobs
runai workspace list -p talmo-lab | grep gapit3
```

## Cleanup

```bash
# Delete completed job
runai workspace delete gapit3-fdr-test-trait2 -p talmo-lab
```

## Related Commands

- `/validate-data` - Validate data before submission
- `/monitor-jobs` - Monitor running jobs
- `/cleanup-jobs` - Clean up completed/failed jobs
- `/submit-test-workflow` - Argo alternative (if preferred)

## Reference

- [scripts/submit-all-traits-runai.sh](../../scripts/submit-all-traits-runai.sh) - Production submission script
- [docs/MANUAL_RUNAI_EXECUTION.md](../../docs/MANUAL_RUNAI_EXECUTION.md) - Full RunAI guide
- [RunAI Workspace Docs](https://docs.run.ai/v2.19/Researcher/cli-reference/new-cli/runai_workspace_submit/)