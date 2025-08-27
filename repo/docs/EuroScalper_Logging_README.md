# EuroScalper Logging Add‑On (decompiled v1.10)

This package instruments your existing EA **without changing trading logic**. It logs order operations and key risk/TP events for one‑to‑one comparison with future rewrites.

## Files
- `EuroScalper_LOG_v1_10.mq4` — your EA with logging hooks only
- `ES_Logger.mqh` — logger + wrappers for OrderSend/Close/Modify
- `EuroScalper_Logging_Config.mqh` — externs to control logging
- `EuroScalper_Log_Schema.md` — exact CSV column spec
- `EuroScalper_Internal_Map.md` — variable → concept mapping
- `Merge_EuroScalper_Logs.py` — optional CSV merge tool

## Install (MT4)
1. **Close MT4.**
2. Copy files to:
   - `EuroScalper_LOG_v1_10.mq4` → `MQL4/Experts/`
   - `ES_Logger.mqh`, `EuroScalper_Logging_Config.mqh` → `MQL4/Include/`
   - `EuroScalper_Log_Schema.md`, `EuroScalper_Internal_Map.md`, `Merge_EuroScalper_Logs.py` → anywhere (docs/tools), optional.
3. Launch MT4 → press **F4** to open MetaEditor.
4. In `Experts`, open **EuroScalper_LOG_v1_10.mq4** and **Compile**.
5. In MT4, attach **EuroScalper_LOG_v1_10** to your chart(s).

## Configure
- Inputs (externs) include only **logging controls**:
  - `ES_Log_Enable` (bool, default **true**)
  - `ES_Log_Level` (int, default **3**; reserved for future verbosity)
  - `ES_Log_FlushEvery` (int, default **1**; flush on every write)
- All **trading inputs & behavior are unchanged**.

## Where logs go
- `MQL4/Files/EuroScalperLogs/<SYMBOL>_<FROM_YYYY.MM.DD_HH_MM_SS>_TO_<TO_YYYY.MM.DD_HH_MM_SS>_<RUN_TAG>.csv`
- Semicolon‑separated, headers included. See **EuroScalper_Log_Schema.md**.
  The **FROM**/**TO** parts capture the first and last tick times of the backtest, not the wall‑clock time.
  Examples:
  - `EURUSD_2025.08.04_00_00_00_TO_2025.08.04_23_59_59_BASELINE.csv`
  - `EURUSD_2025.08.04_00_00_00_TO_2025.08.04_23_59_59_CLEAN.csv`

## What’s captured
- Every **OrderSend**, **OrderClose**, **OrderModify** (attempt/result, error).
- **Daily target**, **Hidden TP**, and **Equity Stop** triggers.
- **Basket TP assignment** (VWAP & basket TP snapshot before pushing).

## Compare with future rewrite
When the clean rewrite is ready, we’ll emit **identical CSV** so you can compare:
- Sequence of events
- Lot sizes, prices, SL/TP
- Error codes, success flags
- Risk/TP trigger timings

## Notes
- If you run multiple charts/symbols, each gets its own file.
- Logging is lightweight; disable with `ES_Log_Enable=false` for production.
