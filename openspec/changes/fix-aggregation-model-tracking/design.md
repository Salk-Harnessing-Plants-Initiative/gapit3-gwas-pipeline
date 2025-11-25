# Design: Fix GAPIT Results Aggregation to Track Model Information

## Current Behavior

### File Structure (Per Trait Directory)
```
trait_002_20251110_222205/
├── GAPIT.Association.GWAS_Results.BLINK.trait_name.csv        (1,378,380 rows - ALL SNPs)
├── GAPIT.Association.GWAS_Results.FarmCPU.trait_name.csv      (1,378,380 rows - ALL SNPs)
├── GAPIT.Association.Filter_GWAS_results.csv                  (2 rows - significant SNPs only)
│   - Contains column: traits = "BLINK.TraitName" or "FarmCPU.TraitName"
└── metadata.json
```

### Current Aggregation Flow
```
collect_results.R runs:
1. Scan for trait_*/ directories
2. For each directory:
   - Find files matching "GAPIT.*GWAS_Results.*csv$"
   - Read each file (1.4M rows × 2 models)
   - Filter for P.value < 5e-8
   - Add trait name from metadata
   - **LOSE model information** (not reliably in filename)
3. Output: significant_snps.csv (missing model column)
```

**Performance**: 186 traits × 2 models × 1.4M rows = 521M rows read, 5-10 minutes

## Proposed Behavior

### Proposed Aggregation Flow
```
collect_results.R runs:
1. Scan for trait_*/ directories
2. For each directory:
   - Read GAPIT.Association.Filter_GWAS_results.csv (~5 rows)
   - Parse traits column: "BLINK.trait_name" → model="BLINK", trait="trait_name"
   - Add rows with model column
3. Sort by P.value
4. Output: all_traits_significant_snps.csv (includes model column)
```

**Performance**: 186 traits × ~5 rows = ~1,000 rows read, <30 seconds

## Key Design Decisions

### Decision 1: Read Filter File Instead of GWAS_Results

**Rationale**:
- Filter file already contains significant SNPs (GAPIT pre-filtered)
- Contains model information in `traits` column
- 500× fewer rows to read
- Uses GAPIT's canonical filtered output

**Fallback**: If Filter file missing, fall back to current approach with warning

### Decision 2: Parse Model from `traits` Column

**Format**: `<MODEL>.<TraitName>`

**Parsing Logic**:
```r
# Extract model (everything before first period)
model <- sub("\\..*", "", traits)  # "BLINK.day_1.2" → "BLINK"

# Extract trait (everything after first period)
trait <- sub("^[^.]+\\.", "", traits)  # "BLINK.day_1.2" → "day_1.2"
```

**Handles trait names with periods**: `"BLINK.mean_GR_rootLength_day_1.2(NYC)"` correctly splits to model="BLINK", trait="mean_GR_rootLength_day_1.2(NYC)"

### Decision 3: Add Model Column (Not Separate Files)

**Output Format**:
```csv
SNP,Chr,Pos,P.value,MAF,nobs,effect,H&B.P.Value,trait,model
SNP_123,1,12345,1.2e-9,0.15,500,0.05,2.3e-8,root_length,BLINK
SNP_123,1,12345,2.3e-9,0.15,500,0.06,3.1e-8,root_length,FarmCPU
```

**Rationale**:
- Single file easier to analyze
- SNPs found by both models appear as separate rows (preserves different P.values/effects)
- Easy to filter: `filter(model == "BLINK")`
- Easy to find overlaps: `group_by(SNP, Chr, Pos) %>% filter(n_distinct(model) > 1)`

## Implementation

### Modified Functions

**New function**: `read_filter_file(trait_dir, threshold)`
- Reads Filter file if exists
- Parses model and trait from `traits` column
- Falls back to GWAS_Results if Filter missing
- Returns data.frame with model column

**Modified section**: Lines 131-182 in collect_results.R
- Replace GWAS_Results loop with Filter file reading
- Add model column to output
- Sort by P.value

### Enhanced Summary Statistics

**Add to summary_stats.json**:
```json
{
  "snps_by_model": {
    "BLINK": 25,
    "FarmCPU": 28,
    "both_models": 11,
    "overlap_snps": ["SNP_123", "SNP_456", ...]
  }
}
```

## Edge Cases

1. **Filter file missing**: Fall back to GWAS_Results, warn user
2. **Trait name with periods**: Handled correctly (split on first period only)
3. **Unexpected model name**: Warn but continue processing
4. **Empty Filter file**: No rows added, continue normally
5. **Corrupted Filter file**: Catch error, fall back to GWAS_Results

## Testing Strategy

### Test Fixtures
- Single model (BLINK only)
- Multiple models (BLINK + FarmCPU)
- Trait name with periods ("day_1.2")
- Missing Filter file (fallback test)
- Empty Filter file (no significant SNPs)

### Validation
- Model parsing accuracy: 100% for standard GAPIT format
- Performance: <30s for 186 traits
- Output format: Correct column order
- Summary stats: Per-model counts accurate

## Breaking Changes

1. **Output CSV format**: New `model` column added (at end)
2. **Output filename**: `significant_snps.csv` → `all_traits_significant_snps.csv`
3. **Summary stats**: New `snps_by_model` field in JSON

**Migration**: Re-run aggregation on existing results. Update downstream scripts if parsing by column position.