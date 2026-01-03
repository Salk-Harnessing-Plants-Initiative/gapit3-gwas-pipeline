## MODIFIED Requirements

### Requirement: Output CSV must include model column

The aggregated results CSV MUST include a `model` column indicating which GAPIT model identified each significant SNP, and an `analysis_type` column indicating the GAPIT analysis variant.

#### Scenario: Output format with model and analysis_type columns

**Given** aggregation of traits with BLINK and FarmCPU models

**When** the aggregated CSV is written

**Then** the output MUST have columns in this order:
```
SNP,Chr,Pos,P.value,MAF,trait,model,analysis_type,trait_dir
```

**And** the `analysis_type` column MUST contain values parsed from trait name suffixes:
- `NYC` for traits ending in `(NYC)`
- `Kansas` for traits ending in `(Kansas)`
- `standard` for traits without suffix

#### Scenario: SNP found by multiple models appears as multiple rows

**Given** a SNP at chr1:12345 found by BLINK (p=1.2e-9) and FarmCPU (p=2.3e-9)

**When** the aggregated CSV is created

**Then** the output MUST contain two rows:
```csv
SNP_123,1,12345,1.2e-9,0.15,root_length,BLINK,NYC,trait_042_20251209_103045
SNP_123,1,12345,2.3e-9,0.15,root_length,FarmCPU,NYC,trait_042_20251209_103045
```

---

## ADDED Requirements

### Requirement: Aggregation must correct BLINK model column order

The aggregation script MUST detect and correct the column order issue in GAPIT's BLINK model output where the MAF column contains sample counts instead of minor allele frequencies.

#### Scenario: BLINK MAF values are corrected during aggregation

**Given** a Filter file row from BLINK model with MAF value > 1:
```csv
,SNP,Chr,Pos,P.value,MAF,traits
1242494,PERL5.16140651,5,16140651,1.103294e-08,536,BLINK.mean_GR_rootLength_day_1.2(NYC)
```

**When** the aggregation script processes this row

**Then** the script MUST:
- Detect that MAF value (536) exceeds valid range [0, 0.5]
- Log a warning: `"Detected BLINK column order issue for trait X: MAF value 536 > 1, marking as NA"`
- Set MAF to `NA` for this row (since correct value cannot be recovered from Filter file)

#### Scenario: Non-BLINK models retain correct MAF values

**Given** a Filter file row from MLM model with valid MAF:
```csv
985512,PERL4.10928145,4,10928145,1.662549e-08,0.07462687,MLM.mean_GR_rootLength_day_1.2(NYC)
```

**When** the aggregation script processes this row

**Then** the script MUST:
- Verify MAF value (0.0746) is in valid range [0, 0.5]
- Retain the original MAF value unchanged

#### Scenario: Summary statistics include BLINK MAF correction count

**Given** aggregation with 100 BLINK rows having invalid MAF and 50 MLM rows with valid MAF

**When** summary statistics are generated

**Then** `summary_stats.json` MUST include:
```json
{
  "data_quality": {
    "blink_maf_corrections": 100,
    "valid_maf_rows": 50,
    "total_rows": 150
  }
}
```

---

### Requirement: Analysis type must be parsed from trait name suffix

The aggregation script MUST extract the analysis type suffix from trait names and store it in a separate `analysis_type` column, leaving the trait name clean.

#### Scenario: NYC suffix parsed into analysis_type column

**Given** a Filter file with traits column value: `BLINK.mean_GR_rootLength_day_1.2(NYC)`

**When** the script parses the traits column

**Then** the script MUST:
- Extract model: `BLINK`
- Extract trait: `mean_GR_rootLength_day_1.2` (suffix removed)
- Extract analysis_type: `NYC`

#### Scenario: Kansas suffix parsed into analysis_type column

**Given** a Filter file with traits column value: `FarmCPU.shoot_iron_content(Kansas)`

**When** the script parses the traits column

**Then** the script MUST:
- Extract model: `FarmCPU`
- Extract trait: `shoot_iron_content` (suffix removed)
- Extract analysis_type: `Kansas`

#### Scenario: Trait without suffix gets standard analysis_type

**Given** a Filter file with traits column value: `MLM.simple_trait`

**When** the script parses the traits column

**Then** the script MUST:
- Extract model: `MLM`
- Extract trait: `simple_trait`
- Extract analysis_type: `standard`

---

### Requirement: GAPIT output quirks must be documented in spec

The results-aggregation spec MUST include documentation of known GAPIT output format quirks to aid future maintainers and ensure reproducibility.

#### Scenario: Spec includes GAPIT quirks reference section

**Given** the results-aggregation spec file

**When** a developer reads the spec

**Then** the spec MUST include a "GAPIT Output Quirks" section documenting:
- BLINK column order issue (MAF contains sample count)
- NYC/Kansas duplicate outputs (identical data, different file names)
- Filter file column limitations (no nobs, effect, H&B.P.Value)