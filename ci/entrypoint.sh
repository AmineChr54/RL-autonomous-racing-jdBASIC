#!/usr/bin/env bash
# Container entrypoint: register with the short-lived token in $RUNNER_TOKEN, run, deregister on stop.
set -e
cd /home/runner/actions-runner
if [ ! -f .runner ]; then
  ./config.sh --unattended --replace --url "https://github.com/$REPO" --token "$RUNNER_TOKEN" \
    --name "$RUNNER_NAME" --labels "self-hosted,linux,jdbasic" --work _work
fi
unset RUNNER_TOKEN
./run.sh &
wait $!
