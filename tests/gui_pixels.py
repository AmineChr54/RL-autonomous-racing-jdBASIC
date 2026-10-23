"""GUI track pre-render parity: gui.jdb's TRACK_PIXELS vs the numpy pre-render of main.py's run_gui.

    python tests/gui_pixels.py [--native]
The yellow start line overwrites road / edge / background pixels in jdBasic, so the numpy counts (made without the line)
may only exceed the jdBasic counts by exactly the number of start-line pixels.
"""
import os, sys
import numpy as np
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import jd

PY_PROJECT = os.environ.get("PY_PROJECT", r"D:\Projects\RL-autonomous-racing")
sys.path.insert(0, PY_PROJECT)
from track import Track

if "--no-run" not in sys.argv:
    jd.run("tests/gui_pixels.jdb", native="--native" in sys.argv)
rows = {l.split()[0]: [int(v) for v in l.split()[1:]] for l in open("tests/out/gui_jd.txt") if l.strip()}
for name in ("easy", "hard"):
    m = Track(name).mask
    er = m.copy()
    er[1:-1, 1:-1] = m[1:-1, 1:-1] & m[:-2, 1:-1] & m[2:, 1:-1] & m[1:-1, :-2] & m[1:-1, 2:]
    er[1:-1, 1:-1] &= m[:-2, :-2] & m[2:, 2:] & m[:-2, 2:] & m[2:, :-2]
    edge = m & ~er
    ref = [int((~m).sum()), int((m & ~edge).sum()), int(edge.sum())]
    bg, road, ed, start = rows[name]
    diff = [r - j for r, j in zip(ref, (bg, road, ed))]
    print(name, "numpy", ref, "jdBasic", [bg, road, ed], "start-line pixels", start, "diff", diff)
    assert all(d >= 0 for d in diff) and sum(diff) == start, name
    assert 150 <= start <= 250, name
print("gui_pixels OK")
