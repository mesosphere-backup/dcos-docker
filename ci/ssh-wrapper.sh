#!/usr/bin/env bash

set -o errexit -o nounset -o pipefail

eval $(ssh-agent -s)
trap "kill $SSH_AGENT_PID" EXIT

exec "$@"
