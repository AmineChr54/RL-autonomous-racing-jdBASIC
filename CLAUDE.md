# RL-autonomous-racing-jdBASIC

jdBasic port of D:\Projects\RL-autonomous-racing (Python). State of every component: STATUS.md. Plan: README.md + open issues.

- Before writing or running any `.jdb`: load the `jdbasic-native` skill. **Every jdBasic run goes through
  `tools/jd.sh` / `tools/jd.py` (hard memory cap)**; an uncapped native run once took 14.5 GB.
- Before starting or finishing a feature/fix: load the `ship-feature` skill (issue -> branch -> PR -> CI -> merge,
  PRs are merged without asking).
