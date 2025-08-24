# Rewrite Plan — EuroScalper_CLEAN.mq4

## Goal
Refactor the decompiled EuroScalper EA into a clean, maintainable MQL4 Expert Advisor **with identical runtime behavior** as the baseline (`EuroScalper_LOG_v1_10.mq4`).

Parity is validated by:
- Using the same extern input names and defaults (so existing .set files work).
- Emitting **identical CSV logs** (see `EuroScalper_Log_Schema.md`).
- Running the comparator tool (`repo/tools/compare_logs.py`) on golden backtests.

## Rewrite Branch
- Branch name: `rewrite/clean-euroscalper`
- Clean EA file: `MQL4/Experts/EuroScalper_CLEAN.mq4`

## Step Plan
1. **Scaffold (done)**  
   - Add externs + includes + logger lifecycle hooks.  
   - File: `EuroScalper_CLEAN.mq4` (no trading logic yet).  

2. **Session gating + open-range filter**  
   - Implement trading hours, Thursday/Friday cut-offs, daily open-range check.  
   - Verify comparator passes on a no-trade run.

3. **First entry logic**  
   - Port candle-delta entry decision, lot sizing, first order placement.  
   - Verify comparator matches baseline logs on a small window.  

4. **Grid adds**  
   - Port Step/MaxTrades/Averaging logic.  
   - Verify multiple-add sequence matches baseline.  

5. **Basket TP maintenance**  
   - Implement VWAP calculation and basket TP assignment + modify events.  
   - Verify VWAP & basket TP match baseline.  

6. **Targets and stops**  
   - Hidden TP, Daily Target, Equity Stop.  
   - Emit same events as baseline before closing.  

7. **Golden run parity check**  
   - Run comparator on all golden backtests (see `repo/runs/manifest.csv`).  
   - All must PASS.  

8. **Merge**  
   - When parity achieved, merge branch into `main`.  
   - Tag release `v1.10-clean`.

## Tools
- Comparator: `repo/tools/compare_logs.py`
- Schema: `repo/docs/EuroScalper_Log_Schema.md`
- Baseline logs: `repo/sample_logs/`
- Presets: `repo/presets/backtests/`
- Manifest: `repo/runs/manifest.csv`

## Acceptance Criteria
- Same externs and defaults.  
- Identical CSV logs (row-for-row parity).  
- Comparator reports PASS ✅ on golden runs.  
