# Local CI runner

`Dockerfile` (two stages):

1. `jdbasic-build`: Ubuntu 24.04, clones https://github.com/AtomiJD/jdBasic at the pinned commit `JDBASIC_REF` (default `70c1b7b0`, upstream main of 2026-10-23, which contains the `-c` refcount rework 8a2a245b) and builds it with plain g++ via upstream `build.sh`: `HTTP=0 GFX=0 NATIVEC=1` (interpreter plus the LLVM 18 backend behind `jdbasic -c`; no SDL, HTTP, ImGui). About 6-8 minutes with 4 jobs, peak well under 6 GB. Output: `/opt/jdbasic/build/jdbasic`, `libjdbrt.so`, `jdb_runtime.o`, `/opt/jdbasic/lib`, `/opt/jdbasic/REF` (commit + subject).
2. The runner image: Ubuntu 24.04 + the official `actions/runner` tarball (pinned `RUNNER_VERSION`) + Python 3 with numpy and CPU torch (the Python original's `brain.py` imports torch) + g++/llvm-18-dev (needed by `jdbasic -c`) + the jdBasic build copied from stage 1. No third-party runner images, no Wine.

- `start-runner.sh` builds the image under `docker build --memory 6g --memory-swap 6g` and starts container `jdbasic-local` (`--restart unless-stopped`, `--memory 3g --memory-swap 3g --cpus 4`). The registration token comes from `gh api` at start time and exists only in the container environment; the entrypoint unsets it after registering. `JDBASIC_REF=<sha> ci/start-runner.sh` rebuilds with another upstream commit.
- `stop-runner.sh` removes the container and deregisters the runner.
- Labels: `self-hosted, linux, jdbasic`. Swap the container only when no job runs (`gh run list`).

## Workflow jobs

- `python-side` (required): the Python original imports; the test scripts compile.
- `jdbasic` (required): `torch_gradcheck`, `track_check`, `reinforce_grad` (interpreter and `-c` native), `env_parity` and `brain_parity` (`python tests/*.py` and `--native`), through `tools/jd.sh` / `tools/jd.py`. On Linux they run the native binary under `timeout`; the container's `--memory` is the hard memory cap.

## History / findings

- Wine did not work: `wine64 jdBasic.exe <anything>` (Wine 9.0, Ubuntu 24.04) dies at startup with `Unhandled page fault on write access to 0000000000000000 at address 0000000140342ADC` inside jdBasic.exe. The Linux source build replaces it (#43).
- The Linux build gives the same numbers as the Windows build: gradcheck errors are around 1e-10, track_check output is identical, env_parity and brain_parity PASS (max diff 2.2e-16) in both backends, and the LLVM `-c` backend works on Linux (ELF binary written as `<name>.exe`). `-c` of a program needs about 100-200 MB and a few seconds.
- Leak #35 (whole-array temporaries under `-c`) is NOT fixed on upstream main 70c1b7b0: see the measurement in issue #35.
