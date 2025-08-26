timestamp;event;symbol;period;magic;bid;ask;spread;ticket;order_type;lots;price;sl;tp;slip;result;error;floating_pl;closed_pl_today;vwap;basket_tp;note

# EuroScalper Log Schema (v1.3, filename range)

This document defines the exact CSV output produced by EuroScalper’s logger. It supersedes v1.0 by renaming column **10** from `op` (numeric) to **`order_type`** (human‑readable).

## File format
- **Encoding:** UTF‑8 with header row
- **Delimiter:** semicolon `;`
- **Decimal point:** `.`
- **Header:** the first line in this file (beginning with `timestamp;…`) is the canonical header
- **Row semantics:** each row is a single event at a specific time

## Column definitions (22 columns; semicolon‑separated)


1. **timestamp** — broker time `YYYY.MM.DD HH:MM:SS`
2. **event** — event name (see *Event types*)
3. **symbol** — symbol (e.g., `EURUSD`)
4. **period** — chart period in minutes (e.g., `1`=M1, `5`=M5, `60`=H1, `1440`=D1)
5. **magic** — EA magic number for this symbol
6. **bid** — bid at log time
7. **ask** — ask at log time
8. **spread** — spread in **points** at log time
9. **ticket** — MT4 order ticket id (0 if not applicable)
10. **order_type** — human‑readable order type (see table below)
11. **lots** — lots involved in the event
12. **price** — price used in the action (send/close/modify)
13. **sl** — stop loss price
14. **tp** — take profit price
15. **slip** — slippage used (send/close events)
16. **result** — `1`=success, `0`=failure (only meaningful for `*_RESULT` events; blank otherwise)
17. **error** — `GetLastError()` code (only in `*_RESULT` events; blank otherwise)
18. **floating_pl** — floating P/L for this magic at log time (account currency)
19. **closed_pl_today** — closed P/L for this magic today (account currency)
20. **vwap** — basket volume‑weighted average price (set in `BASKET_TP_ASSIGN`, blank otherwise)
21. **basket_tp** — current basket take‑profit price (set in `BASKET_TP_ASSIGN`, blank otherwise)
22. **note** — free‑form details (e.g., first entry marker, computed values, reason codes)

## Order type codes (column 10: `order_type`)

| Value       | Meaning       |
|------------|----------------|
| BUY        | Market buy     |
| SELL       | Market sell    |
| BUY LIMIT  | Pending buy below market |
| SELL LIMIT | Pending sell above market |
| BUY STOP   | Pending buy above market |
| SELL STOP  | Pending sell below market |
| -1         | Synthetic / not tied to a specific order (e.g., basket events) |

> Internally, MT4 uses `OP_BUY=0`, `OP_SELL=1`, `OP_BUYLIMIT=2`, `OP_SELLLIMIT=3`, `OP_BUYSTOP=4`, `OP_SELLSTOP=5`. v1.1 writes the **human names** above instead of numbers.

## Event types (column 2: `event`)

- **ORDER_SEND_ATTEMPT** — an order is about to be sent. Relevant fields: `order_type`, `lots`, `price`, `sl`, `tp`, `slip`, `note` (comment).
- **ORDER_SEND_RESULT** — result of `OrderSend`. Relevant: `result`, `error`, `ticket`, `price`, `note`.
- **ORDER_CLOSE_ATTEMPT** — an order is about to be closed. Relevant: `ticket`, `order_type`, `lots`, `price`, `slip`.
- **ORDER_CLOSE_RESULT** — result of `OrderClose`. Relevant: `result`, `error`, `ticket`, `note`.
- **ORDER_MODIFY_ATTEMPT** — an order is about to be modified. Relevant: `ticket`, `sl`, `tp`, `price` (new open price for pending) and `note`.
- **ORDER_MODIFY_RESULT** — result of `OrderModify`. Relevant: `result`, `error`, `ticket`, `note`.
- **BASKET_TP_ASSIGN** — basket VWAP & TP recomputed/assigned. Relevant: `vwap`, `basket_tp`, `note` (may include rationale or components). `ticket=0`, `order_type=-1`.
- **DAILY_TARGET_HIT** — daily profit target reached. May include `note` with threshold/values.
- **HIDDEN_TP_HIT** — hidden TP logic triggered; `note` may contain threshold details.
- **EQUITY_STOP_HIT** — equity stop condition met.

> If a given field is not meaningful for an event, it may be blank in that row.

## Example rows

```
2025.08.04 02:00:00;ORDER_SEND_ATTEMPT;EURUSD;5;101111;1.15840;1.15852;12;0;BUY;0.10;1.15842;0.00000;0.00000;2;;;125.40;0.00;;;"EURUSD-Euro Scalper-0"
2025.08.04 02:00:00;ORDER_SEND_RESULT;EURUSD;5;101111;1.15840;1.15852;12;12345678;BUY;0.10;1.15842;0.00000;0.00000;2;1;0;126.15;0.00;;;"EURUSD-Euro Scalper-0"
2025.08.04 02:00:00;BASKET_TP_ASSIGN;EURUSD;5;101111;1.15841;1.15853;12;0;-1;;;0.00000;0.00000;; ; ;126.15;0.00;1.15842;1.16042;"vwap=1.15842"
```

*(Numbers and ticket are illustrative.)*

## File naming convention (recommended)

`<SYMBOL>_<FROM_YYYY.MM.DD>_<FROM_HH>_<FROM_MM>_<FROM_SS>_TO_<TO_YYYY.MM.DD>_<TO_HH>_<TO_MM>_<TO_SS>_<RUN_TAG>.csv`
Examples:
- `EURUSD_2025.08.26_01_12_05_TO_2025.08.26_23_59_59_BASELINE.csv`
- `EURUSD_2025.08.26_01_12_05_TO_2025.08.26_23_59_59_CLEAN.csv`

The **FROM** and **TO** segments record the backtest's first and last tick times rather than the machine's current time.

- During backtests, MT4 writes to `tester/files/EuroScalperLogs/` (or `MQL4/Files/EuroScalperLogs/` for live).
- For version control, copy the resulting CSVs into your repo under `repo/sample_logs/` (or another tracked folder).

## Comparator alignment & tolerance (for `compare_logs.py`)

- **Default alignment key (v1.0):** `timestamp,event,ticket,op`  
- **Recommended for v1.1:** set `--align-key timestamp,event,ticket,order_type`
- Suggested ignores while iterating on parity: `--ignore-cols magic,note`  
- Float tolerances used by the tool (defaults): price `1e-4`, money `1e-2`, lots `1e-6`.

## Versioning & compatibility

- **v1.0** (historical): column 10 = `op` (numbers 0–5 or `-1`).  
- **v1.1** (this spec): column 10 = `order_type` (readable).  
- When comparing v1.0 vs v1.1 logs, either:
  - use a comparator that maps numbers ↔ names, **or**
  - export both runs in the same version before comparing, **or**
  - align by `timestamp,event,ticket` and ignore `order_type/op` temporarily.

## Notes
- Monetary columns (`floating_pl`, `closed_pl_today`) are in account currency.  
- Prices are raw broker prices (not normalized to digits in the CSV).  
- Empty cells indicate “not applicable” for that event.

## Changelog
- **v1.3** — Added end timestamp (`_TO_`) to filename.
- **v1.2** — Updated filename convention: removed MAGIC from filename; added RUN_TAG (BASELINE/CLEAN).
- **v1.1** — `op` → `order_type`; added readable order types and expanded event notes.
- **v1.0** — initial schema with numeric `op`.