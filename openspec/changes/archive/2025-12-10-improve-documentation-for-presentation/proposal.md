# OpenSpec Change Proposal: Improve Documentation for Presentation

## Why

The repository documentation needs improvement before presenting to a colleague. Key issues:

### Critical Gaps

1. **Broken Documentation Links** - README.md references non-existent files:
   - `docs/USAGE.md` (line 266) - Does not exist
   - `docs/DATA_DICTIONARY.md` (line 267) - Does not exist

2. **Outdated Status Information** - RBAC was resolved 2025-11-18 but docs still show "pending":
   - README.md shows "RBAC Permissions Pending" warning
   - QUICKSTART.md has workaround as primary method

3. **Hardcoded Dataset Values** - Documentation references specific trait counts (184, 186, 187) as if fixed:
   - Trait counts are dataset-dependent, not pipeline constants
   - Should use these as examples, not specifications

4. **Configuration Discoverability** - `.env.example` has excellent documentation but:
   - Not prominently linked from README or QUICKSTART
   - No dedicated parameter reference page
   - Users may miss the comprehensive configuration options

5. **QUICKSTART Too Verbose** - Current QUICKSTART.md is 306 lines:
   - Too long for a "quick" start
   - Mixes setup, usage, troubleshooting, and workarounds
   - Should be succinct: get running in < 50 lines

## What Changes

### Phase 1: Fix Critical Issues

1. **Create `docs/USAGE.md`** - Parameter reference pointing to `.env.example`:
   - Quick reference table of key parameters
   - Link to `.env.example` as authoritative source
   - Common configuration recipes
   - Keep it short - don't duplicate `.env.example`

2. **Create `docs/DATA_REQUIREMENTS.md`** (rename from DATA_DICTIONARY):
   - Input file format requirements (HapMap, phenotype format)
   - Output file descriptions
   - Use example values, not hardcoded counts
   - "Your phenotype file determines trait count"

3. **Update RBAC status** - Mark as resolved:
   - README.md: Remove "pending" warning
   - QUICKSTART.md: Remove workaround prominence

4. **Make documentation dataset-agnostic**:
   - Replace hardcoded "184 traits" with "N traits (e.g., 184 for iron dataset)"
   - Trait count comes from phenotype file, not documentation

### Phase 2: Simplify QUICKSTART

5. **Rewrite QUICKSTART.md** - Target: <50 lines of essential content:
   - Prerequisites (3-4 bullets)
   - Clone & configure (5 lines)
   - Run test (3 lines)
   - Run full pipeline (3 lines)
   - Link to detailed docs for everything else
   - Remove troubleshooting, workarounds, detailed explanations

6. **Promote `.env.example`** - Make configuration discoverable:
   - Add "Configuration" section to README linking to `.env.example`
   - Note in QUICKSTART: "See `.env.example` for all options"

### Phase 3: Organization (Optional)

7. **Create `docs/INDEX.md`** - Simple navigation:
   - One-line descriptions of each doc
   - Reading order by user type

8. **Consolidate demo guides** - One `DEMO_GUIDE.md`:
   - Merge QUICK_DEMO.md and DEMO_COMMANDS.md

## Impact

### Files Changed

| File | Change |
|------|--------|
| `docs/USAGE.md` | **CREATE** - Short parameter reference |
| `docs/DATA_REQUIREMENTS.md` | **CREATE** - Input/output formats |
| `README.md` | **MODIFY** - Fix links, update status, add config section |
| `QUICKSTART.md` | **MODIFY** - Drastically simplify (<50 lines) |
| `docs/INDEX.md` | **CREATE** - Navigation hub |
| `docs/DEMO_GUIDE.md` | **CREATE** - Consolidated demo |

### No Code Changes

Documentation only - no scripts, workflows, or Docker changes.

## Design Principles

1. **Don't duplicate** - `.env.example` is the source of truth for parameters
2. **Dataset-agnostic** - Trait counts are examples, not specifications
3. **Succinct over comprehensive** - Link to details, don't inline them
4. **Discoverable configuration** - Make `.env.example` easy to find

## Success Criteria

1. All README links resolve
2. QUICKSTART < 50 lines of essential content
3. Configuration options findable in < 30 seconds
4. No hardcoded trait counts (only examples)
5. RBAC status accurate across all docs
