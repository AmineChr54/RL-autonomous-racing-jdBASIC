# Local CI runner

`Dockerfile`: Ubuntu 24.04 + the official `actions/runner` tarball (pinned `RUNNER_VERSION`) + Wine 9.0 + xvfb + Python 3 with numpy and CPU torch (the Python original's `brain.py` imports torch). No third-party runner images.

- `start-runner.sh` builds the image and starts container `jdbasic-local` (`--restart unless-stopped`, `--memory 3g --memory-swap 3g --cpus 4`), mounting the Windows jdBasic install read-only at `/opt/jdbasic`. The registration token comes from `gh api` at start time and exists only in the container environment; the entrypoint unsets it after registering.
- `stop-runner.sh` removes the container and deregisters the runner.
- Labels: `self-hosted, linux, jdbasic`.

## Wine status

Finding: `wine64 /opt/jdbasic/jdBasic.exe <anything>` (Wine 9.0, Ubuntu 24.04, with xvfb, with `SDL_VIDEODRIVER=dummy`, fresh or initialised prefix) dies at startup with `Unhandled page fault on write access to 0000000000000000 at address 0000000140342ADC` inside jdBasic.exe itself, before any of its DLLs load. So the interpreter cannot run in the container for now. Workflow consequences:

- job `python-side` (required): clones the Python original and checks it imports, and that the test scripts compile.
- job `jdbasic-wine` (advisory, `continue-on-error`): runs `torch_gradcheck`, `track_check`, `env_parity`, `brain_parity` via `tools/jd.sh` / `tools/jd.py`, which use `wine` on Linux. It will start passing if Wine is fixed (newer WineHQ build, different prefix settings); then make it required.
- Native `-c` builds need MSVC and stay local: `tools/jd.sh native`.
