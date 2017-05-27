#!/usr/bin/env bash

# Extracts the release files from a DC/OS installer (dcos_generate_config.sh).
#
# Usage:
# $ ci/dcos-extract.sh [installer-path]

set -o errexit
set -o nounset
set -o pipefail

DCOS_GENERATE_CONFIG="${1:-dcos_generate_config.sh}"

sudo rm -rf tmp
mkdir -p tmp
sed '0,/^#EOF#$/d' $DCOS_GENERATE_CONFIG | tar Oxv | tar -xC tmp
find tmp -name layer.tar | xargs -t -n 1 sudo tar -C tmp -xf
sudo mkdir -p tmp/opt/mesosphere
sudo tar -C tmp/opt/mesosphere -Jxvf tmp/artifacts/*.bootstrap.tar.xz
