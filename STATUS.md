# Port status (2026-10-22)

Plan: `C:\Users\amine\.claude\plans\pasted-content-id-b48a-rl-cosmic-robin.md`

## Always run jdBasic through the memory cap
`tools/jd.sh run|native|build file.jdb [args]` (JD_MEM MB, default 1024; JD_TIME s, default 600).
It uses `tools/capped.exe` (a Windows Job Object; source `tools/capped.cs`, build with
`C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe -out:tools\capped.exe tools\capped.cs`).
An uncapped native test once took 14.5 GB of RAM.

## Done and verified
- `.mcp.json` points to `C:\Users\amine\jdbasic-native\jdBasic.exe` (Build 102).
- `track.jdb`: matches Python exactly on both tracks. Test: `tools/jd.sh run tests/track_check.jdb`.
- `env.jdb`: Python parity in both backends (max diff 5e-10). `python tests/env_parity.py [--native]`.
- `torch.jdb`: tape autograd, MLP, Adam, clip_grad_norm. All 20 ops pass gradcheck **interpreted and native**:
  `tools/jd.sh run|native tests/torch_gradcheck.jdb`.

## How to write code that survives -c (all verified)
- Declare every parameter that takes an array or map `AS ARRAY` / `AS MAP`, and every FUNC that returns one
  `AS ARRAY` / `AS MAP` (`AS INTEGER` / `AS DOUBLE` for numbers). Untyped means "number" under -c.
- A builtin that has scalar and array forms (`CLAMP`, `ABS`, `FLOOR`, `INT`, comparisons) must land in a local
  declared `DIM x AS ARRAY = ...`. Re-assigning `x = FLOOR(arr)` does not compile, and `CLAMP(...) * k` inline gives a scalar.
- Never `ZEROS([r, c])` / `ONES([r, c])` with many rows: use `TORCH.ZEROS_RC` / `ONES_RC` (flat + RESHAPE).
- Never grow a big string with `s$ = s$ + ...`: append blocks to the file with `TXTWRITER f$, block$, TRUE`.

## Native compiler bugs found (for COMPARISON.md)
1. An untyped FUNC parameter that receives an array reads as 0, `[[]]`, or a corrupt shape (`MATMUL: incompatible dimensions`),
   depending on how it is used. Root cause of the earlier "ADDROW gradient is empty".
2. A FUNC without `AS ARRAY` that returns `CLAMP(array, lo, hi)` returns 0; `CLAMP(y, -1, 1)` inside a big SUB returned `[]`.
3. `ZEROS([r, c])` / `ONES([r, c])` use memory quadratic in r: 3000x8 = 38 MB, 6000x8 = 142 MB, 15000x8 > 800 MB,
   150000x8 = 14.5 GB. A flat `ZEROS([1200000])` is 13 MB and `RESHAPE` of it is fine.
