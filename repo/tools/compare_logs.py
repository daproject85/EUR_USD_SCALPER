#!/usr/bin/env python3
"""
compare_logs.py — EuroScalper log comparator

Compares two CSV logs emitted by the logging-instrumented EA.
- Aligns rows by a composite key (default: timestamp,event,ticket,op)
- Compares numeric and string fields with configurable tolerances
- Summarizes mismatches and missing rows
- Exits 0 on PASS (no diffs), 1 on FAIL

Usage example:
  python repo/tools/compare_logs.py \
    --baseline repo/sample_logs/EURUSD_0_2025.07.07_01_01_00.csv \
    --candidate repo/sample_logs/EURUSD_0_2025.07.07_01_30_00_new.csv \
    --schema repo/docs/EuroScalper_Log_Schema.md \
    --float-tol-price 1e-6 \
    --float-tol-money 0.01
"""
import csv, sys, argparse, math
from typing import List, Dict, Tuple, Optional

DEFAULT_ALIGN_KEY = ["timestamp","event","ticket","op"]

# Columns we compare numerically
NUMERIC_PRICE_COLS = {"price","sl","tp","bid","ask","vwap","basket_tp"}
NUMERIC_INT_COLS   = {"period","magic","ticket","op","slip","result","error","spread"}
NUMERIC_MONEY_COLS = {"floating_pl","closed_pl_today"}
NUMERIC_LOTS_COLS  = {"lots"}
ALL_NUMERIC = NUMERIC_PRICE_COLS | NUMERIC_INT_COLS | NUMERIC_MONEY_COLS | NUMERIC_LOTS_COLS

def parse_args():
    ap = argparse.ArgumentParser(description="Compare two EuroScalper CSV logs for parity.")
    ap.add_argument("--baseline", required=True, help="Path to baseline CSV")
    ap.add_argument("--candidate", required=True, help="Path to candidate CSV")
    ap.add_argument("--schema", help="Optional path to schema .md to validate header/order")
    ap.add_argument("--align-key", default=",".join(DEFAULT_ALIGN_KEY),
                    help=f"Comma-separated key for alignment (default: {','.join(DEFAULT_ALIGN_KEY)})")
    ap.add_argument("--float-tol-price", type=float, default=1e-6, help="Tolerance for prices (price/sl/tp/bid/ask/vwap/basket_tp)")
    ap.add_argument("--float-tol-money", type=float, default=0.01, help="Tolerance for money (floating_pl/closed_pl_today)")
    ap.add_argument("--float-tol-lots", type=float, default=1e-8, help="Tolerance for lot sizes")
    ap.add_argument("--max-diffs", type=int, default=50, help="Print at most N diffs")
    ap.add_argument("--ignore-cols", default="", help="Comma-separated list of columns to ignore completely")
    ap.add_argument("--strict-rows", action="store_true", help="Fail if row counts differ (missing/extra rows)")
    return ap.parse_args()

def read_csv(path:str)->Tuple[List[str], List[Dict[str,str]]]:
    with open(path, newline='', encoding="utf-8") as f:
        # autodetect delimiter but prefer ';'
        sample = f.read(2048)
        f.seek(0)
        dialect = csv.Sniffer().sniff(sample, delimiters=";,\t")
        reader = csv.reader(f, dialect)
        header = next(reader)
        rows = []
        for i, row in enumerate(reader, start=2):
            d = {header[j]: row[j] if j<len(row) else "" for j in range(len(header))}
            d["__rownum__"] = i
            rows.append(d)
        return header, rows

def extract_header_from_schema(schema_path:str)->Optional[List[str]]:
    """Find a line in .md that looks like the CSV header (semicolon-separated)."""
    try:
        with open(schema_path, "r", encoding="utf-8") as f:
            text = f.read()
        for line in text.splitlines():
            if ";" in line and "timestamp" in line and "event" in line and "symbol" in line:
                line = line.strip().strip("`")
                cols = [c.strip() for c in line.split(";")]
                if {"timestamp","event","symbol","period"}.issubset(set(cols)):
                    return cols
        return None
    except Exception:
        return None

def to_float(val:str)->Optional[float]:
    if val is None or val == "": return None
    try:
        return float(val)
    except ValueError:
        return None

def to_int(val:str)->Optional[int]:
    if val is None or val == "": return None
    try:
        return int(val)
    except ValueError:
        try:
            return int(float(val))
        except Exception:
            return None

def build_key(row:Dict[str,str], key_cols:List[str])->Tuple:
    return tuple(row.get(k, "") for k in key_cols)

