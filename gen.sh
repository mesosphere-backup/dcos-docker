#!/bin/bash -xe
docker run --rm=true --net=host --name=dcos-genconf.ef1dd14589860a8f67-23875f0bb29f9185ad.tar -i -p $PORT:9000 -v $(pwd)/genconf/:/genconf mesosphere/dcos-genconf:ef1dd14589860a8f67-23875f0bb29f9185ad --offline $*
