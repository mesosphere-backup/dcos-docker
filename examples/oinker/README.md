# Oinker Example

Oinker-Go is an HA Twitter clone that depends on Cassandra for storage and Marathon-LB for provide load balancing.

Cassandra and Marathon-LB can be installed from the Mesosphere Universe, but they need to be configured for minimal memory footprint in order to work on dcos-docker.

Use the following steps to install and access Oinker:

1. Verify Prerequisites

    1. At least **20GB free disk space**. On Vagrant, the default is sufficient but also configurable before deploy with `vagrant/resize-disk.sh 20480`.

    1. At least **10GB free memory**. On Vagrant, the default is sufficient but also configurable before deploy in the Vagrantfile.

1. Configure dcos-docker

    Auto-detect the base config:

    ```
    ./configure --auto
    ```

    Update the config to use 3 private agents:

    ```
    sed 's/^AGENTS :=.*/AGENTS := 3/' make-config.mk > make-config.mk.bak
    mv make-config.mk.bak make-config.mk
    ```

1. Deploy DC/OS by following the [Quick Start](/README.md#quick-start) instructions.

1. Setup [Network Routing](/README.md#network-routing) in order to be able to access the DC/OS nodes running as Docker containers.

1. Setup [Hostnames](/README.md#hostnames) in order to be able to use `m1.dcos` to access the cluster and `oinker.acme.org` as the vhost to the public node load balancer.

1. Install DC/OS CLI using the instructions in the [DC/OS Web UI](http://m1.dcos/).

1. Log in to DC/OS:

    ```
    dcos auth login
    ```

    Follow the instructions (different for DC/OS vs Enterprise DC/OS).

1. Install Cassandra

    ```
    dcos package install --options=examples/oinker/pkg-cassandra-2.x.json cassandra --yes
    ```

    The Cassandra 1.x config uses a single node to minimize resource usage.

    The Cassandra 2.x config uses three nodes because Cassandra 2.x does not support single node deployment.

    Wait for all the expected Cassandra nodes to be running. This may take up to 15 minutes.

1. Install Marathon-LB

    ```
    dcos package install --options=examples/oinker/pkg-marathon-lb.json marathon-lb --yes
    ```

    Marathon-LB will start one task on the public agent. Wait for it to be running (should be quick).

1. Install Oinker

    ```
    dcos marathon app add examples/oinker/oinker-2.x.json
    ```

    If Cassandra isn't completely ready before starting Oinker, Oinker may thrash and restart a few times before becoming healthy.

1. Visit <http://oinker.acme.org> in a browser!

## Configuration Options

The Cassandra framework was rewritten for version 2.0.
The new version requires 3 nodes and no longer allows seeds to be configured.
So on DC/OS >= 1.9 the new configuration should be used.
Older versions of DC/OS must use the older Cassandra 1.x.

New 2.x Config:
- [pkg-cassandra-2.x.json](pkg-cassandra-2.x.json)
- [pkg-marathon-lb.json](pkg-marathon-lb.json)
- [oinker-2.x.json](oinker-2.x.json)

Old 1.x Config:
- [pkg-cassandra-1.x.json](pkg-cassandra-1.x.json)
- [pkg-marathon-lb.json](pkg-marathon-lb.json)
- [oinker-1.x.json](oinker-1.x.json)
