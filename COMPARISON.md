# Python vs jdBasic

The jdBasic port of [RL-autonomous-racing](https://github.com/AmineChr54/RL-autonomous-racing), side by side.
All jdBasic numbers are from Build 102 (the installed build), 200 cars, hard track, seed 0, on a Ryzen AI 9 HX 370.

## Lines of code

| Component | Python | jdBasic | Why jdBasic is longer |
|---|---|---|---|
| track | 86 | 202 | no numpy/PIL: polyline offsetting and the road mask are written out |
| env | 156 | 366 | no broadcasting: scalar loops over preallocated arrays (fast under `-c`, no leaks) |
| brain | 96 | 127 | no batched matmul: three 2-D `MATMUL`s per layer |
| evolution | 95 | 142 | |
| reinforce | 60 | 223 | no autodiff in the compiled path: hand-written forward/backward loops |
| ppo | 94 | 571 | same, plus clipped-objective gradients by hand |
| dqn | 80 | 458 | same |
| rl_common | 68 | 517 | holds the shared loops that replace `torch` |
| main (CLI + GUI) | 300 | 215 (+337 gui, 301 record) | `gui.jdb` and `record.jdb` split out |
| plot_curves | 67 | 107 | SVG written by hand instead of matplotlib |
| (extra) torch.jdb | - | 600 | tape autograd, MLP, Adam (stands in for PyTorch) |
| (extra) lib/gif.jdb | - | 568 | LZW GIF writer (stands in for PIL) |

The difference is almost all in the learners: Python gets `torch.autograd` for free.

## Run time (200 cars, ms per call, `bench.jdb`)

| op | interpreted | native -c | speedup |
|---|---|---|---|
| BRAIN.FORWARD | 16.9 | 2.10 | 8x |
| ENV.RAY_DISTANCES | 31.1 | 1.19 | 26x |
| ENV.TICK (full) | 34.9 | 1.32 | 26x |
| EVOLUTION.ADVANCE (1 tick) | 50.2 | 3.33 | 15x |

Whole iterations (native): evolution 5.2 s/generation (peak 63 MB), REINFORCE 5.9 s/iteration (peak 77 MB), DQN about 80 s/iteration (#46).
Python-side timings: still to measure.

## Learning results

See `assets/curves.svg` (made by `plot_curves.jdb`). Table of half-lap iteration and final distances: filled in when #26 lands.

## What replaced what

| Python | jdBasic |
|---|---|
| numpy broadcasting | explicit loops or `MATMUL(ONES(...), row)` (broadcasting is unsafe across backends) |
| `torch.autograd` | `torch.jdb` tape (interpreter) and hand-written loops (compiled) |
| `torch.baddbmm` | three 2-D `MATMUL`s per layer |
| pygame | `GFX.*` / SDL3, `gui.jdb` |
| PIL GIF | `lib/gif.jdb` |
| ONNX / DirectML (`accel.py`) | nothing: the build has no ONNX and no GPU compute |

## jdBasic bugs found (with the workaround and what it cost)

1. Untyped `FUNC` parameter that receives an array reads as 0 under `-c`. Fix: `AS ARRAY` / `AS MAP` everywhere.
2. A `FUNC` returning `CLAMP(array, ...)` without `AS ARRAY` returns 0.
3. `ZEROS([r, c])` / `ONES([r, c])` use memory quadratic in `r` under `-c` (150000x8 = 14.5 GB). Fix: flat array + `RESHAPE`.
4. String concatenation in a loop leaks every temporary under `-c`. Fix: `TXTWRITER ... TRUE` blocks.
5. Broadcasting `[N,k] op [k]` segfaults under `-c`; `[N,k] op [[1,k]]` returns one row.
6. `DIM x = 0` is an INTEGER forever; an array assigned to it becomes 0.
7. In a module, a Map value in an untyped local never matches `SWITCH CASE`.
8. `ONES([m{"r"}, m{"c"}])` with a shape from Map values crashes.
9. Whole-array temporaries (`MATMUL`, `a * b`, `TANH`, `RESHAPE`) are never freed under `-c`: +160 MB for 200 iterations. The biggest cost of the port: it forced scalar-loop learners (about 1,000 extra lines) (#35).
10. `RAND.DRAWS(gen, "normal", n)` returns zeros (sigma defaults to 0).
11. `TESTKIT.EQARRAY` on 2-D arrays is always false under `-c` (#36).
12. `NOW_EPOCH()` has whole-second resolution under `-c` (#37).
13. Interpreter: an `ASYNC FUNC` sees module CONSTs/globals as 0 (#38).
14. `DF.WRITECSV` writes 6 significant digits (#39).
15. `TORCH.LOAD_JSON` is broken under `-c` (#45).
16. GFX gaps found by the GUI port (#52).

Achim reports these are fixed in Build 109 / v1.2.0; to be re-verified (see below).

## What jdBasic should add (priority order)

1. Free whole-array temporaries under `-c` (bug 9). Removes the scalar-loop learners.
2. General broadcasting that behaves the same in both backends.
3. N-D axis reductions and batched matmul (`baddbmm` equivalent), plus `SHAPE()`.
4. Built-in autodiff, or promote `torch.jdb` to `lib/`.
5. GPU compute: compute shaders or FBO read-back in `GL.*`, or ONNX/DirectML in the native build.
6. FFI with double and array parameters.
7. Polygon fill in `GFX`, a GIF writer in the library, 2-D gather, `RAND.NORMAL` / `randperm` builtins.

## Re-verification on Build 109 / v1.2.0

Pending: the v1.2.0 binary has not been installed yet. Each bug above gets a minimal repro run on the new build, and every fixed workaround is removed.
