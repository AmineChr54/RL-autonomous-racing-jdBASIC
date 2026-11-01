# How to extend the project

Always run jdBasic through `tools/jd.sh` (hard memory cap) and load the rules in `STATUS.md` ("How to write code that survives `-c`")
before writing `.jdb`. Every recipe below ends with the commands that prove it works.

## Add a track

`track.jdb` builds a track from closed control points (`ControlPoints(name$)`), a road width (`RoadWidth(name$)`) and a Catmull-Rom spline.

1. Add a branch for your name in `ControlPoints` (flat x, y pairs inside the 1000 x 700 world, closed loop) and in `RoadWidth`.
2. Allow the name in `main.jdb` (`--track` choices) and, if you want, in `playable.jdb`.
3. Check: `tools/jd.sh run tests/track_check.jdb` (point count, lap length, road pixels) and look at it with
   `tools/jd.sh run main.jdb --track <name> --shot assets/shot.png --gens 1`.

Brains evolved on one track do not drive another (`docs/ANALYSIS.md`, section 7), so retrain with `train_brain.jdb` if you want opponents for it.

## Add a learner

A learner is a module `X` with `NEW(e AS MAP, seed)`, `ADVANCE(t AS MAP) AS INTEGER` (1 when an iteration just finished),
`LEADER(t)`, `ACTS(t, i)`, `SAVE_JSON$(t)` and `LOAD_JSON(t, text$)`; its trainer map carries `mode`, `name`, `env`, `generation`,
`hist_best`, `hist_mean`. `reinforce.jdb` is the smallest example; `rl_common.jdb` has rollout buffers and the scalar-loop forward
and backward passes.

1. Write `x.jdb` following `reinforce.jdb`. Parameters that hold arrays or maps are declared `AS ARRAY` / `AS MAP`, functions
   `AS ...`; do not use array maths in the hot loop of the compiled path (whole-array temporaries are never freed, `STATUS.md` bug 9).
2. Register it in `trainer.jdb` (`VALID_MODE`, `NEW`, `ADVANCE`, `LEADER`, `ACTS`, `SAVE_JSON$`, `LOAD_JSON`: plain `IF` on the mode string).
3. Add a smoke test like `tests/reinforce_smoke.jdb` and, if the learner has two code paths, a gradient test like `tests/reinforce_grad.jdb`.
4. Check: `tools/jd.sh run|native tests/x_smoke.jdb 3`, then `tests/leak_check.sh tests/x_smoke.jdb 2 6` (peak memory must stay flat).

## Add a test

* A jdBasic test prints `PASS` or `END 1`; put it in `tests/`, run it interpreted and native, and add a step to the `jdbasic` job in
  `.github/workflows/ci.yml` (copy the `torch_json` step). The runner builds jdBasic from upstream source (`ci/`), so a test must
  not need the GFX window.
* A Python parity test imports the original from `$PY_PROJECT` (see `tests/env_parity.py`, `tests/torch_vs_pytorch.py`) and calls
  `tools/jd.run("tests/x.jdb", native=...)`.
* Files committed from Windows lose the executable bit: `git update-index --chmod=+x tests/x.sh`.

## Train, race and record

| Goal | Command |
|---|---|
| train headless | `tools/jd.sh native main.jdb --headless --mode ppo --gens 30` |
| many seeds at once | `tools/jd.sh native par_seeds.jdb ppo 30 8` (staggered starts; mind the memory) |
| retrain the opponents | `tools/jd.sh native train_brain.jdb 25` |
| play | `tools/jd.sh run playable.jdb [easy\|hard]` |
| film a training | `JD_MEM=1500 tools/jd.sh native record.jdb reinforce 30 1,10,20,last 80 4` |
| pitch GIF | `JD_MEM=1600 tools/jd.sh run pitch.jdb` |
| everything | `tools/demo.sh quick` or `full` |

## Rules of thumb

* One jdBasic process at a time; `JD_MEM` never above 2048 MB.
* Report a new jdBasic bug in `STATUS.md` (symptom, minimal repro, workaround) and, once confirmed, draft it in `docs/UPSTREAM_REPORTS.md`.
* Absolute timings move by about 40% with machine load; compare ratios, or runs on a quiet machine.
