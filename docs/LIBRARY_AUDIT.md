# jdBasic lib/ audit (issue #31)

Library: `C:\Users\amine\jdbasic-native\lib\` (55 modules), jdBasic v1.1 Build 102. Every module we might use was
probed with a tiny program that calls the functions we would use, run through `tools/jd.sh run` and
`tools/jd.sh native` (jdBasic `-c`), one process at a time, `CAPPED_PEAK=1`. Peak memory is `interpreted / compiled run`
(the compile step itself peaks at 14 to 106 MB). Probes live in `spikes/` (gitignored); the interesting repros are inline
in the linked bug issues.

Rule of thumb for calling libs under `-c`: **handles are Maps** (`LOGGER.NEW`, `CLI.NEW`, `CONSOLE.PROGRESS`, `IMG.*`
images, `DF` frames, `FIT.SPLINE`), so declare them `DIM lg AS MAP = ...` (`AS INTEGER` is a compile error);
`RAND.GENERATOR`, `METRICS.NEW*` and `SVG.CHART/NEW/RENDER` are integers. Results that are arrays go in `DIM x AS ARRAY`.
With that, every probed module compiled and ran with identical output in both backends, except the items under
"-c problems".

## Decisions

| Module | Gives us | Interp | -c | Peak MB (i / c) | Decision | Used by |
|---|---|---|---|---|---|---|
| `rand` | seeded generators, `INTRANGE`, `NORMAL`, `UNIFORM`, `PERMUTATION`, `SAMPLE`, `WEIGHTED` (same stream in both backends) | ok | ok | 12 / 3 | **adopt** (env.jdb already does). Do not use `DRAWS(..,"normal",n)` (#17) | env, DQN/PPO scalar draws |
| `stats` | `SD/VAR` (ddof 1 = `torch.std`), `ZSCORES(v, ddof)`, `DESCRIBE`, `QUANTILE`, `CORR`, `LINREGRESS`, `TTEST2`, `SEM`, `NORMCDF` | ok | ok | 12 / 3 | **adopt** (PPO advantage normalisation, bench/COMPARISON statistics) | #23, #27, #29 |
| `cli` | `NEW/FLAG/OPT/NUM/ARGV/PARSE/DONE/HELP$`, generated `--help`, errors like `--seed wants a number, got "x"` | ok | ok, argv passes through the .exe | 11 / 3 | **adopt** for `main.jdb` flags | #24 |
| `testkit` | `SUITE/EQ/NEAR/ISTRUE/EQARRAY/REPORT` (non-zero exit when red), TAP and JUnit output | ok | ok for scalars and 1-D arrays; `EQARRAY` on 2-D is wrong, `THROWS` is interpreter-only | 11 / 3 | **adopt** (done: `tests/torch_gradcheck.jdb`), flatten 2-D arrays before `EQARRAY` | all tests, CI #19 |
| `proptest` | `FORALL` property tests with seeds and shrinking | ok | ok (funcref property) | 13 / 4 | **adopt-with-wrapper** later: e.g. "BRAIN.FORWARD output within [-1,1]", "ENV.TICK never returns NaN" | future tests |
| `svg` | `CHART("line")` + `POINTS` / `SERIES`, `REFLINE`, `SETOPT colors`, `SPARKLINE$`, `WRITEFILE`; 4 KB for a 2-series line chart | ok | ok, same markup | 14 / 3 | **adopt** for `assets/curves.svg` | #26 |
| `img` | `FROMPIXELS` / `WRITEPNG` / `READPNG` / `RESIZE` / `DATAURI$`. 1000x700 RGB: 1.1 s + 4.9 s write interpreted, 0.1 s + 2.2 s compiled, peak 520 / 471 MB (one-off, cached to `cache/track_<name>.png`) | ok | ok (hold results in a variable before the next IMG call) | 76 / 30 (200x100) | **adopt** for the GUI track image; use `{"filter":"sub","level":1}` | #25 |
| `df` | `FROMCOLS`, `WITH`, `GROUPBY`, `SORT`, `DESCRIBE`, `READCSV`, `WRITECSV`, `SHOW` (console table) | ok | ok; writes a 6000x13 frame (844 KB) in 11 MB, no string leak | 12 / 3 | **adopt** for result tables (bench, plot_curves summary, COMPARISON data); **not** for numeric traces (CSVWRITER keeps only 6 significant digits, #39) | #27, #26, #29 |
| `console` | `TABLE$`, `KV`, `RULE`, `PANEL`, `PROGRESS` (+`ADVANCE`, `PROGRESS$`), `STYLE$` | ok | ok | 14 / 3 | **adopt-with-wrapper** for bench/summary output (`CONSOLE.PLAIN(TRUE)` for CI logs; the headless training line must stay the exact Python `f"..."` line, so use `FORMAT$`) | #24, #27 |
| `logger` | levels, console / text file / JSON-lines sinks with rotation, context map | ok | ok; `epoch` loses its fraction (#37) | 12 / 3 | **adopt** for training logs (`TO_JSONL` per generation: `{"gen","best","mean"}`) | #24, #26 |
| `metrics` | counters / gauges / histograms in Prometheus text format | ok | ok | 12 / 3 | **not needed** (nothing scrapes us; `LOGGER` + `DF` cover it) | |
| `dt` | `NOW`, `FMT$(t,"%Y%m%d-%H%M%S")`, `ISO$`, `ADD` | ok | ok; `NOW()` whole seconds (#37) | 14 / 3 | **adopt-with-wrapper**: run ids and file names only; use `TICK()` for elapsed time | #24, #27 |
| `textx` | `DURATION$`, `FILESIZE$`, `INTCOMMA$` | ok | ok | 14 / 3 | **not needed** (optional polish for bench tables) | |
| `fit` | `POLYFIT/POLYVAL`, `SPLINE`, `INTERP`, `CURVEFIT`, `LSTSQ` | ok | ok | 12 / 3 | **not needed** now (optional: `SVG.FITLINE(chart, name, FIT.POLYFIT(x, y, 1))` for a trend line) | |
| `conf` / `yaml` | TOML / dotenv / INI / YAML into maps, dotted `GET` | ok | ok | 12 / 3 | **not needed**: hyperparameters are constants that must match Python. If a `--config file.toml` flag is ever wanted, use `CONF.TOML` | |
| `pool` | `CREATE/SPAWN/GATHER/VALUES` over `ASYNC FUNC` workers; 4 env rollouts on 2 workers 0.58 s, peak 115 MB | worker that calls a stateful module fails (#38) | ok | 29 / 9 (squares), 70 / 115 (env) | **adopt-with-wrapper**, `-c` only: parallel seeds for bench / plot_curves. Each worker has its own copy of the globals, so return plain numbers only | #26, #27 |
| `ml` | train/test split, scalers, linear/ridge/logistic/knn/kmeans/tree, metrics (checked against scikit-learn) | ok | ok | 12 / 3 | **not needed**: no autodiff or neural nets; `torch.jdb` stays | |
| `cache`, `retry`, `sched`, `numfmt`, `struct`, `fuzzy`, `xlsx`, `md`, `search` | import-only probe | ok | ok | 20 / 3 | **not needed** | |
| the rest (`archive db docx fake graph htmldom i18n ical jdweb jwt llmapi mail money oauth parsec pdfgen pkg pptx qr req schema secret textdiff tmpl ttf url valid xml`) | web, documents, mail, auth, parsing: nothing in a headless RL demo | not probed | not probed | | **not needed** | |

## What we replaced (this PR)

- `tests/torch_gradcheck.jdb`: the hand-written PASS/FAIL printing and `END 1` are now `TESTKIT.SUITE` + one
  `TESTKIT.ISTRUE(worst <= 1e-4, name + detail)` per op + `TESTKIT.REPORT()` (non-zero exit when red, TAP/JUnit available for CI).
  20/20 ops pass, interpreted (84 ms) and `-c` (33 ms).

## What we looked at and deliberately kept

- `TORCH.RANDN/RANDU` (torch.jdb): vectorised on `RNG.FILL` into an `[n, k]` matrix. 100 000 normals: `TORCH.RANDN` 69 ms
  interpreted / 23 ms compiled, a `RAND.NORMAL` loop 205 / 60 ms; there is no matrix form in `rand`. Same formula as
  `RAND.NORMAL` (Box-Muller, one pair of uniforms per value).
- `TORCH.NROWS/NCOLS/ZEROS_RC/ONES_RC/REPROW`: no lib equivalent (they work around `-c` bugs #10, #12).
- CSV writers in `tests/brain_check.jdb` / `tests/env_parity.jdb`: `DF.WRITECSV` writes 6 significant digits, parity needs 17 (#39).
- `RAND.SAMPLE(gen, list, k)` for a DQN minibatch: 40 ms interpreted / 2 ms compiled for 64 of 100 000, but it copies the list;
  prefer `INT(RNG.FILL(gen, 512) * size)` as the DQN issue plans.
- `RAND.PERMUTATION(gen, 100000)` 226 / 45 ms; PPO's `GRADE(RNG.FILL(gen, n))` is the vectorised alternative.

## -c problems and lib bugs found

| # | Where | What | Issue |
|---|---|---|---|
| 1 | `lib/rand.jdb:299-333` `DRAWS` | `p1 = 0, p2 = 0` defaults: `"normal"` has sigma 0 (all zeros), `exponential`/`gamma`/`beta` throw | #17 (already known) |
| 2 | `lib/testkit.jdb:100-107` `SameArray` | `EQARRAY` on a 2-D array is always false under `-c` (garbage in the failure detail); interpreted ok | #36 |
| 3 | `-c` builtin `NOW_EPOCH()` (used at `lib/logger.jdb:124`, `lib/dt.jdb:141,146-147`) | whole-second resolution compiled, microseconds interpreted | #37 |
| 4 | interpreter, `ASYNC FUNC` (affects `lib/pool.jdb`) | the worker sees module `CONST`s and globals as 0: `Division by zero` in every job; compiled ok | #38 |
| 5 | `lib/df.jdb:625` `WRITECSV` (`CSVWRITER` builtin) | numbers written with 6 significant digits, no precision option | #39 |
| 6 | `lib/testkit.jdb` `THROWS` | interpreter-only (documented in testkit_lib_readme.md) | known, documented |
| 7 | `lib/img.jdb` | an IMG call nested inside another IMG call (`IMG.COMPOSITE(IMG.TOCHANNELS(..), ..)`) can arrive empty compiled; hold in a variable (documented in img_lib_readme.md) | known, documented |

Observation, not filed: our own main programs reject `DIM i` (no type, no initialiser) under `-c` with
`STRICT: untyped DIM 'I' has no type and no initializer`, while the libs use exactly that and compile.