def compare_rows(base:Dict[str,str], cand:Dict[str,str], ignore:set, tol_price:float, tol_money:float, tol_lots:float):
    diffs = []
    for col in base.keys():
        if col.startswith("__") or col in ignore:
            continue
        if col not in cand:
            diffs.append((col, base.get(col,""), "", "missing col in candidate"))
            continue
        b = base.get(col, "")
        c = cand.get(col, "")
        if col in NUMERIC_INT_COLS:
            bi, ci = to_int(b), to_int(c)
            if bi != ci:
                diffs.append((col, str(bi), str(ci), "int mismatch"))
        elif col in NUMERIC_LOTS_COLS:
            bf, cf = to_float(b), to_float(c)
            if bf is None or cf is None or math.isnan(bf) or math.isnan(cf) or abs(bf-cf) > tol_lots:
                diffs.append((col, b, c, f"lots tol={tol_lots}"))
        elif col in NUMERIC_PRICE_COLS:
            bf, cf = to_float(b), to_float(c)
            if bf is None or cf is None or math.isnan(bf) or math.isnan(cf) or abs(bf-cf) > tol_price:
                diffs.append((col, b, c, f"price tol={tol_price}"))
        elif col in NUMERIC_MONEY_COLS:
            bf, cf = to_float(b), to_float(c)
            if bf is None or cf is None or math.isnan(bf) or math.isnan(cf) or abs(bf-cf) > tol_money:
                diffs.append((col, b, c, f"money tol={tol_money}"))
        else:
            if b != c:
                diffs.append((col, b, c, "string mismatch"))
    return diffs

def main():
    args = parse_args()
    align_key = [k.strip() for k in args.align_key.split(",") if k.strip()]
    ignore_cols = set([c.strip() for c in args.ignore_cols.split(",") if c.strip()])

    # Read CSVs
    b_header, b_rows = read_csv(args.baseline)
    c_header, c_rows = read_csv(args.candidate)

    # Optional schema validation
    if args.schema:
        expected = extract_header_from_schema(args.schema)
        if expected:
            if [h.strip() for h in b_header] != expected:
                print("[WARN] Baseline header does not match schema. Baseline:", b_header)
                print("[WARN] Expected (from schema):", expected)
            if [h.strip() for h in c_header] != expected:
                print("[WARN] Candidate header does not match schema. Candidate:", c_header)
                print("[WARN] Expected (from schema):", expected)
        else:
            print("[INFO] Could not extract header from schema; skipping header validation.")

    # Build index by key
    b_index = {}
    for r in b_rows:
        k = build_key(r, align_key)
        b_index.setdefault(k, []).append(r)

    c_index = {}
    for r in c_rows:
        k = build_key(r, align_key)
        c_index.setdefault(k, []).append(r)

    total_pairs = 0
    total_missing_baseline = 0
    total_missing_candidate = 0
    total_mismatch = 0
    shown = 0

    all_keys = set(b_index.keys()) | set(c_index.keys())

    for k in sorted(all_keys):
        b_list = b_index.get(k, [])
        c_list = c_index.get(k, [])
        n = max(len(b_list), len(c_list))
        for i in range(n):
            b = b_list[i] if i < len(b_list) else None
            c = c_list[i] if i < len(c_list) else None
            if b is None:
                total_missing_baseline += 1
                if shown < args.max_diffs:
                    print(f"[MISS] Extra in candidate only key={k} cand_row={c.get('__rownum__','?')}")
                    shown += 1
                continue
            if c is None:
                total_missing_candidate += 1
                if shown < args.max_diffs:
                    print(f"[MISS] Missing in candidate key={k} base_row={b.get('__rownum__','?')}")
                    shown += 1
                continue
            total_pairs += 1
            diffs = compare_rows(b, c, ignore_cols, args.float_tol_price, args.float_tol_money, args.float_tol_lots)
            if diffs:
                total_mismatch += 1
                if shown < args.max_diffs:
                    print(f"[DIFF] key={k} base_row={b.get('__rownum__')} cand_row={c.get('__rownum__')}")
                    for col, bv, cv, why in diffs:
                        print(f"  - {col}: base={bv} cand={cv} ({why})")
                    shown += 1

    print("\n=== SUMMARY ===")
    print(f"Baseline rows: {len(b_rows)} | Candidate rows: {len(c_rows)}")
    print(f"Aligned pairs: {total_pairs}")
    print(f"Missing in candidate: {total_missing_candidate} | Extra in candidate: {total_missing_baseline}")
    print(f"Row pairs with diffs: {total_mismatch}")
    fail = False
    if args.strict_rows and (total_missing_candidate>0 or total_missing_baseline>0):
        fail = True
    if total_mismatch > 0:
        fail = True
    print("RESULT:", "PASS ✅" if not fail else "FAIL ❌")
    sys.exit(0 if not fail else 1)

if __name__ == "__main__":
    main()
