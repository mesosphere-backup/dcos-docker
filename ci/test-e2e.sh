#!/usr/bin/env bash

# Performs End To End (e2e) testing of DC/OS Docker.
#
# Options:
#   DCOS_VERSION (defaults to the "latest" in dcos-versions.yaml)
#
# Usage:
# $ ci/test-e2e.sh

set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

# Networking integration tests require 2 private agents
MAKE_ARGS="AGENTS=2"

# Require bash 4+ for associative arrays
if [[ ${BASH_VERSINFO[0]} -lt 4 ]]; then
  echo "Requires Bash 4+" >&2
  exit 1
fi

project_dir=$(cd "$(dirname "${BASH_SOURCE}")/.." && pwd -P)
cd "${project_dir}"

# Log dependency versions
jq --version

# Default to latest known version unless DCOS_VERSION is specified
if [[ -z "${DCOS_VERSION:-}" ]]; then
  bash dcos_generate_config.sh --version
  DCOS_VERSION="$(bash dcos_generate_config.sh --version | jq -r '.version')"
fi

# Destroy All VMs
make clean ${MAKE_ARGS}

# Destroy All VMs on exit
function cleanup() {
  make clean ${MAKE_ARGS}
}
trap cleanup EXIT

# Deploy
make ${MAKE_ARGS}

# Wait
make postflight ${MAKE_ARGS}

# Cleanup hosts on exit
function cleanup2() {
  make clean-hosts ${MAKE_ARGS}
  cleanup
}
trap cleanup2 EXIT

# Setup /etc/hosts (password required)
make hosts ${MAKE_ARGS}

# Test API (unauthenticated)
curl --fail --location --silent --show-error --verbose http://m1.dcos/dcos-metadata/dcos-version.json

# Install CLI
DCOS_CLI="$(ci/dcos-install-cli.sh)"
echo "${DCOS_CLI}"

# Delete CLI on exit
function cleanup3() {
  # only use sudo if required
  if [[ -w "$(dirname "${DCOS_CLI}")" ]]; then
    rm -rf "${DCOS_CLI}"
  else
    sudo rm -rf "${DCOS_CLI}"
  fi
  cleanup2
}
trap cleanup3 EXIT

# Create User
DCOS_USER="test@example.com"
ci/dcos-create-user.sh "${DCOS_USER}"

# Login
DCOS_ACS_TOKEN="$(ci/dcos-login.sh "${DCOS_USER}")"
dcos config set core.dcos_acs_token "${DCOS_ACS_TOKEN}"

# Install & test Oinker
ci/test-oinker.sh

# Detect URL
DCOS_URL="$(dcos config show core.dcos_url)"

# Test GUI (authenticated)
curl --fail --location --silent --show-error --verbose -H "Authorization: token=${DCOS_ACS_TOKEN}" ${DCOS_URL} -o /dev/null

# Add test user (required to be added when not the first user)
# TODO: only required for OSS DC/OS
ci/dcos-create-user.sh "albert@bekstil.net"

# Delete CLI on exit
function cleanup4() {
  # Copy out test results
  docker cp dcos-docker-master1:/opt/mesosphere/active/dcos-integration-test/test-junit.xml test-junit.xml || true
  cleanup3
}
trap cleanup4 EXIT

# Integration tests
make test ${MAKE_ARGS} \
  DCOS_PYTEST_CMD="py.test -vv --junitxml=test-junit.xml -m 'not ccm'" \
  DCOS_PYTEST_DIR="/opt/mesosphere/active/dcos-integration-test/"
