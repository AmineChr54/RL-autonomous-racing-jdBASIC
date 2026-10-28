#!/usr/bin/env bash
# Leak regression: peak memory must stay flat when a training run is 3x longer.
#   tests/leak_check.sh [smoke_test.jdb] [short_iters] [long_iters]     (native -c, hard memory cap)
# Fails when peak(long) > 1.25 * peak(short) + 30 MB. Covers STATUS.md bug 9 (whole-array temporaries never freed).
set -e
cd "$(dirname "$0")/.."
T="${1:-tests/evo_smoke.jdb}"; A="${2:-2}"; B="${3:-6}"
export CAPPED_PEAK=1 JD_MEM="${JD_MEM:-768}" JD_TIME="${JD_TIME:-900}"
peak() { tools/jd.sh native "$T" "$1" 2>&1 >/dev/null | sed -n 's/.*capped: peak \([0-9]*\) MB.*/\1/p' | tail -1; }
pa=$(peak "$A"); pb=$(peak "$B")
echo "$T: peak $pa MB at $A iterations, $pb MB at $B iterations"
[ -n "$pa" ] && [ -n "$pb" ] || { echo "no peak reported"; exit 2; }
limit=$(( pa * 125 / 100 + 30 ))
if [ "$pb" -gt "$limit" ]; then echo "LEAK: $pb MB > limit $limit MB"; exit 1; fi
echo "ok (limit $limit MB)"
