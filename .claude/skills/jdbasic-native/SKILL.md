---
name: jdbasic-native
description: How to write, run and test jdBasic code in this repo so it works interpreted AND compiled with -c, without eating the machine's RAM. Load before writing or running any .jdb file here.
---

# Writing and running jdBasic in this repo

jdBasic: `C:\Users\amine\jdbasic-native\jdBasic.exe` (v1.1 Build 102). Docs: `C:\Users\amine\jdbasic-native\doc\languages.md`
(grep it, it is 5000 lines). Library modules: `C:\Users\amine\jdbasic-native\lib\`.
The Python original is `D:\Projects\RL-autonomous-racing` (read-only reference; every constant must match it).

## NEVER run jdBasic or a compiled .exe without the memory cap

An uncapped native test once allocated 14.5 GB and nearly crashed the user's PC. Always:

```bash
tools/jd.sh run    file.jdb [args]   # interpreter
tools/jd.sh native file.jdb [args]   # jdBasic -c, then run the .exe
tools/jd.sh build  file.jdb          # compile only
```
`JD_MEM=<MB>` (default 1024) and `JD_TIME=<s>` (default 600) override the caps; `CAPPED_PEAK=1` prints peak memory.
Python tests use `tools/jd.py` (`jd.run(src, native=...)`). Never raise JD_MEM above 2048.
Run at most ONE jdBasic process at a time: other agents share this machine (16 GB) and each run may take up to its cap.

## Rules for code that also compiles with -c (each one was a real bug)

- Every parameter that receives an array or map: `p AS ARRAY` / `p AS MAP`. Untyped = number under -c
  (symptoms: value reads as 0, `[[]]`, `MATMUL: incompatible dimensions`, segfault).
- Every FUNC that returns an array/map/number: `FUNC F(...) AS ARRAY` / `AS MAP` / `AS INTEGER` / `AS DOUBLE`.
- Locals that hold arrays/maps read from a map: `DIM xs AS ARRAY = e{"x"}`, `DIM tr AS MAP = e{"track"}`.
- Builtins with scalar+array forms (`CLAMP`, `ABS`, `FLOOR`, `INT`, `<`, `>`) must land in `DIM x AS ARRAY = ...`.
  `x = FLOOR(arr)` (re-assignment) does not compile; `CLAMP(a, lo, hi) * k` inline is treated as a scalar.
- NEVER `ZEROS([r, c])` / `ONES([r, c])` 2-D with many rows (memory is quadratic in rows under -c: 15000x8 > 800 MB).
  Use `TORCH.ZEROS_RC(r, c)` / `TORCH.ONES_RC(r, c)` (flat + RESHAPE). 1-D `ZEROS([n])` is fine.
- NEVER build a big string with `s$ = s$ + ...` in a loop (every temporary leaks under -c). Append small blocks with
  `TXTWRITER path$, block$, TRUE`.
- No implicit broadcasting (`[N,k] + [k]` segfaults natively, `[N,k] + [[1,k]]` returns one row):
  use `TORCH.REPROW(row1xk, n)` / `MATMUL(col, TORCH.ONES_RC(1, k))`.
- A local `DIM x = 0` is an INTEGER forever; an array assigned to it becomes 0. Declare types up front.
- Read map values into typed locals before `SWITCH` (`DIM op AS INTEGER = CINT(nd{"op"})`).
- Identifiers are case-insensitive (`genome` param vs `GENOME` const is an error). `STEP` is reserved (use ADVANCE).
  `EXITFOR` / `EXITDO` are one word. `IOTA(n)` is 1-based. `TICK()` is ms since start. `OS.ARGS()` gives argv.
- `M[idx_vec]` gathers rows, `v[idx_vec]` gathers elements (fractional indices truncate). `GRADE` = argsort ascending.
- Randomness: `RNG.NEW(seed)`, `RNG.NEXT`, `RNG.INT(h, lo, hi)`, `RNG.FILL(h, n)`; `TORCH.RANDN/RANDU(gen, r, c)`.
  `RAND.DRAWS(gen, "normal", n)` returns zeros (sigma defaults to 0) - don't use it.
- `IMPORT X` finds `x.jdb` in the script's folder, then the working dir: run tests from the repo root.

## Tests that must stay green

```bash
tools/jd.sh run tests/torch_gradcheck.jdb && tools/jd.sh native tests/torch_gradcheck.jdb
python tests/env_parity.py && python tests/env_parity.py --native
python tests/brain_parity.py && python tests/brain_parity.py --native
```
When you find a new jdBasic bug, add it (symptom, minimal repro, workaround) to the bug list in STATUS.md.
