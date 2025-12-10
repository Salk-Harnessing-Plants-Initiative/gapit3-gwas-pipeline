# Demo Guide

Live demonstration of the GAPIT3 GWAS pipeline. **Time: 20-30 minutes**

## Pre-Demo Checklist

- [ ] WSL terminal open
- [ ] Cluster connectivity verified: `runai workspace list`
- [ ] Test data available on NFS

## Demo Flow

### 1. Show Configuration (2 min)

```bash
cd /mnt/c/repos/gapit3-gwas-pipeline
cat .env.example | head -60
```

Key points: MODELS, PCA_COMPONENTS, SNP_THRESHOLD are all configurable at runtime.

### 2. Submit Test Jobs (5 min)

```bash
cd cluster/argo
./scripts/submit_workflow.sh test \
  --data-path /hpi/hpi_dev/users/YOU/data \
  --output-path /hpi/hpi_dev/users/YOU/outputs
```

### 3. Monitor Progress (5 min)

```bash
./scripts/monitor_workflow.sh watch <workflow-name>
```

Show: DAG execution, parallel jobs, live status updates.

### 4. Show Architecture (5 min)

Open in VSCode:
- `cluster/argo/workflows/gapit3-test-pipeline.yaml` - DAG structure
- `cluster/argo/workflow-templates/gapit3-single-trait-template.yaml` - Job template

Key points: Validation → Extraction → Parallel GWAS → Aggregation

### 5. Check Results (3 min)

```bash
ls outputs/
ls outputs/aggregated_results/
```

Show: Manhattan plots, QQ plots, significant SNPs CSV.

### 6. Alternative: RunAI Direct (Optional, 5 min)

```bash
cd scripts
./submit-all-traits-runai.sh
./monitor-runai-jobs.sh --watch
```

Key point: Same Docker image, different orchestration.

## Cleanup

```bash
# Argo
argo delete <workflow-name> -n runai-talmo-lab

# RunAI
./scripts/cleanup-runai.sh --workspaces-only
```

## Key Talking Points

1. **Fully containerized** - Same results locally or on cluster
2. **Runtime configurable** - No rebuild needed to change parameters
3. **Parallel execution** - 184 traits in ~4 hours vs ~46 hours serial
4. **Two execution paths** - Argo (orchestrated) or RunAI (direct)

---

**Detailed commands:** See [DEMO_COMMANDS.md](DEMO_COMMANDS.md) for copy-paste reference.