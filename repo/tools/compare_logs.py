#!/usr/bin/env python3
import argparse, csv, io, sys, os


def _stringify_key(key_tuple):
    return tuple("" if v is None else str(v) for v in key_tuple)


def _compute_widths(key_cols, keys_list):
    # widths for each key column (by internal name), with extra padding for readability
    widths = {name: max(len(name), 2) for name in key_cols}
    for key in keys_list:
        for i, name in enumerate(key_cols):
            val = "" if i >= len(key) else (key[i] if key[i] is not None else "")
            widths[name] = max(widths[name], len(str(val)))
    # add a bit of breathing room between columns
    for name in widths:
        widths[name] += 3
    return widths

def _fmt_key_row(prefix, key_cols, widths, key):
    parts = [prefix]
    for i, name in enumerate(key_cols):
        val = "" if i >= len(key) else (key[i] if key[i] is not None else "")
        sval = str(val)
        parts.append(sval.ljust(widths[name]))
    return "  ".join(parts)


def _print_rowcount_table(key_cols, rowcount_records, file=sys.stdout):
    if not rowcount_records:
        return
    keys_only = [rec["key"] for rec in rowcount_records]
    widths = _compute_widths(key_cols, keys_only)

    # dynamic widths for the count columns
    baseline_w = max(len("baseline"), max((len(str(rec["baseline"])) for rec in rowcount_records), default=1)) + 2
    candidate_w = max(len("candidate"), max((len(str(rec["candidate"])) for rec in rowcount_records), default=1)) + 2

    # header: rename 'op' -> 'order_type' only for display
    hdr_cols = []
    for name in key_cols:
        disp = "order_type" if name == "op" else name
        hdr_cols.append(disp.ljust(widths[name]))
    hdr = ["[ROWCOUNT]"] + hdr_cols + ["baseline".ljust(baseline_w), "candidate".ljust(candidate_w)]
    print("  ".join(hdr), file=file)

    # rows
    for rec in rowcount_records:
        key = rec["key"]
        line = _fmt_key_row("[   ]", key_cols, widths, key)
        line += "  " + str(rec["baseline"]).rjust(baseline_w) + "  " + str(rec["candidate"]).rjust(candidate_w)
        print(line, file=file)

def _compute_diff_widths(diff_records):
    # compute widths for the diff table (column name, baseline, candidate)
    col_w = max(6, max((len(col) for rec in diff_records for col in rec["diffs"].keys()), default=0))
    base_w = max(8, max((len(str(v[0])) for rec in diff_records for v in rec["diffs"].values()), default=0))
    cand_w = max(9, max((len(str(v[1])) for rec in diff_records for v in rec["diffs"].values()), default=0))
    return col_w, base_w, cand_w


def _print_diff_section(key_cols, diff_records, file=sys.stdout):
    if not diff_records:
        return
    # widths for key columns (for the header rows)
    keys_only = [rec["key"] for rec in diff_records]
    key_widths = _compute_widths(key_cols, keys_only)
    col_w, base_w, cand_w = _compute_diff_widths(diff_records)
    for rec in diff_records:
        # show key row (values), same spacing
        print(_fmt_key_row("[DIFF]", key_cols, key_widths, rec["key"]), file=file)
        # sub-table header
        print("       " + "column".ljust(col_w) + "  " + "baseline".ljust(base_w) + "  " + "candidate".ljust(cand_w), file=file)
        # rows
        for col, (b, c) in rec["diffs"].items():
            print("       " + str(col).ljust(col_w) + "  " + str(b).ljust(base_w) + "  " + str(c).ljust(cand_w), file=file)
        print("", file=file)  # blank line between diff groups



NUMERIC_COLS = {"ticket", "baseline", "candidate"}

def _display_name(name):
    return "order_type" if name == "op" else name

def _stringify_key(key_tuple):
    return tuple("" if v is None else str(v) for v in key_tuple)

def _compute_widths(key_cols, keys_list, include_counts=False):
    widths = {name: max(len(_display_name(name)), 2) for name in key_cols}
    for key in keys_list:
        for i, name in enumerate(key_cols):
            val = "" if i >= len(key) else (key[i] if key[i] is not None else "")
            widths[name] = max(widths[name], len(str(val)))
    if include_counts:
        widths["baseline"] = max(len("baseline"), 1)
        widths["candidate"] = max(len("candidate"), 1)
    for k in widths:
        widths[k] += 2
    return widths

