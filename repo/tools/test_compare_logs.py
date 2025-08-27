import sys
import subprocess
from pathlib import Path


TOOLS_DIR = Path(__file__).resolve().parent
sys.path.append(str(TOOLS_DIR))

import compare_logs  # noqa: E402


def test_load_schema_and_headers(tmp_path):
    schema_path = tmp_path / "schema.txt"
    schema_path.write_text("""# comment line
col1,col2
col3,col4
""")

    cols = compare_logs.load_schema(str(schema_path))
    assert cols == ["col1", "col2", "col3", "col4"]

    header = "col1,col2,col3,col4\n"
    baseline = tmp_path / "baseline.csv"
    candidate = tmp_path / "candidate.csv"
    baseline.write_text(header + "1,2,3,4\n")
    candidate.write_text(header + "1,2,3,4\n")

    result = subprocess.run([
        sys.executable,
        str(TOOLS_DIR / "compare_logs.py"),
        "--baseline", str(baseline),
        "--candidate", str(candidate),
        "--schema", str(schema_path),
        "--align-key", "col1",
    ], capture_output=True, text=True)

    assert result.returncode == 0, result.stdout + result.stderr


def test_header_mismatch_fails(tmp_path):
    schema_path = tmp_path / "schema.txt"
    schema_path.write_text("""# schema
col1,col2
col3
""")

    header_ok = "col1,col2,col3\n"
    header_bad = "col1,col2,colX\n"
    baseline = tmp_path / "baseline.csv"
    candidate = tmp_path / "candidate.csv"
    baseline.write_text(header_ok + "1,2,3\n")
    candidate.write_text(header_bad + "1,2,3\n")

    result = subprocess.run([
        sys.executable,
        str(TOOLS_DIR / "compare_logs.py"),
        "--baseline", str(baseline),
        "--candidate", str(candidate),
        "--schema", str(schema_path),
        "--align-key", "col1",
    ], capture_output=True, text=True)

    assert result.returncode != 0
    assert "Candidate header does not match schema" in result.stdout


def test_lots_difference_detected(tmp_path):
    schema_path = tmp_path / "schema.txt"
    schema_path.write_text("timestamp,event,ticket,op,lots\n")

    header = "timestamp,event,ticket,op,lots\n"
    baseline = tmp_path / "baseline.csv"
    candidate = tmp_path / "candidate.csv"
    baseline.write_text(header + "1,trade,42,0,0.1\n")
    candidate.write_text(header + "1,trade,42,0,0.2\n")

    result = subprocess.run([
        sys.executable,
        str(TOOLS_DIR / "compare_logs.py"),
        "--baseline", str(baseline),
        "--candidate", str(candidate),
        "--schema", str(schema_path),
        "--align-key", "timestamp,event,ticket,op",
    ], capture_output=True, text=True)

def test_duplicate_key_mismatched_lots_reports_diff(tmp_path):
    header = "timestamp,event,ticket,op,lots\n"
    baseline = tmp_path / "b.csv"
    candidate = tmp_path / "c.csv"
    baseline.write_text(header + "1,A,100,0,0.01\n1,A,100,0,0.02\n")
    candidate.write_text(header + "1,A,100,0,0.01\n1,A,100,0,0.03\n")

    result = _run_compare(baseline, candidate, "timestamp,event,ticket,op")

    assert result.returncode != 0
    assert "lots=0.02" in result.stdout and "lots=0.03" in result.stdout