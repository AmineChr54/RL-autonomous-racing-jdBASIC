"""Cross-check torch.jdb against real PyTorch (float64): forward, MSE and smooth-L1/GATHERCOL losses, gradients, one Adam step.

    python tests/torch_vs_pytorch.py [--native]      (needs torch; skips with a message when it is missing)

Weights and inputs come from closed formulas shared with tests/torch_dump.jdb, so nothing is exchanged but the results.
"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
try:
    import torch
except ImportError:
    print("torch is not installed: skipping the PyTorch cross-check")
    sys.exit(0)
import numpy as np
from tools import jd

TOL = 1e-9
native = "--native" in sys.argv
os.makedirs(os.path.join(HERE, "out"), exist_ok=True)
jd.run("tests/torch_dump.jdb", native=native)

ref = {}
for line in open(os.path.join(HERE, "out", "torch_ref.csv"), encoding="utf-8"):
    p = line.strip().split(",")
    if p and p[0]:
        ref[p[0]] = np.array([float(v) for v in p[1:]])

def make(sizes):
    ps = []
    for l in range(len(sizes) - 1):
        ni, no = sizes[l], sizes[l + 1]
        w = np.array([[0.3 * np.sin(0.37 * (i * no + j) + l + 0.5) for j in range(no)] for i in range(ni)])
        b = np.array([[0.05 * np.cos(0.7 * j + l) for j in range(no)]])
        ps += [torch.tensor(w, requires_grad=True), torch.tensor(b, requires_grad=True)]
    return ps

def fwd(ps, x):
    h = x
    for l in range(len(ps) // 2):
        h = h @ ps[2 * l] + ps[2 * l + 1]
        if l < len(ps) // 2 - 1:
            h = torch.tanh(h)
    return h

n = 6
X = torch.tensor([[np.sin(0.21 * (r * 8 + c) + 0.3) for c in range(8)] for r in range(n)])
T = torch.tensor([[0.5 * np.cos(0.9 * (r * 2 + c)) for c in range(2)] for r in range(n)])
Y = torch.tensor([2.0 * np.sin(r * 1.7) for r in range(n)])
idx = torch.tensor([r % 5 for r in range(n)])

fails = 0
def check(name, mine, theirs):
    global fails
    d = float(np.max(np.abs(mine - np.asarray(theirs).reshape(-1))))
    ok = d <= TOL
    fails += 0 if ok else 1
    print(f"  {'ok  ' if ok else 'FAIL'} {name:12s} max |diff| {d:.2e}")

def case(tag, sizes, lossfn, outname):
    ps = make(sizes)
    o = fwd(ps, X)
    loss = lossfn(o)
    loss.backward()
    check(f"{tag} {outname}", ref[f"{tag}_{outname}"], o.detach().numpy())
    check(f"{tag} loss", ref[f"{tag}_loss"], loss.detach().numpy())
    for k, p in enumerate(ps):
        check(f"{tag} grad{k}", ref[f"{tag}_grad{k}"], p.grad.numpy())
    opt = torch.optim.Adam(ps, lr=0.01)   # torch's Adam sees the same gradients
    opt.step()
    for k, p in enumerate(ps):
        check(f"{tag} param{k}", ref[f"{tag}_param{k}"], p.detach().numpy())

print("torch.jdb vs PyTorch %s, %s" % (torch.__version__, "native" if native else "interpreted"))
case("A", [8, 16, 16, 2], lambda o: ((o - T) ** 2).mean(), "out")
case("B", [8, 16, 16, 5], lambda o: torch.nn.functional.smooth_l1_loss(o.gather(1, idx[:, None])[:, 0], Y), "q")
print("PASS" if fails == 0 else f"{fails} FAILED")
sys.exit(1 if fails else 0)
