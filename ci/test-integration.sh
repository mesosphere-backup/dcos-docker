#!/usr/bin/env bash

# Performs smoke testing of DC/OS Docker.
#
# Usage:
# $ ci/test-e2e.sh

set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

# Require bash 4+ for associative arrays
if [[ ${BASH_VERSINFO[0]} -lt 4 ]]; then
  echo "Requires Bash 4+" >&2
  exit 1
fi

project_dir=$(cd "$(dirname "${BASH_SOURCE}")/.." && pwd -P)
cd "${project_dir}"

# Log dependency versions
docker --version
jq --version
echo "${BASH_VERSINFO[@]}"

# Check for running containers
docker ps

# Destroy All VMs
make clean

# Destroy All VMs on exit
function cleanup() {
  make clean
}
trap cleanup EXIT

# Auto-configure
./configure --auto

# Networking integration tests require 2 private agents
sed 's/^AGENTS :=.*/AGENTS := 2/' make-config.mk > make-config.mk.bak
mv make-config.mk.bak make-config.mk

# Deploy
make

# Wait
make postflight

# Cleanup hosts on exit
function cleanup2() {
  make clean-hosts
  cleanup
}
trap cleanup2 EXIT

# Setup /etc/hosts (password required)
make hosts

# Test API (unauthenticated)
curl --fail --location --silent --show-error --verbose http://m1.dcos/dcos-metadata/dcos-version.json

# Add test user (required to be added when not the first user)
# TODO: only required for OSS DC/OS
ci/dcos-create-user.sh "albert@bekstil.net"

# Delete CLI on exit
function cleanup3() {
  # Copy out test results
  docker cp dcos-docker-master1:/opt/mesosphere/active/dcos-integration-test/test-junit.xml test-junit.xml || true
  cleanup2
}
trap cleanup3 EXIT

# Integration tests
make test \
  DCOS_PYTEST_CMD="py.test -vv --junitxml=test-junit.xml -m 'not ccm'" \
  DCOS_PYTEST_DIR="/opt/mesosphere/active/dcos-integration-test/"
