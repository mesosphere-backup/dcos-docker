#!/usr/bin/env bash

# Extracts the last N (default 10000) lines from journalctl on each node.
#
# Usage:
# $ ci/dcos-logs.sh [--lines=N]

set -o errexit -o nounset -o pipefail

LINES=10000

for i in "$@"; do
  case ${i} in
    -l=*|--lines=*)
      LINES="${i#*=}"
      shift # past argument=value
      ;;
    *)
      echo >&2 "Invalid parameter: ${i}"
      exit 1
      ;;
  esac
done

function extract_logs() {
  CTR_NAME="$1"
  local i=1
  while docker inspect "${CTR_NAME}${i}" &>/dev/null; do
    echo "Extracting Logs: ${CTR_NAME}${i}"
    docker exec -i "${CTR_NAME}${i}" journalctl -n ${LINES} > "${CTR_NAME}${i}.log"
    i+=1
  done
}

extract_logs 'dcos-docker-master'
extract_logs 'dcos-docker-agent'
extract_logs 'dcos-docker-pubagent'
