#!/usr/bin/env bash
# Host side (Git Bash): build the image, register a self-hosted runner with a short-lived token, start the container.
# The token is fetched from the GitHub API at start time and only lives in the container's environment.
set -euo pipefail
export MSYS_NO_PATHCONV=1
REPO="${REPO:-AmineChr54/RL-autonomous-racing-jdBASIC}"
NAME="${RUNNER_NAME:-jdbasic-local}"
HERE="$(cd "$(dirname "$0")" && pwd -W 2>/dev/null || pwd)"
JDBASIC_REF="${JDBASIC_REF:-70c1b7b0}"   # upstream AtomiJD/jdBasic commit built into the image
# building jdBasic + LLVM codegen is heavy: hard 6 GB limit on the build (never an unlimited build on this machine)
docker build --memory 6g --memory-swap 6g --build-arg JDBASIC_REF="$JDBASIC_REF" -t jdbasic-runner "$HERE"
docker rm -f "$NAME" >/dev/null 2>&1 || true
TOKEN="$(gh api -X POST "repos/$REPO/actions/runners/registration-token" --jq .token)"
docker run -d --name "$NAME" --restart unless-stopped \
  --memory 3g --memory-swap 3g --cpus 4 \
  -e REPO="$REPO" -e RUNNER_NAME="$NAME" -e RUNNER_TOKEN="$TOKEN" \
  jdbasic-runner
echo "started $NAME; check: gh api repos/$REPO/actions/runners --jq '.runners[]|[.name,.status]'"
