# Pitch video storyboard (about 60 s, rendered by record.jdb, all jdBasic)

| s | Scene | Source |
|---|---|---|
| 0-6 | Title: "200 cars. 0 drivers. All jdBasic." Generation 1: cars crash within metres | `main.jdb --mode evolution --record` gen 1 |
| 6-18 | Evolution montage: gen 1, 5, 10, 20 time-lapse, trails glow, first full lap | evolution run, 4 clips |
| 18-30 | Split screen: evolution, REINFORCE, PPO, DQN on the same hard track, live distance bars | four trainers, same seed |
| 30-40 | Human vs AI: a player car races the best brain, lap timer, ghost | playable mode |
| 40-50 | Learning curves draw themselves (`assets/curves.svg` animated) | plot_curves.jdb |
| 50-60 | Numbers: native 26x faster than interpreted, 63 MB flat memory, 0 Python | bench.jdb, STATUS.md |

Captions are drawn with GFX text; transitions are alpha blends between frames. Output: GIF via `lib/gif.jdb`
plus a PNG frame sequence for any encoder.

## What exists (`pitch.jdb` -> `docs/gifs/pitch.gif`, 238 frames, 1.4 MB, about 1 min and 1.5 GB peak to build)
Title card, the four learners side by side, the skill ladder (the best brains of evolution generation 3, 8, 15 and 25 race one track, the weak ones crash), the learning curves drawing themselves (from `assets/curves.csv`), the numbers card. Not yet in the film: the human-vs-AI scene (needs frames from `playable.jdb`, #57).
