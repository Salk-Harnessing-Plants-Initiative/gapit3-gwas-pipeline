# Quick Start Guide - Elizabeth's Setup

This guide is customized for your specific environment setup on talmo-lab-02.

## Your Configuration

- **Machine**: talmo-lab-02 (WSL Ubuntu)
- **Namespace**: `runai-talmo-lab`
- **Data Path**: `/hpi/hpi_dev/users/eberrigan/20251107_GAPIT_pipeline_tests/data`
- **Output Path**: `/hpi/hpi_dev/users/eberrigan/20251107_GAPIT_pipeline_tests/outputs`

## Data Verified ✓

Your data structure is correct:

```
/hpi/hpi_dev/users/eberrigan/20251107_GAPIT_pipeline_tests/data/
├── genotype/
│   └── acc_snps_filtered_maf_perl_edited_diploid.hmp.txt (2.2 GB)
├── phenotype/
│   └── iron_traits_edited.txt (894 KB, 187 columns)
└── metadata/
    └── ids_gwas.txt (2.7 KB)
```

## Prerequisites Complete ✓

- [x] kubectl configured (using kubeconfig-runai-talmo-lab.yaml)
- [x] Argo Workflows CLI installed
- [x] Cluster access verified
- [x] Data files validated

## Step 1: Deploy Workflow Templates

```bash
# Navigate to repository
cd ~/gapit3-gwas-pipeline  # Or wherever you cloned it

# Deploy templates to cluster
cd cluster/argo/workflow-templates
kubectl apply -f gapit3-gwas-single-trait.yaml -n runai-talmo-lab
kubectl apply -f gapit3-results-collector.yaml -n runai-talmo-lab

# Verify templates are installed
kubectl get workflowtemplates -n runai-talmo-lab
```

Expected output:
```
NAME                         AGE
gapit3-gwas-single-trait    5s
gapit3-results-collector    5s
```

## Step 2: Run Test Pipeline (3 Traits)

This will run traits at indices 2, 3, and 4 to verify everything works:

```bash
# Navigate to workflows directory
cd ~/gapit3-gwas-pipeline/cluster/argo/workflows

# Submit test workflow
argo submit gapit3-test-pipeline.yaml -n runai-talmo-lab

# Get workflow name from output (e.g., gapit3-test-abc123)
WORKFLOW_NAME=$(argo list -n runai-talmo-lab --running -o name | head -1)

# Watch progress
argo get $WORKFLOW_NAME -n runai-talmo-lab --watch

# View logs (optional)
argo logs $WORKFLOW_NAME -n runai-talmo-lab --follow
```

## Step 3: Monitor Workflow

```bash
# Check workflow status
argo get <workflow-name> -n runai-talmo-lab

# View specific pod logs
argo logs <workflow-name> -n runai-talmo-lab --follow

# List all workflows
argo list -n runai-talmo-lab
```

## Step 4: Verify Results

Once the test workflow completes (~45 minutes), check outputs:

```bash
# Check output directory
ls -la /mnt/hpi_dev/users/eberrigan/20251107_GAPIT_pipeline_tests/outputs/

# Should see directories like:
# trait_002_<trait-name>/
# trait_003_<trait-name>/
# trait_004_<trait-name>/
# traits_manifest.yaml

# Check individual trait results
ls -la /mnt/hpi_dev/users/eberrigan/20251107_GAPIT_pipeline_tests/outputs/trait_002_*/
```

Expected files per trait:
- `GAPIT.*.GWAS.Results.csv` - GWAS results with p-values
- `GAPIT.*.Manhattan.*.pdf` - Manhattan plot
- `GAPIT.*.QQ-Plot.pdf` - QQ plot
- `metadata.json` - Execution metadata

## Step 5: Run Full Pipeline (186 Traits)

Once test succeeds, run all traits:

```bash
cd ~/gapit3-gwas-pipeline/cluster/argo/workflows

# Submit parallel workflow
argo submit gapit3-parallel-pipeline.yaml -n runai-talmo-lab

# Monitor (this will run ~4 hours with 50 parallel jobs)
WORKFLOW_NAME=$(argo list -n runai-talmo-lab --running -o name | head -1)
argo get $WORKFLOW_NAME -n runai-talmo-lab --watch
```

## Troubleshooting

### Check Pod Status

```bash
# List all pods in your namespace
kubectl get pods -n runai-talmo-lab

# Describe a specific pod
kubectl describe pod <pod-name> -n runai-talmo-lab

# Get pod logs
kubectl logs <pod-name> -n runai-talmo-lab
```

### Common Issues

**Issue**: Workflow fails with "ImagePullBackOff"

**Solution**: Verify image is accessible:
```bash
kubectl get pods -n runai-talmo-lab | grep ImagePull
kubectl describe pod <pod-name> -n runai-talmo-lab
```

**Issue**: Workflow fails with "directory not found"

**Solution**: Verify cluster nodes can access NFS paths:
```bash
# Check if paths exist
ls -la /mnt/hpi_dev/users/eberrigan/20251107_GAPIT_pipeline_tests/data/
ls -la /mnt/hpi_dev/users/eberrigan/20251107_GAPIT_pipeline_tests/outputs/
```

**Issue**: OOMKilled (out of memory)

**Solution**: Increase memory in workflow YAML:
```yaml
- name: memory-gb
  value: "36"  # Increase from 32 to 36 GB
```

### View Argo UI

```bash
# Port forward Argo UI to localhost
kubectl port-forward -n argo svc/argo-server 2746:2746

# Then open browser to: http://localhost:2746
```

## Using the Automated Script

Alternatively, use the automated deployment script:

```bash
cd ~/gapit3-gwas-pipeline/scripts

# Run full deployment (interactive)
./deploy-test.sh

# Or automated mode:
./deploy-test.sh --full    # Deploy templates + run test
./deploy-test.sh --deploy  # Only deploy templates
./deploy-test.sh --test    # Only submit test workflow
```

## Next Steps

After successful test run:

1. Review test results in output directories
2. Verify Manhattan and QQ plots look correct
3. Run full pipeline for all 186 traits
4. Collect and analyze aggregated results

## Resources

- [Full Deployment Guide](docs/DEPLOYMENT_TESTING.md)
- [Data Requirements](docs/DATA_REQUIREMENTS.md)
- [Usage Guide](docs/USAGE.md)
- [Troubleshooting](docs/DEPLOYMENT_TESTING.md#troubleshooting)