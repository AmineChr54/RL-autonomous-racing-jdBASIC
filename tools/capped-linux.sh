#!/usr/bin/env bash
# Linux stand-in for capped.exe: capped-linux.sh MEM_MB TIME_S cmd args...
# Wall clock via timeout; memory is capped by the container's --memory/--memory-swap (MEM_MB is informational).
# jdBasic is a native Linux binary here (ci/Dockerfile), no Wine.
# CAPPED_PEAK=1 prints "capped: peak N MB" (max RSS of the command) on stderr, like capped.exe, for tests/leak_check.sh.
t="$2"; shift 2
if [ "${CAPPED_PEAK:-}" = 1 ]; then
  exec python3 - "$t" "$@" <<'PY'
import resource, subprocess, sys
t, cmd = float(sys.argv[1]), sys.argv[2:]
try:
    rc = subprocess.run(cmd, timeout=t).returncode
except subprocess.TimeoutExpired:
    rc = 124
peak = resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss // 1024   # KiB -> MB
sys.stderr.write("capped: peak %d MB\n" % peak)
sys.exit(rc)
PY
fi
exec timeout "$t" "$@"
