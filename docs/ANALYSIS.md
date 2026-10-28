# Analysis: what the port shows

All numbers were measured in this repo (jdBasic Build 102, Windows x64, Ryzen AI 9 HX 370, hard track, 200 cars, seed 0 unless
stated). Sources: `bench.jdb`, `plot_curves.jdb`, `par_seeds.jdb`, `STATUS.md`, `COMPARISON.md`.

## 1. Which algorithm learns best?

| method | iterations to half a lap (8 seeds, mean, range) | final mean distance | spread between seeds |
|---|---|---|---|
| PPO | 14.2 (11-18) | 5381 px after 30 | 2% |
| neuroevolution | 24.8 (19-30) | 3113 px after 30 | 16% |
| REINFORCE | 42.2 (36-52) | 3712 px after 60 | 9% |
| DQN | never in 15 | 152 px after 15 | not measured |

- **PPO wins on every axis**: about 3x fewer iterations than REINFORCE, and it is by far the most repeatable (a 2% spread).
- **Evolution is quick to start but noisy**: its worst seed ended at 1986 px, its best at 3590 px. It needs no gradients, and one
  generation costs the same as an iteration of the others (about 5 s native).
- **REINFORCE is steady but slow**; its curve keeps rising at iteration 100 (4702 px, best car 1.8 laps).
- **DQN is undecided**: 15 iterations is too short, and an iteration costs about 45 s (see 3), so a fair run takes hours.
- One seed is not evidence. Seed 0 happened to be the best or near the best for several methods, so single-curve claims in the
  Python README should be read with the spread in mind.

## 2. How fast is the compiled backend?

Interpreted vs native (`-c`), ms per call: brain forward 16.9 -> 2.1 (8x), ray casting 31.1 -> 1.19 (26x), env tick 34.9 -> 1.32
(26x), evolution tick 50.2 -> 3.3 (15x). Whole iterations: evolution 70 s -> 5.2 s, REINFORCE 14.5 s -> 5.9 s. The native build
is what makes training practical; the interpreter is for checking.

## 3. What limits speed

- Native array kernels run at about 7-14 ns per multiply-add (scalar loop 13.6 ns, `MATMUL` 6.6 ns). Reordering or unrolling the
  loops did not help (`STATUS.md`, #46). DQN does 256 learn steps of batch 512 per iteration, so it is the one that suffers.
- Whole-array temporaries are never freed in native builds (bug 9). That is why the compiled learners are scalar loops over
  preallocated arrays (about 1000 extra lines against the Python) and why `tests/leak_check.sh` guards memory in CI.
- Memory is flat where it matters: evolution 63 MB, REINFORCE 77 MB, PPO 64 MB, DQN 58 MB per process.

## 4. Using more of the machine

- One race cannot be split over threads (workers get copies of globals; copying state every tick costs more than the 1.3 ms tick).
- Whole trainings can run in parallel: 8 evolution seeds in 263 s instead of about 1250 s (4.7x), REINFORCE 4.5x, PPO 3.3x. PPO
  and DQN need staggered worker starts because `TRAINER.NEW` registers parameters in module globals that threads share.
- The integrated Radeon cannot do compute from jdBasic (OpenGL 3.3 without compute shaders; `OS.FEATURE("OPENGL")` is false in
  this build), and there is no CUDA on an AMD machine.

## 5. Is the port faithful?

- Track, environment and brains match the Python original (env max diff 5e-10, brain 2e-16, identical track pixel counts).
- `torch.jdb` matches real PyTorch 2.9.1 to 1e-16 for forward, MSE and smooth-L1/gather losses, every gradient and an Adam step
  (`tests/torch_vs_pytorch.py`), interpreted and native.
- The seed-0 results of the parallel runs equal the single-process runs exactly (evolution 26, REINFORCE 38, PPO 11 iterations to
  half a lap), so threads do not change the maths.

## 6. What would change the picture

A jdBasic with leak-free array temporaries and faster array kernels would shrink the port (the scalar-loop learners could go
back to the tape) and make DQN practical. Achim reports the leaks fixed in Build 109 / v1.2.0; that is the first thing to
re-measure once the new build is installed. Draft upstream reports: `docs/UPSTREAM_REPORTS.md`.