def _justify(name, text, widths):
    s = "" if text is None else str(text)
    if name in NUMERIC_COLS:
        return s.rjust(widths[name])
    return s.ljust(widths[name])

def _fmt_key_row(prefix, key_cols, widths, key):
    parts = [prefix]
    for i, name in enumerate(key_cols):
        val = "" if i >= len(key) else (key[i] if key[i] is not None else "")
        parts.append(_justify(name, val, widths))
    return "  ".join(parts)

def _print_rowcount_table(key_cols, rowcount_records, file=sys.stdout):
    if not rowcount_records:
        return
    keys_only = [rec["key"] for rec in rowcount_records]
    widths = _compute_widths(key_cols, keys_only, include_counts=True)
    hdr = ["[ROWCOUNT]"]
    for name in key_cols:
        hdr.append(_justify(name, _display_name(name), widths))
    for name in ("baseline", "candidate"):
        hdr.append(_justify(name, name, widths))
    print("  ".join(hdr), file=file)
    for rec in rowcount_records:
        line = _fmt_key_row("[   ]", key_cols, widths, rec["key"])
        line += "  " + _justify("baseline", rec["baseline"], widths)
        line += "  " + _justify("candidate", rec["candidate"], widths)
        print(line, file=file)

def _compute_diff_widths(diff_records):
    col_w = max(6, max((len(str(col)) for rec in diff_records for col in rec["diffs"].keys()), default=0))
    base_w = max(8, max((len(str(v[0])) for rec in diff_records for v in rec["diffs"].values()), default=0))
    cand_w = max(9, max((len(str(v[1])) for rec in diff_records for v in rec["diffs"].values()), default=0))
    return col_w, base_w, cand_w

def _print_diff_section(key_cols, diff_records, file=sys.stdout):
    if not diff_records:
        return
    keys_only = [rec["key"] for rec in diff_records]
    key_widths = _compute_widths(key_cols, keys_only)
    col_w, base_w, cand_w = _compute_diff_widths(diff_records)
    for rec in diff_records:
        print(_fmt_key_row("[DIFF]", key_cols, key_widths, rec["key"]), file=file)
        print("       " + "column".ljust(col_w) + "  " + "baseline".ljust(base_w) + "  " + "candidate".ljust(cand_w), file=file)
        for col, (b, c) in rec["diffs"].items():
            print("       " + str(col).ljust(col_w) + "  " + str(b).ljust(base_w) + "  " + str(c).ljust(cand_w), file=file)
        print("", file=file)


def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument("--baseline", required=True)
    p.add_argument("--candidate", required=True)
    p.add_argument("--schema", default=None)
    p.add_argument("--align-key", default="timestamp,event,ticket,op",
                   help="Comma-separated key columns used to align rows")
    p.add_argument("--float-tol-price", type=float, default=1e-4)
    p.add_argument("--float-tol-money", type=float, default=1e-2)
    p.add_argument("--float-tol-lots",  type=float, default=1e-6)
    p.add_argument("--max-diffs", type=int, default=50)
    p.add_argument("--ignore-cols", default="",
                   help="Comma-separated list of columns to ignore in value compare")
    p.add_argument("--strict-rows", action="store_true",
                   help="Fail if row counts do not match after alignment")
    p.add_argument("--delimiter", default=None,
                   help="CSV delimiter override (default: auto-detect; if fails, falls back to ',')")
    return p.parse_args()

def read_csv(path, delimiter_override=None):
    if not os.path.exists(path):
        raise FileNotFoundError(path)
    with open(path, "r", encoding="utf-8", newline="") as f:
        sample = f.read(4096)
        remainder = f.read()
    if delimiter_override:
        delimiter = delimiter_override
        print(f"[info] Using explicit delimiter: {delimiter}")
    else:
        try:
            dialect = csv.Sniffer().sniff(sample)
            delimiter = dialect.delimiter
            print(f"[info] Auto-detected delimiter: {delimiter}")
        except Exception:
            delimiter = ','
            print(f"[warn] Could not auto-detect delimiter. Falling back to ','")
    reader = csv.reader(io.StringIO(sample + remainder), delimiter=delimiter)
    rows = list(reader)
    # Strip BOM from first header field if present
    if rows and rows[0]:
        rows[0][0] = rows[0][0].lstrip("\ufeff")
    header = rows[0]
    data = rows[1:]
    return header, data

