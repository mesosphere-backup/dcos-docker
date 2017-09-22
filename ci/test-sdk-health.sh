#!/usr/bin/env bash

# Polls an SDK service until it is healthy using the dcos CLI.
# Times out after 5 minutes.
#
# Usage:
# $ ci/test-sdk-health.sh <app-id> [timeout-seconds]

set -o errexit -o nounset -o pipefail

project_dir=$(cd "$(dirname "${BASH_SOURCE}")/.." && pwd -P)
cd "${project_dir}"

SERVICE_TYPE="${1}" # ex: cassandra
SERVICE_ID="${2}" # ex: cassandra
MAX_ELAPSED="${3:-300}" # In seconds. Default: 5 minutes.

DEPLOY_STATUS_CODE='N/A'

RESULT='timed-out'
START_TIME=${SECONDS}
while [[ $((${SECONDS} - ${START_TIME})) -lt ${MAX_ELAPSED} ]]; do
  echo "Polling ${SERVICE_TYPE} (id=${SERVICE_ID}) deploy status..."
  if ! DEPLOY_STATUS="$(dcos ${SERVICE_TYPE} --name "${SERVICE_ID}" plan status deploy --json)"; then
    echo >&2 "Command failed: dcos ${SERVICE_TYPE} --name "${SERVICE_ID}" plan status deploy --json"
    echo >&2 "${DEPLOY_STATUS}"
    continue
  fi
  DEPLOY_STATUS_CODE="$(echo "${DEPLOY_STATUS}" | jq -r '.status')"
  if [[ "${DEPLOY_STATUS_CODE}" == 'COMPLETE' ]]; then
    RESULT='complete'
    break
  fi
  DEPLOY_STATUS_ERRORS="$(echo "${DEPLOY_STATUS}" | jq -r '.errors')"
  if [[ "${DEPLOY_STATUS_ERRORS}" != '[]' ]]; then
    RESULT='error'
    break
  fi
  sleep 5
done

if [[ "${RESULT}" == 'error' ]]; then
  echo >&2 "${SERVICE_TYPE} (${SERVICE_ID}) deploy ${DEPLOY_STATUS_CODE}"
  echo >&2 "Status:\n${DEPLOY_STATUS}"
  exit 1
fi
if [[ "${RESULT}" == 'timed-out' ]]; then
  echo >&2 "${SERVICE_TYPE} (${SERVICE_ID}) deploy ${DEPLOY_STATUS_CODE} -- Timed out after ${MAX_ELAPSED} seconds."
  echo >&2 "Status:\n${DEPLOY_STATUS}"
  exit 1
fi
echo >&2 "${SERVICE_TYPE} (${SERVICE_ID}) deploy ${DEPLOY_STATUS_CODE}"
