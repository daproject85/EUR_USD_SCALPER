timestamp;event;symbol;period;magic;bid;ask;spread;ticket;order_type;lots;price;sl;tp;slip;result;error;floating_pl;closed_pl_today;vwap;basket_tp;note

# EuroScalper Log Schema (v1.1)

**Change:** Column 10 renamed from **op** to **order_type** and represented as human‑readable names.

Columns (semicolon-separated):

1. **timestamp** — broker time `YYYY.MM.DD HH:MM:SS`
2. **event** — one of:
   - ORDER_SEND_ATTEMPT / ORDER_SEND_RESULT
   - ORDER_CLOSE_ATTEMPT / ORDER_CLOSE_RESULT
   - ORDER_MODIFY_ATTEMPT / ORDER_MODIFY_RESULT
   - DAILY_TARGET_HIT
   - HIDDEN_TP_HIT
   - EQUITY_STOP_HIT
   - BASKET_TP_ASSIGN
3. **symbol**
4. **period** — numeric MT4 period (e.g., 1=M1, 5=M5, 60=H1, 1440=D1)
5. **magic** — EA magic number for this symbol
6. **bid** — snapshot at log time
7. **ask** — snapshot at log time
8. **spread** — snapshot in points
9. **ticket** — affected order ticket (0 when not applicable)
10. **order_type** — human‑readable order type
    - BUY (0 / OP_BUY)
    - SELL (1 / OP_SELL)
    - BUY LIMIT (2 / OP_BUYLIMIT)
    - SELL LIMIT (3 / OP_SELLLIMIT)
    - BUY STOP (4 / OP_BUYSTOP)
    - SELL STOP (5 / OP_SELLSTOP)
    - −1 *(synthetic / not tied to an order)*
11. **lots** — lots involved
12. **price** — price being sent/closed/modified
13. **sl** — stop loss (price)
14. **tp** — take profit (price)
15. **slip** — slippage used (send/close only)
16. **result** — 1=success, 0=failure (`*_RESULT` rows)
17. **error** — `GetLastError()` code (`*_RESULT` rows)
18. **floating_pl** — current floating P/L for this magic
19. **closed_pl_today** — closed P/L for this magic (today)
20. **vwap** — set in **BASKET_TP_ASSIGN** (empty otherwise)
21. **basket_tp** — set in **BASKET_TP_ASSIGN** (empty otherwise)
22. **note** — free-form message / comment

### Compatibility
- **v1.0** used column 10 as `op` (numeric 0–5 or −1). New runs using v1.1 will have **order_type** as a string (e.g., "BUY").
- When comparing old (v1.0) vs new (v1.1) logs, treat `op` (numeric) and `order_type` (string) equivalently via a mapping.
