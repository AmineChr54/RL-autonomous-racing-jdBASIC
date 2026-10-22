#!/usr/bin/env bash
# Linux stand-in for capped.exe: capped-linux.sh MEM_MB TIME_S cmd args...
# Wall clock via timeout; memory is capped by the container's --memory/--memory-swap (MEM_MB is informational).
t="$2"; shift 2
if command -v xvfb-run >/dev/null; then exec timeout "$t" xvfb-run -a wine "$@"; fi
exec timeout "$t" wine "$@"
