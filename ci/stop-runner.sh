#!/usr/bin/env bash
# Host side: deregister the runner from GitHub and remove the container.
set -uo pipefail
REPO="${REPO:-AmineChr54/RL-autonomous-racing-jdBASIC}"
NAME="${RUNNER_NAME:-jdbasic-local}"
ID="$(gh api "repos/$REPO/actions/runners" --jq ".runners[]|select(.name==\"$NAME\")|.id")"
docker rm -f "$NAME"
[ -n "$ID" ] && gh api -X DELETE "repos/$REPO/actions/runners/$ID"
echo "stopped $NAME"
