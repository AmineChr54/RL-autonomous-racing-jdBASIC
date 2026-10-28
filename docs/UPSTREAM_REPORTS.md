# Draft bug reports for AtomiJD/jdBasic (not posted; issue #32)

Found on Build 102 (Windows x64), several also on upstream main 70c1b7b0 (Linux build). Re-verify on the new release before posting.

## 1. `-c`: whole-array temporaries are never freed (re-verified 2026-10-28)
```basic
DIM x AS ARRAY = RESHAPE(ONES([100000]), [1000, 100])
DIM a AS ARRAY = x * x
DIM i AS INTEGER = 0
FOR i = 1 TO 200
    a = x * x
NEXT i
PRINT SUM(a)
```
Interpreter: flat. `jdBasic -c`: peak 177 MB for 200 iterations (about 0.8 MB, one array, per `x * x`); it grows linearly with the loop count.
Same for `MATMUL`, `TANH`, `RESHAPE`. `JD_RC_OFF=1` changes nothing. Impact: training loops cannot use array maths (we wrote scalar loops, about 1000 extra lines).

## 2. `-c`: `ZEROS([r, c])` / `ONES([r, c])` memory is quadratic in r
3000x8 = 38 MB, 6000x8 = 142 MB, 15000x8 > 800 MB, 150000x8 = 14.5 GB. `ZEROS([1200000])` is 13 MB and `RESHAPE` of it is fine.

## 3. `-c`: untyped `FUNC`/`SUB` parameter that receives an array is a number
Reads as 0, `[[]]`, or a corrupt shape (`MATMUL: incompatible dimensions`); only `p AS ARRAY` works. A compile-time error or a warning would save hours.

## 4. `-c`: string concatenation in a loop leaks every temporary
A 1 MB CSV built with `out$ = out$ + line$` needs more than 1 GB.

## 5. `-c`: broadcasting `[N,k] op [k]` segfaults; `[N,k] op [[1,k]]` silently returns one row
The interpreter broadcasts the row correctly (and column broadcast `[N,k]*[N,1]` there gives garbage).

## 6. Smaller
- `DIM x = 0` is an INTEGER forever under `-c`; assigning an array to it turns it into 0.
- A map value in an untyped local never matches `SWITCH CASE` in a module (`IF` works).
- `RAND.DRAWS(gen, "normal", n)` returns zeros (sigma defaults to 0).
- `TESTKIT.EQARRAY` on 2-D arrays is always false under `-c`; `NOW_EPOCH()` has whole-second resolution under `-c`.
- `TORCH`-style code: `ASYNC FUNC` workers that use one module's global tape race with each other (PPO/DQN fail with more than one worker, evolution/REINFORCE are fine).
- Build 102 has `OS.FEATURE("OPENGL")` FALSE; `GL.*` has no compute shaders or read-back, so the iGPU cannot be used for simulation.
