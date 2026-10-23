#!/usr/bin/env bash
# main.jdb smoke test: every mode runs headless for one generation/iteration (small swarm) and prints Python's line format.
#   tests/main_smoke.sh            interpreter, all four modes
#   tests/main_smoke.sh native     compiled with -c, evolution + dqn
set -e -o pipefail
cd "$(dirname "$0")/.."
PAT='^.{14} gen +[0-9]+  best +[0-9]+px \([0-9]+\.[0-9]{2} laps\)  mean +[0-9]+px  \[ *[0-9]+\.[0-9]s\]$'
if [ "$1" = native ]; then H=native; modes="evolution dqn"; else H=run; modes="evolution reinforce dqn ppo"; fi
for m in $modes; do
  out="$(JD_TIME=240 tools/jd.sh $H main.jdb --headless --mode $m --cars 20 --max-steps 200 --gens 1 | grep -v '^Compiled')"
  echo "$out"
  echo "$out" | tr -d '\r' | grep -Eq "$PAT" || { echo "FAIL: $m line format"; exit 1; }
done
# bad mode must fail with status 2
if tools/jd.sh $H main.jdb --headless --mode nope >/dev/null 2>&1; then echo "FAIL: bad mode accepted"; exit 1; fi
echo "main_smoke OK"