4. String concatenation in a loop leaks every temporary: a 1 MB CSV built with `out$ = out$ + line$` needs > 1 GB.
5. Implicit broadcasting: `[N,k] op [k]` segfaults; `[N,k] op [[1,k]]` silently returns one row.
6. A local declared `DIM x = 0` silently turns an array assigned to it into 0.
7. In a module, a Map value read into an untyped local never matches a `SWITCH CASE` (`IF` works).
8. `ONES([m{"r"}, m{"c"}])`, a shape built from Map values, crashes.
9. Every whole-array temporary (`MATMUL`, `a * b`, `TANH(a)`, `RESHAPE`, `DIM x AS ARRAY = expr` in a loop, even re-assignment `x = a * a`) is never freed: 200 x 100 doubles per op x 200 iterations = +160 MB. Scalar element loops over preallocated arrays (as `env.jdb`) do not leak. Repro: loop `DIM a AS ARRAY = x * x` with a 1000x100 `x`. Workaround: `BRAIN.FORWARD` and `NextGeneration` use scalar loops writing into buffers made once per generation. Whole-array math is fine only for one-off (per generation or per program) work.
   Still present on upstream main 70c1b7b0 (Oct 23, includes the refcount rework 8a2a245b), measured on the Linux build: same 175 MB peak for 200 x `x * x`, `MATMUL`, `TANH`, `RESHAPE`, 512 MB for `TANH(MATMUL(x, w)) + x`; `JDB_RC_OFF=1` changes nothing (#35).
- Interpreter: `IIF` on 2D arrays is broken. Library: `RAND.DRAWS(gen,"normal",n)` returns zeros (σ defaults to 0).

## Library audit (issue #31, `docs/LIBRARY_AUDIT.md`)
Adopt: `rand`, `stats`, `cli` (main flags), `testkit` (tests; done in torch_gradcheck), `svg` (plot_curves), `img` (GUI track PNG),
`df` + `console` (tables), `logger` (training logs), `pool` (parallel bench seeds, `-c` only). Not needed: ml, metrics, fit, conf, yaml and the rest.
All probed libs compile and run under `-c` when handles are typed (`DIM lg AS MAP = LOGGER.NEW(..)`). Lib / -c problems found:
10. `RAND.DRAWS` p1/p2 default to 0 (rand.jdb:299-333): normal has sigma 0 (#17, known).
11. `TESTKIT.EQARRAY` on 2-D arrays is always false under `-c` (testkit.jdb:100-107): flatten with `RESHAPE` first (#36).
12. `NOW_EPOCH()` has whole-second resolution under `-c` (affects logger.jdb:124, dt.jdb:141): use `TICK()` for durations (#37).
13. Interpreter: an `ASYNC FUNC` sees module CONSTs/globals as 0, so `POOL` workers that call ENV/TRACK only work under `-c` (#38).
14. `DF.WRITECSV` / `CSVWRITER` writes 6 significant digits (df.jdb:625): keep our `FORMAT$("{:.17g}")` writers for parity traces (#39).

## Evolution
`tools/jd.sh native tests/evo_smoke.jdb 20`: about 5.2 s/generation (200 cars, 900 ticks), peak 63 MB, flat. Best car passes a full lap (3186 px)
by gen 14-20, mean 683 at gen 20. Interpreted: about 70 s/generation, 2 generations suffice as a check.

## RL (rl_common.jdb, reinforce.jdb)
`tools/jd.sh native tests/reinforce_smoke.jdb 60`: about 5.9 s/iteration (200 cars, 128 ticks + update), peak 77 MB, flat (58 MB after 3 iterations).
Mean distance passes half a lap (1593 px) at iteration 38; iteration 60: best 5571 px (1.75 laps), mean 4088 px. Interpreted: about 14.5 s/iteration, peak 460 MB.
Because of bug 9 the compiled path does not use the TORCH tape: acting and the REINFORCE gradient run as scalar loops over flat preallocated
arrays (`RL_COMMON.LOOP_NEW/LOOP_FWD/LOOP_BWD`); the interpreter uses the tape. `tests/reinforce_grad.jdb` checks both give the same loss and
gradients (max diff 7e-17, both backends). The vector `MATMUL` is also slow under -c (about 40 MFlop/s; `hTh` of 25600x32 takes 1.8 s).
The tape update alone leaks about 250 MB per iteration natively (1 GB cap after 3 iterations).

## PPO (ppo.jdb)
`tools/jd.sh native tests/ppo_smoke.jdb 50`: about 34 s/iteration (200 cars, 128 ticks, then 4 epochs x 13 minibatches of 2048), peak 39 MB after 5 iterations,
84 MB after 50 (a creep of about 1 MB/iteration from small string temporaries such as `"gw" + STR$(l)` map keys, not the array leak of bug 9).
Mean distance passes half a lap (1593 px) at iteration 11; iteration 50: best 5667 px (1.78 laps), mean 5613 px (Python: ~5664 / 5699 after 60).
Interpreted: about 42 s/iteration. Same two paths as REINFORCE: tape (`GradsTape`) in the interpreter, scalar loops (`GradsLoop`, `LoopStep` = grad clip 0.5 over all
params + Adam, in place, no arrays) under -c. `tests/ppo_grad.jdb`: loss, gradients (clipped + tie samples), grad norm and the clip + Adam step agree to 3e-16 in both backends.
Under -c about 80% of the time is the 52 minibatch updates: compiled scalar loops run ~30 M multiply-adds/s (about 10 ns per array access, whatever the indexing or unrolling).
`RL_COMMON` additions: `LOOP_GRADS` (flat gradients, no PUTGRAD), `PERMUTE` (Fisher-Yates; `GRADE(RNG.FILL)` allocates n-sized temporaries).
Note: the builtin `STDEV` (used by `RL_COMMON.NORMALIZE_COL`) is the population std per the library audit, not unbiased as its comment says (relative diff 1/(2n), harmless at n = 25600); PPO computes the unbiased std itself.

## DQN (dqn.jdb)
`tools/jd.sh native tests/dqn_smoke.jdb 3`: about 75-96 s/iteration (200 cars, 128 ticks, 256 learn steps of batch 512), peak 65 MB, flat. Interpreted: about 82 s/iteration,
peak 129 MB, same numbers (3 iterations: best 424/384/504 px, loss 0.229/0.157/0.146, identical in both backends). Learning quality is not yet measured (needs hundreds of iterations at this speed, see #46).
Like REINFORCE, the compiled path runs forward, target forward, gradients, clip, Adam and polyak as scalar loops over flat arrays (no array temporaries); the interpreter uses the tape.
`tests/dqn_grad.jdb` checks both give the same loss and gradients (max diff 1.4e-17, both backends). The replay buffer is flat 1-D arrays (150000 transitions).
`TORCH.SAVE_JSON$` / `LOAD_JSON` now use flat number lists (nested JSON arrays are unusable under -c, #45): save and load work interpreted and native (`tests/torch_json.jdb`, DQN/PPO/REINFORCE smoke tests load natively). Brains saved in the old nested format do not load any more. `JSON.STRINGIFY$` keeps about 7 significant digits.

## trainer.jdb + main.jdb (issue #24)
`trainer.jdb` = `make_trainer` (NEW/ADVANCE/LEADER/ACTS/SAVE_JSON$/LOAD_JSON, IF dispatch on `t{"mode"}`). `main.jdb` parses flags with `lib/cli.jdb`
(`--mode --cars --track --max-steps --headless --gens --shot --shot-gen --record --record-from --record-frames --record-stride`; `--device` accepted and ignored).
Headless prints Python's line via `RL_COMMON.HEADLINE$`. Without `--headless` it opens the GUI (see below).
`tools/jd.sh native main.jdb --headless --mode evolution --gens 3`: 5.6-6.0 s/generation, peak 83 MB. REINFORCE 5.4 s/iteration, peak 82 MB. Test: `tests/main_smoke.sh [native]`.

## CI (issue #43)
The runner image builds jdBasic from upstream source on Linux (g++, LLVM 18, no Wine; pinned commit, see `ci/README.md`). The `jdbasic` job runs torch_gradcheck, track_check, reinforce_grad (interpreter and `-c`), env_parity and brain_parity (both backends); results equal the Windows build (parity diffs 2.2e-16, gradcheck 20/20). The old Wine job is gone.
## README GIFs (issue #49: `lib/gif.jdb`, `record.jdb`)
`lib/gif.jdb`: GIF89a writer (`GIF.WRITE(path$, frames, delay_ms)` for IMG-style frames, `GIF.WRITEINDEXED` for palette-index frames) plus `GIF.DECODE/READ` for tests. LZW uses a flat-array trie (no map lookups), global palette (exact if <= 256 colors, else a 6x7x6 cube), NETSCAPE loop. `tests/gif_selftest.jdb` (TESTKIT, 17 checks) passes interpreted and -c; the output also decodes in Pillow. The IMPORT path: `tools/jd.sh` sets `JDBASIC_PATH` to the repo's `lib/`.
`record.jdb <algo> <iters> <snapshots> [cars] [stride] [out]` trains one algorithm and films chosen iterations (250x215 frames drawn as palette indices). Native, one GIF each: evolution 120 cars 20 gens 76 s, 240 frames, 529 KB, peak 83 MB (cap peak 499 MB incl. frames); REINFORCE 80 cars 30 iters 80 s, 128 frames, 301 KB; PPO 80 cars 12 iters 168 s, 96 frames, 216 KB; DQN 80 cars 8 iters 608 s, 96 frames, 211 KB. Interpreted GIF.ENCODE of 3k pixels takes ~50 ms; the record path was only run native.
Observed: `UNIQUE` is quadratic in the number of distinct values (8 s for 6k values), so the quantiser sorts with `GRADE` instead. `MAX(a, b)` is not a two-value max (use `MAX([a, b])`).

## Work tracking
Everything open is a GitHub issue: https://github.com/AmineChr54/RL-autonomous-racing-jdBASIC/issues
(#26 plot_curves, #27 bench, #28 PyTorch cross-check, #29 COMPARISON.md).
Done work and the jdBasic bugs above are closed issues #1-#18.

## GUI (gui.jdb + main.jdb, issue #25)
1400x700 window, layout/colours/fonts (Consolas 16/13/22 bold) copied from main.py run_gui. Road pre-rendered once (`GUI.TRACK_PIXELS` -> `IMG.WRITEPNG` ->
`cache/track_<name>.png`), then `GFX.LOADIMAGE`/`DRAWIMAGE` per frame. Cars are filled quads = 8 parallel lines each, the swarm in ONE `LINE` matrix call with a
colour row per line (matrices preallocated, refilled by element: no leak). Leader rays + circle, panel, best/mean curve with lap lines, brain visualiser, flash text.
Keys (`ON "KEYDOWN"`, keycodes): 1-4 mode, +/- speed, F turbo, S/L save/load `saves/<mode>.json`, R restart, Esc/close quit (G, B not applicable).
`--shot path.png --shot-gen N` (draws only after generation N, saves when a car has run 220 ticks) and `--record DIR` (`frame_NNNN.png`, `--record-from/-frames/-stride`).
Works interpreted and `-c`. Screenshot (evolution, gen 13): `assets/shot.png`; `tools/jd.sh native main.jdb --shot assets/shot.png --shot-gen 12` takes about 1 min.
Test without a window: `python tests/gui_pixels.py [--native]` (pre-rendered road vs numpy, exact up to the start line); the GUI itself is not in CI (needs a display).
GFX notes: `LINE matrix, colours` needs an Nx3 colour matrix (inline r,g,b are ignored in the matrix form); `EXIT SUB` is a parse error (use RETURN); identifiers are
case-insensitive, `W` and `w` collided in a loop; no hidden-window mode, so `--shot` / `--record` still open a window; no resize, so frames are 1400x700.

## Bench (issue #27, `bench.jdb`, jdBasic Build 102, 200 cars, hard track, ms per call)
| op | interpreted | native -c | speedup |
|---|---|---|---|
| BRAIN.FORWARD | 16.9 | 2.10 | 8x |
| ENV.RAY_DISTANCES | 31.1 | 1.19 | 26x |
| ENV.TICK (full) | 34.9 | 1.32 | 26x |
| EVOLUTION.ADVANCE (1 tick) | 50.2 | 3.33 | 15x |
Run: `tools/jd.sh run bench.jdb 3 interp` / `tools/jd.sh native bench.jdb 20 native`; writes `assets/bench_<mode>.json`. Per-iteration training times are in the smoke-test sections (evolution 5.2 s/gen, REINFORCE 5.9 s/iter native; DQN ~80 s/iter, #46).

## Parallel seeds (issue #54, `par_seeds.jdb`, native only)
`tools/jd.sh native par_seeds.jdb evolution 2 8`: one ASYNC worker (OS thread) per seed through `lib/pool.jdb`, each with its own track and env.
- evolution, REINFORCE: correct. Seed 0 on 4 threads equals the single-process result exactly (159.35786). 8 seeds in 14 s vs 7 s for one (about 4x throughput), peak 293 MB.
- PPO, DQN: with workers started at the same moment they fail (random "Array index out of bounds" / "MATMUL: incompatible dimensions"). `TRAINER.NEW` registers the TORCH params in module globals (`gPVal`, `gPCount`, ...), which the threads share under -c. Workaround in `par_seeds.jdb`: `STAGGER_MS` (6 s) between worker starts. With it 8 PPO seeds x 30 iterations ran clean, seed 0 identical to the single run, 1224 s (3.3x), peak 499 MB. DQN not tried in parallel yet. A real fix would make the param store per-worker.
- In `par_seeds.jdb` a string worker parameter (`mode$`, passed through `POOL.SPAWN`) arrived null under -c, so the mode is passed as a number. A plain `ASYNC FUNC W(s$)` called with a string variable works in both backends (re-checked), so the cause is not isolated.

- Interpreter (Build 102): `INSTR(h$, n$)` returns a 0-based index (-1 if absent) and `MID$(s$, start, len)` takes a 0-based start. Found while drawing the pixel font in `pitch.jdb`.
- `pitch.jdb` natively compiled ran into the 1.5 GB cap (bug 9, array temporaries); the interpreter needs 1.4 GB peak for 124 frames of 500 x 470 and takes about 1 min.

## DQN speed: what was tried (issue #46, 2026-10-28, native Build 102)
One layer forward, 512 rows x 64 -> 64 (2.1 M multiply-adds): scalar loop 28.6 ms (13.6 ns per MAC); reordered so weights are read contiguously 30.1 ms; unrolled x4 37.5 ms (slower); `TANH(MATMUL(x, w))` 13.9 ms (6.6 ns per MAC) and it leaks about 0.5 MB per call (200 calls: +127 MB).
So source-level loop tuning does not help, and even a leak-free `MATMUL` would be only about 2x faster here: the native array kernels run at roughly 7-14 ns per multiply-add. A 45 s DQN iteration (256 learn steps) can only get big wins from a faster array/loop code generator upstream (compare: plain C would be about 1 ns per MAC).

## torch.jdb vs real PyTorch (issue #28, `tests/torch_vs_pytorch.py`)
Formula-defined weights, an 8-16-16-2 MLP with MSE and an 8-16-16-5 MLP with GATHERCOL + SMOOTH_L1 (the DQN loss): forward output, loss, every parameter gradient and one Adam step agree with PyTorch 2.9.1 (float64) to 1e-16, interpreted and native (tolerance 1e-9). `python tests/torch_vs_pytorch.py [--native]`; skips with a message when torch is missing (CI).

Note on timings: absolute milliseconds vary by about 40% with machine load (a later `tools/demo.sh quick` measured native env tick 0.80 ms and interpreted 19.8 ms, against 1.32 / 34.9 in the Bench table above); the speedup ratios stay the same (about 25x for the env tick, 8x brain, 15x evolution tick). Compare runs only on the same quiet machine.
- `train_general.jdb` -c exit 139 was #45: an array from `JSON.PARSE$` segfaults when used under -c. Workaround (now in the script): copy the numbers into a fresh `ZEROS` array (`LoadGenome`). The native and interpreted comparison now print identical numbers.
