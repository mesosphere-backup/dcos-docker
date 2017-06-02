#!/usr/bin/env bash

# Tears down a Mesos framework.
# DC/OS CLI must be installed, configured, and logged in!
#
# Usage:
# $ ci/dcos-teardown-framework.sh <fwk-id>
#
# Options:
#   DCOS_URL (default: http://m1.dcos)

set -o errexit
set -o nounset
set -o pipefail

if [[ -z "${1:-}" ]]; then
  echo >&2 'Framework ID required'
  exit 2
fi

FRAMEWORK_ID="${1}"
DCOS_URL="${DCOS_URL:-http://m1.dcos}"
DCOS_ACS_TOKEN="$(dcos config show core.dcos_acs_token)"

curl -v -L -X POST \
     -H "Content-Type: application/json" \
     -H "Authorization: token=${DCOS_ACS_TOKEN}" \
     -d "frameworkId=${FRAMEWORK_ID}" \
     "${DCOS_URL}/mesos/teardown"
