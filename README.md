# 🏎️ RL Autonomous Racing, in jdBasic

A port of [RL-autonomous-racing](https://github.com/AmineChr54/RL-autonomous-racing) (Python: numpy + PyTorch + pygame) to **jdBasic**. A swarm of 200 cars, each with a tiny neural network as its brain, learns to lap a winding track. The same environment is solved with four learning algorithms: neuroevolution, REINFORCE, DQN and PPO.

jdBasic has no autodiff and no deep-learning library, so this repo also contains **`torch.jdb`, a small PyTorch written in plain jdBasic**: a tape-based reverse-mode autograd, MLPs, Adam and gradient clipping, checked against finite differences.

The port has three goals:

1. **Rewrite the project in jdBasic** with the same file layout, constants and behaviour as the Python original, so the two can be compared side by side.
2. **Find out what jdBasic is missing** for this kind of numeric work, and how much each gap costs. This goes into `COMPARISON.md`.
3. **Run it both ways**: interpreted (`jdBasic main.jdb`) and compiled to a native `.exe` (`jdBasic -c main.jdb`).

> **Status: work in progress.** The world (track and env), the per-car brains and the autograd engine are done. Each matches Python, or a numeric gradient for the autograd, in both backends. Neuroevolution runs in the interpreter. The gradient-based algorithms, the window and the docs are being built. See the [issues](../../issues) for what is done and what is next.

## What is in here

| File | Ports | What it does | Status |
|---|---|---|---|
| `track.jdb` | `track.py` | Closed Catmull-Rom spline, uniform resample, road mask and nearest-centerline index map as flat arrays | ✅ identical to Python (171 870 road pixels, 3 186 px lap) |
| `env.jdb` | `env.py` | 200 cars: physics, 7 ray sensors, crash/stuck/timeout, progress reward | ✅ parity with Python, max diff 5e-10 |
| `torch.jdb` | (PyTorch) | Tape autograd with 20 ops, MLP, Adam, `clip_grad_norm`, polyak, JSON save/load | ✅ gradcheck passes interpreted and native |
| `brain.jdb` | `brain.py` | 290-number genomes, every car runs its own net, batched without `bmm` | ✅ identical to `forward_numpy` (2e-16) |
| `evolution.jdb` | `evolution.py` | Elites, crossover, mutation | 🚧 interpreter works, native in progress |
| `rl_common.jdb`, `reinforce.jdb` | `rl_common.py`, `reinforce.py` | Shared rollout plumbing, REINFORCE on `torch.jdb` (tape in the interpreter, leak-free scalar loops under `-c`) | ✅ learns: mean passes half a lap at iteration 38 |
| `ppo.jdb` | `ppo.py` | PPO: GAE, clipped objective, critic (tape in the interpreter, leak-free scalar loops under `-c`) | ✅ learns: mean passes half a lap at iteration 11, 5613 px mean after 50 |
| `dqn.jdb` | `dqn.py` | DQN: replay buffer, target net, tape in the interpreter, scalar loops under `-c` | ✅ runs, gradients match; ~80 s/iteration, learning not yet measured |
| `main.jdb` | `main.py` | Window (GFX) and headless modes, same flags and keys | ⏳ |
| `plot_curves.jdb`, `bench.jdb` | `plot_curves.py`, `accel.py` | Learning-curve chart (SVG), timings interpreted vs native | ⏳ |

## How it works

### The world

* **Track:** a closed loop through 13 (easy) or 20 (hard) control points, pre-rendered into a road mask and a "how far along the track am I?" map. Both are flat 1-D arrays indexed `y * 1000 + x`.
* **Simulation:** every tick each car picks `steer` and `throttle` in [-1, 1]. Speed has drag, and turning depends on speed. State is rounded to float32 (`CSNG`) like the numpy original, so both versions drive bit-for-bit alike.
* **Sensors:** 7 distance rays (-90° … +90°, 120 px) plus the car's speed: 8 numbers.
* **Episode end:** off the road, stuck for 70 ticks, or the time limit (900 ticks).
* **Reward:** `0.1 * pixels gained along the track - 5 if crashed or stuck`.

### `torch.jdb`: a mini PyTorch

```basic
IMPORT TORCH
DIM gen AS INTEGER = RNG.NEW(0)
DIM net AS MAP = TORCH.MLP_NEW([8, 32, 32, 2], gen)        ' Linear+Tanh stack, torch's default init
DIM opt AS MAP = TORCH.ADAM_NEW(TORCH.MLP_PIDS(net), 0.001)
TORCH.RESET()                                               ' start a new tape
DIM pred AS INTEGER = TORCH.MLP_FWD(net, TORCH.C(obs))      ' nodes are integer ids on the tape
DIM loss AS INTEGER = TORCH.TMEAN(TORCH.SQUARE(TORCH.MINUS(pred, TORCH.C(target))))
TORCH.ZERO_GRAD(TORCH.MLP_PIDS(net))
TORCH.BACKWARD(loss)
TORCH.ADAM_STEP(opt)
```

Every tensor is 2-D. The heavy maths runs on jdBasic's C++ array builtins (`MATMUL` is Eigen; `TANH` and `EXP` are vectorised). The ops: `MM`, `ADDROW`, `MULROW`, `BCASTROW`, `ADD`, `MINUS`, `MUL`, `SCALE`, `ADDS`, `TTANH`, `TEXP`, `SQUARE`, `TMEAN`, `TSUM`, `ROWSUM`, `MINIMUM`, `TCLAMP`, `GATHERCOL`, `SMOOTH_L1`, plus `NORMAL_LOGP` for Gaussian policies.

### Brains without a batched matmul

Neuroevolution gives every car its own network. Python evaluates all 200 at once with `torch.baddbmm`. jdBasic has no 3-D matmul, so `brain.jdb` does each layer with three ordinary 2-D `MATMUL`s, still for the whole swarm at once. It expands the inputs, multiplies element-wise by each car's weights, then sums per output.

## Quick start

Needs jdBasic v1.1 Build 102 or newer (Windows x64; the `-c` native compiler needs MSVC Build Tools).

```bash
jdBasic tests/evo_smoke.jdb 3          # 3 generations of neuroevolution, prints progress
jdBasic -c tests/evo_smoke.jdb         # compile to tests/evo_smoke.exe
```

The planned entry point mirrors the Python one: `jdBasic main.jdb --mode ppo --track hard --headless --gens 40`.

## Tests

| Command | Checks |
|---|---|
| `tools/jd.sh run tests/track_check.jdb` | track build (point count, lap length, road pixels) |
| `python tests/env_parity.py [--native]` | jdBasic env against the Python `SwarmEnv`, 20 cars × 300 ticks |
| `python tests/brain_parity.py [--native]` | per-car brains against `brain.forward_numpy` |
| `tools/jd.sh run\|native tests/torch_gradcheck.jdb` | all 20 autograd ops against central finite differences |

The Python tests import the original project from `D:\Projects\RL-autonomous-racing`, or from `$PY_PROJECT`.

### Always run jdBasic under the memory cap

`tools/jd.sh run|native|build file.jdb [args]` runs jdBasic inside a Windows Job Object with a hard memory limit (`JD_MEM`, default 1024 MB) and a time limit (`JD_TIME`, default 600 s). `tools/jd.py` does the same for the Python tests. A few native-compiler bugs (below) can allocate many GB in seconds, and the cap turns that into a clean failure. The runner is `tools/capped.cs`, built by `tools/build_capped.sh` with the C# compiler that ships with Windows.

## Writing jdBasic that also compiles with `-c`

The native compiler is strict and fixes a type for every value at compile time. These rules were each found the hard way during the port:

* Declare every parameter that takes an array or map `AS ARRAY` / `AS MAP`, and give every function that returns one `AS ARRAY` / `AS MAP`. An untyped parameter is a number under `-c`.
* Put the result of a builtin that has both scalar and array forms (`CLAMP`, `ABS`, `FLOOR`, comparisons) in a local declared `DIM x AS ARRAY = ...`.
* Never `ZEROS([r, c])` / `ONES([r, c])` with many rows: their memory grows with the square of the rows under `-c`. Use `TORCH.ZEROS_RC` / `ONES_RC` (a flat array plus `RESHAPE`).
* Never grow a big string with `s$ = s$ + ...` in a loop under `-c`; append blocks to the file instead.
* No implicit broadcasting: repeat a row explicitly with `MATMUL(ONES_RC(n, 1), row)`.
* Identifiers are case-insensitive (`genome` and `GENOME` clash), and `STEP` is reserved.

The full list of jdBasic bugs and gaps, each with its workaround and measured cost, goes into `COMPARISON.md`.

## Development workflow

Every feature or fix is a GitHub issue, worked on a branch and merged through a pull request once the checks pass. CI runs on a **self-hosted GitHub Actions runner in a local Docker container**, because the hosted runners have limits. The container has a hard 3 GB memory limit (`--memory 3g --memory-swap 3g`). Native (`-c`) builds are checked in CI too (Linux LLVM build) and locally with `tools/jd.sh native`.

```bash
ci/start-runner.sh   # Git Bash: builds the image, fetches a registration token via gh (never stored), starts the container
ci/stop-runner.sh    # deregisters the runner and removes the container
```
The container restarts automatically (`--restart unless-stopped`). Details are in `ci/README.md`.
The runner image builds jdBasic natively on Linux from upstream source (g++ + LLVM 18, pinned commit, no Wine), so the `jdbasic` job in `.github/workflows/ci.yml` runs the real tests in the interpreter and under `-c`; both jobs are required.

## Credits

The original Python project, its algorithms and constants: [AmineChr54/RL-autonomous-racing](https://github.com/AmineChr54/RL-autonomous-racing). MIT licensed, see `LICENSE`.
