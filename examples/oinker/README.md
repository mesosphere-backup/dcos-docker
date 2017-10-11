# Oinker Example

Oinker-Go is an HA Twitter clone that depends on Cassandra for storage and Marathon-LB for provide load balancing.

Cassandra and Marathon-LB can be installed from the Mesosphere Universe, but they need to be configured for minimal memory footprint in order to work on dcos-docker.

Use the following steps to install and access Oinker:

1. Verify Prerequisites

    1. At least **20GB free disk space**.
    1. At least **10GB free memory**.

1. (Vagrant-only) Configure, launch, and shell into a Virtual Machine

    ```
    make vagrant-network
    vagrant up
    vagrant ssh
    ```

1. (Docker-For-Mac-only) Setup [Network Routing](/README.md#network-routing) in order to be able to access the DC/OS nodes running as Docker containers.

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

1. Deploy DC/OS:

    ```
    make all postflight
    ```

1. Setup [Hostnames](/README.md#hostnames) in order to be able to use `m1.dcos` to access the cluster and `oinker.acme.org` as the vhost to the public node load balancer.

1. Log in to the [DC/OS Web UI](http://m1.dcos/).

1. Install the DC/OS CLI using the instructions in the DC/OS Web UI.

1. Log in to DC/OS with the CLI:

    ```
    dcos auth login
    ```

    Follow the instructions (different for DC/OS vs Enterprise DC/OS).

1. Install Cassandra

    - (DC/OS >= v1.9) Cassandra 2.x

        This configuration uses three nodes for high availability.

        ```
        dcos package install --options=examples/oinker/pkg-cassandra-2.x.json cassandra --yes
        ```

    - (DC/OS < v1.9) Cassandra 1.x

        This configuration uses single-node Cassandra to reduce resource requirements and deploy time.

        ```
        dcos package install --options=examples/oinker/pkg-cassandra-1.x.json cassandra --yes
        ```

    Wait for all the expected Cassandra nodes to be running. This may take up to 15 minutes.

1. Install Marathon-LB

    ```
    dcos package install --options=examples/oinker/pkg-marathon-lb.json marathon-lb --yes
    ```

    Marathon-LB will start one task on the public agent. Wait for it to be running (should be quick).

1. Install Oinker

    - (DC/OS >= v1.9) Configured for Cassandra 2.x

        ```
        dcos marathon app add examples/oinker/oinker-2.x.json
        ```

    - (DC/OS < v1.9) Configured for Cassandra 1.x

        ```
        dcos marathon app add examples/oinker/oinker-1.x.json
        ```

    If Cassandra isn't completely ready before starting Oinker, Oinker may thrash and restart a few times before becoming healthy.

1. Visit <http://oinker.acme.org> in a browser!
