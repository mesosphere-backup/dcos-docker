#!/bin/bash -xe
DCOS_GENERATE_CONFIG="${1:-dcos_generate_config.sh}"
sudo rm -rf tmp
mkdir -p tmp
sed '0,/^#EOF#$/d' $DCOS_GENERATE_CONFIG | tar Oxv | tar -xC tmp
find tmp -name layer.tar | xargs -t -n 1 sudo tar -C tmp -xf
sudo mkdir -p tmp/opt/mesosphere
sudo tar -C tmp/opt/mesosphere -Jxvf tmp/artifacts/*.bootstrap.tar.xz
