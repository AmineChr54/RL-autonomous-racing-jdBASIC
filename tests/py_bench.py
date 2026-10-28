"""Python-side timings for the same operations bench.jdb measures (200 cars, hard track), for COMPARISON.md.

    python tests/py_bench.py        (needs the Python original; $PY_PROJECT or the default D: path\RL-autonomous-racing)
"""
import os, sys, time
import numpy as np
PY_PROJECT = os.environ.get("PY_PROJECT", r"D:\Projects\RL-autonomous-racing")
sys.path.insert(0, PY_PROJECT)
from track import Track
from env import SwarmEnv
import brain

tr = Track("hard")
env = SwarmEnv(tr, n=200, max_steps=900, seed=0)
rng = np.random.default_rng(1)
G = brain.random_genomes(200, rng=rng)
obs = env.reset()
act = brain.forward_numpy(G, obs)

def per_call_ms(fn, reps):
    fn()
    t0 = time.perf_counter()
    for _ in range(reps):
        fn()
    return (time.perf_counter() - t0) / reps * 1000

res = {
    "brain_forward_ms": per_call_ms(lambda: brain.forward_numpy(G, obs), 200),
    "ray_distances_ms": per_call_ms(env.ray_distances, 200),
    "env_tick_ms": per_call_ms(lambda: env.step(act), 200),
}
for k, v in res.items():
    print(f"{k:18s} {v:8.3f}")
