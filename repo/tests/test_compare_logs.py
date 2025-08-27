import subprocess, sys, textwrap, tempfile, pathlib

def run_compare(baseline, candidate):
    with tempfile.TemporaryDirectory() as d:
        d_path = pathlib.Path(d)
        b = d_path / 'baseline.csv'
        c = d_path / 'candidate.csv'
        b.write_text(textwrap.dedent(baseline).lstrip())
        c.write_text(textwrap.dedent(candidate).lstrip())
        result = subprocess.run(
            [sys.executable, 'repo/tools/compare_logs.py', '--baseline', str(b), '--candidate', str(c)],
            capture_output=True,
            text=True,
        )
        return result

def test_swapped_order_identical_rows():
    baseline = """\
    timestamp,event,ticket,op,lots
    1,trade,100,0,0.1
    1,trade,100,0,0.2
    """
    candidate = """\
    timestamp,event,ticket,op,lots
    1,trade,100,0,0.2
    1,trade,100,0,0.1
    """
    res = run_compare(baseline, candidate)
    assert res.returncode == 0, res.stdout + res.stderr
    assert 'RESULT: PASS' in res.stdout

