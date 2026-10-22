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

## In progress / not started
brain, evolution, rl_common, reinforce, dqn, ppo, main (GUI and headless), plot_curves, bench, the PyTorch
cross-check, README.md, COMPARISON.md.
