# Quick Start

Get the GAPIT3 GWAS pipeline running in 5 minutes.

## Prerequisites

- Cluster access with `kubectl` and `argo` CLI configured
- Data on shared NFS (genotype HapMap + phenotype TSV)
- See [docs/DATA_REQUIREMENTS.md](docs/DATA_REQUIREMENTS.md) for formats

## 1. Clone & Configure

```bash
git clone https://github.com/Salk-Harnessing-Plants-Initiative/gapit3-gwas-pipeline.git
cd gapit3-gwas-pipeline/cluster/argo

# Update paths in workflows (replace YOUR_USERNAME)
sed -i 's|YOUR_USERNAME|your_actual_username|g' workflows/*.yaml workflow-templates/*.yaml
```

## 2. Install Templates (One-Time)

```bash
./scripts/submit_workflow.sh templates
```

## 3. Run Test (3 Traits)

```bash
./scripts/submit_workflow.sh test \
  --data-path /hpi/hpi_dev/users/YOU/data \
  --output-path /hpi/hpi_dev/users/YOU/outputs
```

## 4. Run Full Pipeline

```bash
./scripts/submit_workflow.sh full \
  --data-path /hpi/hpi_dev/users/YOU/data \
  --output-path /hpi/hpi_dev/users/YOU/outputs \
  --max-parallel 50
```

## 5. Monitor

```bash
./scripts/monitor_workflow.sh watch <workflow-name>
```

---

**Configuration:** See [`.env.example`](.env.example) for all runtime parameters.

**Detailed guides:** [docs/ARGO_SETUP.md](docs/ARGO_SETUP.md) | [docs/USAGE.md](docs/USAGE.md) | [docs/INDEX.md](docs/INDEX.md)
