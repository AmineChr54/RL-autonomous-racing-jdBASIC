"""Brain parity: jdBasic BRAIN.FORWARD against brain.py's forward_numpy on the same genomes.

    python tests/brain_parity.py [--native]      (from the jdBasic project root)
"""
import os, subprocess, sys
import numpy as np
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import jd                                                         # memory-capped jdBasic runner
sys.path.insert(0, os.environ.get("PY_PROJECT", r"D:\Projects\RL-autonomous-racing"))   # the Python original
from brain import forward_numpy, genome_size

os.makedirs("tests/out", exist_ok=True)
jd.run("tests/brain_check.jdb", native="--native" in sys.argv)
G = np.loadtxt("tests/out/brain_g.csv", delimiter=",")
obs = np.loadtxt("tests/out/brain_obs.csv", delimiter=",")
out = np.loadtxt("tests/out/brain_out.csv", delimiter=",")
ref = forward_numpy(G, obs)
err = np.abs(ref - out).max()
print(f"genome {G.shape[1]} (python {genome_size()}), max |diff| {err:.3g}")
print("PASS" if err < 1e-9 and G.shape[1] == genome_size() else "FAIL")
