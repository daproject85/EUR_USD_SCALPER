timestamp;event;symbol;period;magic;bid;ask;spread;ticket;op;lots;price;sl;tp;slip;result;error;floating_pl;closed_pl_today;vwap;basket_tp;note

# EuroScalper Log Schema (v1.0)

CSV written to `MQL4/Files/EuroScalperLogs/` with file name:
`EuroScalper_<SYMBOL>_<MAGIC>_<YYYYMMDD_HHMMSS>.csv`

Columns (semicolon-separated):

1. timestamp — broker time `YYYY.MM.DD HH:MM:SS`
2. event — one of:
   - ORDER_SEND_ATTEMPT / ORDER_SEND_RESULT
   - ORDER_CLOSE_ATTEMPT / ORDER_CLOSE_RESULT
   - ORDER_MODIFY_ATTEMPT / ORDER_MODIFY_RESULT
   - DAILY_TARGET_HIT
   - HIDDEN_TP_HIT
   - EQUITY_STOP_HIT
   - BASKET_TP_ASSIGN
3. symbol
4. period — numeric MT4 period (e.g., 1=M1, 5=M5, 60=H1, 1440=D1)
5. magic — EA’s magic for this symbol
6. bid — snapshot at log time
7. ask — snapshot
8. spread — snapshot in points (from `MarketInfo`)
9. ticket — affected order ticket (0 when not applicable)
10. op — order type (as returned by `OrderType()` or `cmd` for send)
11. lots — lots involved
12. price — price being sent/closed/modified
13. sl — stop loss in price
14. tp — take profit in price
15. slip — slippage used (send/close only)
16. result — 1=success, 0=failure `(for *_RESULT rows)`
17. error — `GetLastError()` output `(for *_RESULT rows)`
18. floating_pl — current floating P/L for this magic (money)
19. closed_pl_today — closed P/L for this magic today (money)
20. vwap — (set in **BASKET_TP_ASSIGN** event; empty otherwise)
21. basket_tp — (set in **BASKET_TP_ASSIGN** event; empty otherwise)
22. note — free-form message: comments, reasons, tags

Notes:
- All order operations are captured via wrappers.
- Key risk/target triggers are logged as events.
- TP assignment is logged once per cycle before TPs are pushed to orders.
