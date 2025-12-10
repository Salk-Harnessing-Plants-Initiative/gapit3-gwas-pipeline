## 1. Implementation

- [x] 1.1 Create `cluster/argo/workflows/gapit3-aggregation-standalone.yaml` workflow file

## 2. Documentation - Argo README

- [ ] 2.1 Update `cluster/argo/README.md` directory structure to include `gapit3-aggregation-standalone.yaml`
- [ ] 2.2 Add new section "### gapit3-aggregation-standalone.yaml" under workflows
- [ ] 2.3 Add "When to Use Each Aggregation Method" comparison table

## 3. Documentation - Claude Commands

- [ ] 3.1 Update `.claude/commands/aggregate-results.md` to include Argo standalone workflow option
- [ ] 3.2 Update `.claude/commands/manage-workflow.md` to document the exact standalone aggregation command (currently only mentions "Offer standalone aggregation" without the command)

## 4. Validation

- [ ] 4.1 Run `openspec validate add-standalone-aggregation-workflow --strict`