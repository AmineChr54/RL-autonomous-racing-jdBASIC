# Architecture

Everything is jdBasic. One module per file, each `EXPORT MODULE X`, loaded with `IMPORT`. Run from the repo root and always
through `tools/jd.sh` (hard memory cap).

```
track.jdb ──► env.jdb ──► brain.jdb ─────► evolution.jdb ─┐
                 │                                         ├─► trainer.jdb ─► main.jdb ─► gui.jdb
                 └──► rl_common.jdb ─► reinforce / ppo / dqn ┘        │             └─► record.jdb (GIFs, lib/gif.jdb)
                          └─► torch.jdb (tape autograd, MLP, Adam)    └─► plot_curves.jdb, bench.jdb, par_seeds.jdb,
                                                                          playable.jdb, train_brain.jdb
```

| File | Job |
|---|---|
| `track.jdb` | The closed track: centerline, road mask and nearest-centerline index maps as flat arrays (`y * WORLD_W + x`). Two tracks, `easy` and `hard`. |
| `env.jdb` | A swarm of cars simulated at once. Per car: steer and throttle in, 7 distance rays plus speed out (8 numbers). State is rounded to float32 so it matches the numpy original (max diff 5e-10). |
| `brain.jdb` | One 8-12-12-2 tanh network per car (a 290-number genome); all cars in one batch via 2-D `MATMUL`s (no batched matmul in jdBasic). |
| `evolution.jdb` | Neuroevolution: rank by fitness, keep elites, crossover and mutate the rest. |
| `torch.jdb` | A small PyTorch: tape autograd, 20 ops checked against finite differences, MLP, Adam, gradient clipping. |
| `rl_common.jdb` | Shared rollout buffers, returns, normalisation for the learners that share one brain. |
| `reinforce.jdb`, `ppo.jdb`, `dqn.jdb` | The three gradient learners. |
| `trainer.jdb` | One interface over all four methods: `NEW`, `ADVANCE` (one env tick), `LEADER`, `ACTS`, `SAVE_JSON$`. |
| `main.jdb`, `gui.jdb` | The CLI and the 1400x700 GFX window (track, cars, brain visualiser, learning curves). |
| `record.jdb`, `lib/gif.jdb` | Trains for real and writes GIFs; the GIF (LZW) encoder is our own. |
| `plot_curves.jdb`, `bench.jdb`, `par_seeds.jdb` | Learning curves (SVG), interpreted-vs-native timings, parallel multi-seed training. |
| `playable.jdb`, `train_brain.jdb` | Race the best evolved brain yourself; train and save that brain. |

## Two backends, one source

Each file runs in the interpreter and compiled (`jdBasic -c`, about 8-26x faster). The compiled path is strict, so the code follows
rules written up in `STATUS.md` and the README: typed `AS ARRAY` / `AS MAP` parameters, no 2-D `ZEROS` with many rows, no implicit
broadcasting, no string building in loops.

## Why the learners have two implementations

Under `-c` every whole-array temporary (`a * b`, `MATMUL`, `TANH`) is never freed (STATUS bug 9, #35). Training does thousands of
those per iteration, so memory would grow without bound. The compiled path therefore uses scalar loops over preallocated flat
arrays (`GradsLoop`, `LoopStep`); the interpreter uses the readable vector code on the `torch.jdb` tape. `tests/*_grad.jdb`
check that both give the same loss and gradients. `tests/leak_check.sh` (also in CI) fails if peak memory grows when a run gets
3x longer.

## Tests and CI

| Test | Checks |
|---|---|
| `tests/track_check.jdb` | track construction |
| `tests/env_parity.py`, `tests/brain_parity.py` | env and brain against the Python original |
| `tests/torch_gradcheck.jdb` | autograd against finite differences |
| `tests/*_grad.jdb`, `*_smoke.jdb` | learner gradients (tape vs loops) and short training runs |
| `tests/gif_selftest.jdb`, `tests/gui_pixels.jdb` | GIF encoder, road pre-render |
| `tests/leak_check.sh` | peak memory stays flat |

CI runs on a self-hosted runner in a local Docker container (3 GB cap) that builds jdBasic from upstream source (`ci/`).

## Parallelism and the GPU

`par_seeds.jdb` trains independent seeds in parallel threads (`lib/pool.jdb`, native only): evolution and REINFORCE work and
match single-process results; PPO and DQN share the autograd tape between threads and do not yet (#54). jdBasic's `GL.*` is
OpenGL 3.3 without compute shaders or read-back, so the integrated GPU can render but not simulate (#55).
