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
- Interpreter: `IIF` on 2D arrays is broken. Library: `RAND.DRAWS(gen,"normal",n)` returns zeros (σ defaults to 0).

## Library audit (issue #31, `docs/LIBRARY_AUDIT.md`)
Adopt: `rand`, `stats`, `cli` (main flags), `testkit` (tests; done in torch_gradcheck), `svg` (plot_curves), `img` (GUI track PNG),
`df` + `console` (tables), `logger` (training logs), `pool` (parallel bench seeds, `-c` only). Not needed: ml, metrics, fit, conf, yaml and the rest.
All probed libs compile and run under `-c` when handles are typed (`DIM lg AS MAP = LOGGER.NEW(..)`). Lib / -c problems found:
9. `RAND.DRAWS` p1/p2 default to 0 (rand.jdb:299-333): normal has sigma 0 (#17, known).
10. `TESTKIT.EQARRAY` on 2-D arrays is always false under `-c` (testkit.jdb:100-107): flatten with `RESHAPE` first (#36).
11. `NOW_EPOCH()` has whole-second resolution under `-c` (affects logger.jdb:124, dt.jdb:141): use `TICK()` for durations (#37).
12. Interpreter: an `ASYNC FUNC` sees module CONSTs/globals as 0, so `POOL` workers that call ENV/TRACK only work under `-c` (#38).
13. `DF.WRITECSV` / `CSVWRITER` writes 6 significant digits (df.jdb:625): keep our `FORMAT$("{:.17g}")` writers for parity traces (#39).

## Work tracking
Everything open is a GitHub issue: https://github.com/AmineChr54/RL-autonomous-racing-jdBASIC/issues
(#19 local CI, #20 evolution under -c, #21 REINFORCE, #22 DQN, #23 PPO, #24 trainer + headless main,
#25 GUI, #26 plot_curves, #27 bench, #28 PyTorch cross-check, #29 COMPARISON.md).
Done work and the jdBasic bugs above are closed issues #1-#18.
