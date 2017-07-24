#!/usr/bin/env bash

# Installs and tests Oinker on DC/OS Docker.
# Requires dcos CLI to be installed, configured, and logged in.
#
# Usage:
# $ ci/test-oinker.sh

set -o errexit -o nounset -o pipefail

OINKER_HOST="${OINKER_HOST:-oinker.acme.org}"

project_dir=$(cd "$(dirname "${BASH_SOURCE}")/.." && pwd -P)
cd "${project_dir}"

source vendor/semver_bash/semver.sh

# CLI v0.5.3 added a confirmation prompt to uninstall and --yes to bypass it.
CLI_VERSION="$(dcos --version | grep dcoscli.version | cut -d'=' -f2)"
if semverLT "${CLI_VERSION}" "0.5.3"; then
  CONFIRM=''
else
  CONFIRM='--yes'
fi

set -o xtrace

# Install Cassandra
dcos package install --options=examples/oinker/pkg-cassandra.json cassandra --yes
ci/test-app-health.sh 'cassandra'

# Install Marathon-LB
dcos package install --options=examples/oinker/pkg-marathon-lb.json marathon-lb --yes
ci/test-app-health.sh 'marathon-lb'

# Install Oinker
dcos marathon app add examples/oinker/oinker.json
ci/test-app-health.sh 'oinker'

# Test HTTP status
curl --fail --location --silent --show-error "http://${OINKER_HOST}/" -o /dev/null

# Test load balancing uses all instances
ci/test-oinker-lb.sh

# Test posting and reading posts
ci/test-oinker-oinking.sh

# Uninstall Oinker
dcos marathon app remove oinker

# Uninstall Marathon-LB
dcos package uninstall marathon-lb ${CONFIRM}

# Uninstall Cassandra
dcos package uninstall cassandra ${CONFIRM}

# Uninstall Cassandra framework
dcos node ssh --master-proxy --leader --user=root --option StrictHostKeyChecking=no --option IdentityFile=$(pwd)/genconf/ssh_key \
  "docker run mesosphere/janitor /janitor.py -r cassandra-role -p cassandra-principal -z dcos-service-cassandra"
