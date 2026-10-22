"""Env parity: run the original Python SwarmEnv and the jdBasic ENV on the same action script, compare traces.

    python tests/env_parity.py          (from the jdBasic project root; --native: compile with -c first)
"""
import os, subprocess, sys
import numpy as np
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import jd                                                         # memory-capped jdBasic runner

PY_PROJECT = os.environ.get("PY_PROJECT", r"D:\Projects\RL-autonomous-racing")   # the Python original
sys.path.insert(0, PY_PROJECT)
from track import Track
from env import SwarmEnv

N, T = 20, 300
os.makedirs("tests/out", exist_ok=True)
env = SwarmEnv(Track("hard"), n=N, max_steps=200, seed=0)
class _NoNoise:                                                  # no start noise
    def normal(self, loc, scale, size): return np.zeros(size)
    def integers(self, lo, hi, size): return np.zeros(size, np.int64)
env.rng = _NoNoise()
obs = env.reset()
rows = []
for t in range(T):
    # cars 0-3 brake (-> "stuck"), the others steer toward open space (-> long drives, timeouts)
    act = np.zeros((N, 2), np.float32)
    for k in range(N):
        o = obs[k].astype(np.float64)
        steer = (o[4] + o[5] + o[6] - o[0] - o[1] - o[2]) * (1.5 + 0.1 * k)
        act[k, 0] = np.float32(steer)
        act[k, 1] = np.float32(-1.0 if k < 4 else 0.15 + 0.02 * k)
    obs, rew, done, _ = env.step(act)
    for k in range(N):
        rows.append([t, k, *obs[k].tolist(), float(rew[k]), int(done[k]), float(env.progress[k])])
ref = np.array(rows)

if "--no-run" not in sys.argv:
    jd.run("tests/env_parity.jdb", native="--native" in sys.argv)
jdt = np.loadtxt("tests/out/env_jd.csv", delimiter=",")
assert jdt.shape == ref.shape, (jdt.shape, ref.shape)
names = [f"ray{r}" for r in range(7)] + ["speed", "reward", "done", "progress"]
worst = 0.0
for c, name in enumerate(names, start=2):
    diff = np.abs(jdt[:, c] - ref[:, c])
    worst = max(worst, diff.max() if name != "progress" else 0)
    bad = np.nonzero(diff > 1e-4)[0]
    first = f"  first at t={int(ref[bad[0], 0])} car={int(ref[bad[0], 1])}" if len(bad) else ""
    print(f"{name:9s} max |diff| {diff.max():.3g}  rows > 1e-4: {len(bad)}{first}")
print("deaths python", int(ref[:, 11].sum()), " jdbasic", int(jdt[:, 11].sum()), " (of", N, "cars; crash or timeout)")
print("PASS" if worst <= 1e-4 else "FAIL")
