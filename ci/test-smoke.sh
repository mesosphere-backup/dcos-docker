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
