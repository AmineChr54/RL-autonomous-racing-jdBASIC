---
name: ship-feature
description: The issue -> branch -> PR -> CI -> merge workflow for this repo (AmineChr54/RL-autonomous-racing-jdBASIC). Load before starting any feature or fix, and when finishing one.
---

# Shipping a feature or fix

The user has authorised opening and merging PRs and closing issues without asking. Never force-push to `main`,
never rewrite history on `main`, never delete branches other than your own.

1. **Issue.** Work on an existing issue (`gh issue view <n>`), or create one first:
   `gh issue create --title "..." --body "..." --label feature` (labels: feature, bug, jdbasic-bug, infra, perf, documentation).
2. **Branch** from up-to-date main: `git fetch origin && git switch -c <n>-short-name origin/main`.
3. **Implement** following the `jdbasic-native` skill (memory cap!). Keep the Python file layout and constants.
   Add or extend a test for what you built. Run the green-test list from `jdbasic-native` that touches your change,
   including the `--native` / `tools/jd.sh native` variant.
4. **Commit** in small logical commits. End each commit message with the attribution lines from the system prompt
   if there are any. Reference the issue (`Refs #<n>`).
5. **PR:** `git push -u origin HEAD` then
   `gh pr create --title "..." --body "Closes #<n>\n\n<what, how it was tested, timings/peak memory>"`.
6. **CI:** `gh pr checks <pr> --watch` waits for the self-hosted Docker runner (workflow `.github/workflows/ci.yml`).
   If it fails, read `gh run view --log-failed`, fix, push again. If no runner is online yet (checks pending > 10 min
   or no workflow exists), say so in the PR body and merge on the strength of your local test run.
7. **Merge:** `gh pr merge <pr> --squash --delete-branch`. Confirm the issue closed (`gh issue view <n>`).
8. **Report** back: issue/PR numbers, what changed, test results, anything left open (file new issues for leftovers).

Update STATUS.md (and README's status table) in the same PR when the state of a component changes.
