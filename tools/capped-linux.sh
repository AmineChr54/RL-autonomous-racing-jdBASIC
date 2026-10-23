#!/usr/bin/env bash
# Linux stand-in for capped.exe: capped-linux.sh MEM_MB TIME_S cmd args...
# Wall clock via timeout; memory is capped by the container's --memory/--memory-swap (MEM_MB is informational).
# jdBasic is a native Linux binary here (ci/Dockerfile), no Wine.
t="$2"; shift 2
exec timeout "$t" "$@"
