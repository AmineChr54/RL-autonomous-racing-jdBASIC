#!/usr/bin/env bash
# One-command tour of the repo, every step under the memory cap of tools/jd.sh, one jdBasic process at a time.
#   tools/demo.sh quick     about 3 minutes: tests, a short training, benchmark, playable screenshot
#   tools/demo.sh full      about 40 minutes: also the four learning curves, the GIF recordings and the pitch film
# Output goes to assets/ and docs/gifs/; every step prints what it did.
set -e
cd "$(dirname "$0")/.."
MODE="${1:-quick}"
step() { echo; echo "=== $*"; }

step "1/6 tests (autograd gradcheck, track, env parity, brain parity)"
JD_TIME=300 tools/jd.sh native tests/torch_gradcheck.jdb
JD_TIME=300 tools/jd.sh run tests/track_check.jdb
python tests/env_parity.py --native
python tests/brain_parity.py --native
python tests/torch_vs_pytorch.py --native

step "2/6 memory-leak guard (peak must stay flat over a 3x longer run)"
tests/leak_check.sh tests/evo_smoke.jdb 2 6

step "3/6 neuroevolution, headless, 5 generations"
JD_TIME=300 tools/jd.sh native main.jdb --headless --mode evolution --gens 5

step "4/6 benchmark, interpreted vs native"
JD_TIME=300 tools/jd.sh run bench.jdb 3 interp
JD_TIME=300 tools/jd.sh native bench.jdb 20 native

step "5/6 playable mode: autopilot demo, screenshot assets/playable_shot.png"
JD_TIME=300 tools/jd.sh run playable.jdb demo 300 assets/playable_shot.png

if [ "$MODE" = full ]; then
  step "6/6 full: learning curves (evolution, REINFORCE, PPO; DQN is slow, 15 iterations) and the pitch film"
  rm -f assets/curves.csv
  JD_TIME=1800 tools/jd.sh native plot_curves.jdb train evolution 60
  JD_TIME=1800 tools/jd.sh native plot_curves.jdb train reinforce 100
  JD_TIME=1800 tools/jd.sh native plot_curves.jdb train ppo 30
  JD_TIME=3600 tools/jd.sh native plot_curves.jdb train dqn 15
  tools/jd.sh run plot_curves.jdb plot
  JD_MEM=1600 JD_TIME=900 tools/jd.sh run pitch.jdb
else
  step "6/6 skipped (run 'tools/demo.sh full' for the curves and the pitch film)"
fi
echo; echo "done. Play it yourself: tools/jd.sh run playable.jdb"