def load_schema(schema_path):
    if not schema_path or not os.path.exists(schema_path):
        return None
    with open(schema_path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"): 
                continue
            cols = [c.strip() for c in line.replace(";", ",").split(",")]
            return cols
    return None

def to_key(row, header, key_cols):
    idxs = [header.index(k) for k in key_cols if k in header]
    return tuple(row[i] if i < len(row) else "" for i in idxs)

def try_float(x):
    try: 
        return float(x)
    except:
        return None

PRICE_COLS = {"price","open_price","close_price","bid","ask"}
MONEY_COLS = {"profit","commission","swap","balance","equity"}
LOTS_COLS  = {"lots","volume"}

def compare_rows(b_row, c_row, header, ignore_set,
                 tol_price, tol_money, tol_lots):
    diffs = {}
    for i, col in enumerate(header):
        if col in ignore_set: 
            continue
        b = b_row[i] if i < len(b_row) else ""
        c = c_row[i] if i < len(c_row) else ""
        if b == c:
            continue
        bn = try_float(b)
        cn = try_float(c)
        if bn is not None and cn is not None:
            if col.lower() in PRICE_COLS:
                if abs(bn - cn) > tol_price:
                    diffs[col] = (b, c)
            elif col.lower() in MONEY_COLS:
                if abs(bn - cn) > tol_money:
                    diffs[col] = (b, c)
            elif col.lower() in LOTS_COLS:
                if abs(bn - cn) > tol_lots:
                    diffs[col] = (b, c)
            else:
                if bn != cn:
                    diffs[col] = (b, c)
        else:
            diffs[col] = (b, c)
    return diffs

def main():
    args = parse_args()

    b_header, b_rows = read_csv(args.baseline, args.delimiter)
    c_header, c_rows = read_csv(args.candidate, args.delimiter)

    if args.schema:
        expected = load_schema(args.schema)
        if expected:
            if [h.strip() for h in b_header] != expected:
                print("[ERROR] Baseline header does not match schema")
                print("Expected:", expected)
                print("Found   :", b_header)
                sys.exit(1)
            if [h.strip() for h in c_header] != expected:
                print("[ERROR] Candidate header does not match schema")
                print("Expected:", expected)
                print("Found   :", c_header)
                sys.exit(1)

    key_cols = [k.strip() for k in args.align_key.split(",") if k.strip()]
    b_map = {}
    for r in b_rows:
        b_map.setdefault(to_key(r, b_header, key_cols), []).append(r)
    c_map = {}
    for r in c_rows:
        c_map.setdefault(to_key(r, c_header, key_cols), []).append(r)

    ignore_set = set([c.strip() for c in args.ignore_cols.split(",") if c.strip()])

    total = 0
    mismatches = 0
    shown = 0

    # Collect records first for formatting
    rowcount_records = []
    diff_records = []

    all_keys = sorted(set(b_map.keys()) | set(c_map.keys()))
    for k in all_keys:
        b_list = b_map.get(k, [])
        c_list = c_map.get(k, [])
        if len(b_list) != len(c_list):
            rowcount_records.append({"key": _stringify_key(k), "baseline": len(b_list), "candidate": len(c_list)})
            if args.strict_rows:
                mismatches += 1
                continue
        # Compare aligned rows up to min length
        for i in range(min(len(b_list), len(c_list))):
            total += 1
            diffs = compare_rows(b_list[i], c_list[i], b_header, ignore_set,
                                 args.float_tol_price, args.float_tol_money, args.float_tol_lots)
            if diffs:
                mismatches += 1
                if shown < args.max_diffs:
                    diff_records.append({"key": _stringify_key(k), "diffs": diffs})
                    shown += 1

    # Pretty-print
    if rowcount_records:
        _print_rowcount_table(key_cols, rowcount_records)
        print("")
    if diff_records:
        _print_diff_section(key_cols, diff_records)

    print(f"\nSUMMARY: compared_pairs={total} mismatches={mismatches}")
    if mismatches == 0:
        print("RESULT: PASS")
        sys.exit(0)
    else:
        print("RESULT: FAIL")
        sys.exit(1)

if __name__ == "__main__":
    main()
