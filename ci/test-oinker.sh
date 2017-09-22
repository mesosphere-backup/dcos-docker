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

DCOS_VERSION="$(dcos --version | grep dcos.version | cut -d'=' -f2)"

# strip minor version and suffix
if [[ "${DCOS_VERSION}" =~ ^([^.]*\.[^.-]*).* ]]; then
  DCOS_VERSION="${BASH_REMATCH[1]}.0"
fi

# DC/OS 1.10 added auto-cleanup. Prior versions need to use the janitor.
if semverLT "${DCOS_VERSION}" "1.10.0"; then
  CASSANDRA_PKG_CLEANUP="true"
fi

# Latest Cassandra requires >= 1.9
# https://github.com/mesosphere/universe/blob/version-3.x/repo/packages/C/cassandra/26/package.json#L3
if semverLT "${DCOS_VERSION}" "1.9.0"; then
  CASSANDRA_PKG_VERSION='1.x'
else
  CASSANDRA_PKG_VERSION='2.x'
fi

set -o xtrace

# Install Cassandra
dcos package install --options=examples/oinker/pkg-cassandra-${CASSANDRA_PKG_VERSION}.json cassandra --yes
ci/test-app-health.sh 'cassandra'

if [[ "${CASSANDRA_PKG_VERSION}" == '2.x' ]]; then
  # Block until node deployment is complete (15 minute timeout)
  ci/test-sdk-health.sh 'cassandra' 'cassandra' 900
fi

# Install Marathon-LB
dcos package install --options=examples/oinker/pkg-marathon-lb.json marathon-lb --yes
ci/test-app-health.sh 'marathon-lb'

# Install Oinker
dcos marathon app add examples/oinker/oinker-${CASSANDRA_PKG_VERSION}.json
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

# DC/OS 1.10 added auto-cleanup. Prior versions need to use the janitor.
if [[ "${CASSANDRA_PKG_CLEANUP:-}" == "true" ]]; then
  dcos node ssh --leader --user=root --option StrictHostKeyChecking=no --option IdentityFile=$(pwd)/genconf/ssh_key \
       "docker run mesosphere/janitor /janitor.py -r cassandra-role -p cassandra-principal -z dcos-service-cassandra"
fi
