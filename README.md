## dcos-docker

Run DC/OS with systemd and docker in two containers.

### Requirements

- A Linux machine with systemd, make, and docker 1.10 installed. (Your Docker
  graphdriver needs to be AUFS or Overlay). You need a kernel that is _not_
  a franken kernel.


## Quick Start

1. Put a `dcos_generate_config.sh` in the root of this directory.

2. From this directory run `make`.

**Makefile usage:**

```console
$ make help
all                            Runs a full deploy of DC/OS in containers.
agent                          Starts the containers for DC/OS agents.
build-all                      Build the Dockerfiles for all the various distros.
build                          Build the docker image that will be used for the containers.
clean-certs                    Remove all the certs generated for the registry.
clean                          Stops all containers and removes all generated files for the cluster.
clean-containers               Removes and cleans up the master, agent, and installer containers.
clean-slice                    Removes and cleanups up the systemd slice for the mesos executor.
deploy                         Run the DC/OS installer with --deploy.
genconf                        Run the DC/OS installer with --genconf.
generate                       generate the Dockerfiles for all the distros.
info                           Provides information about the master and agent's ips.
installer                      Starts the container for the DC/OS installer.
install                        Install DC/OS using "advanced" method
master                         Starts the containers for DC/OS masters.
open-browser                   Opens your browser to the master ip.
preflight                      Run the DC/OS installer with --preflight.
registry                       Start a docker registry with certs in the mesos master.
web                            Run the DC/OS installer with --web.
```

### Settings

#### Changing the number of masters or agents

This defaults to 1 master and 1 agent. You can change the number of masters by
setting the variable `MASTERS`. You can change the number of agents by setting
the variable `AGENTS`. For example:

```console
$ make MASTERS=3 AGENTS=5
# start a cluster with 3 masters and 5 agents
```

#### Changing the distro

> **NOTE:** This feature should only be used for testing, it is unstable.

By default the cluster will be spun up using a centos base image but if you
want to test something else you can run:

```console
$ make DISTRO=fedora
```

### Running with vagrant

There is a Vagrantfile in the root on this repository you can use it to run
dcos-docker if you do not satisfy the [requirements](#requirements) on your
host.

```console
# bring up the virtual machine
$ vagrant up

# ssh into the vagrant box
$ vagrant ssh

# the directory for this repo is in /vagrant
$ cd /vagrant

# now run make
$ make
```

### Troubleshooting

Oh dear, you must be in an unfortunate position. You have a few options with
regard to debugging your container cluster.

If the containers are currently running then the best option is to `docker exec`
into the master or agent and poke around. Here is an example of that:

```console
$ docker exec -it dcos-docker-master1 bash

# list the systemd units
[root@dcos-docker-master1 /]# systemctl list-units
...
dbus.socket                         loaded active     running         D-Bus System Message Bus Socket
systemd-fail.service                loaded failed     exited          Journal Audit Socket
systemd-journald-dev-log.socket     loaded active     running         Journal Socket (/dev/log)
systemd-journald.socket             loaded active     running         Journal Socket
basic.target                        loaded active     active          Basic System
dcos.target                         loaded active     active          dcos.target
local-fs.target                     loaded active     active          Local File Systems
...

# find the failed unit and get the status
[root@dcos-docker-master1 /]# systemctl status systemd-fail

# get the logs from journald
[root@dcos-docker-master1 /]# journalctl -xefu systemd-fail
```

