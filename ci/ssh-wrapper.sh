#!/usr/bin/env bash

set -o errexit -o nounset -o pipefail

echo 'Starting ssh-agent...'
eval $(ssh-agent -s)

function cleanup() {
  echo 'Killing ssh-agent...'
  kill ${SSH_AGENT_PID}
}
trap cleanup EXIT

# DO NOT EXEC - exec nullifies traps
"$@"
