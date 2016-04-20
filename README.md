## dcos-docker

Run dcos with systemd and docker in two containers.

## Quick Start

1. Put a `dcos_generate_config.sh` in the root of this directory.

2. From this directory run `make`.

**Makefile usage:**

```console
$ make help
all                            Runs a full deploy of DCOS in containers.
agent                          Starts the containers for dcos agents.
build-all                      Build the Dockerfiles for all the various distros.
build                          Build the docker image that will be used for the containers.
clean-certs                    Remove all the certs generated for the registry.
clean                          Stops all containers and removes all generated files for the cluster.
clean-containers               Removes and cleans up the master, agent, and installer containers.
clean-slice                    Removes and cleanups up the systemd slice for the mesos executor.
deploy                         Run the dcos installer with --deploy.
genconf                        Run the dcos installer with --genconf.
generate                       generate the Dockerfiles for all the distros.
info                           Provides information about the master and agent's ips.
installer                      Starts the container for the dcos installer.
master                         Starts the containers for dcos masters.
open-browser                   Opens your browser to the master ip.
preflight                      Run the dcos installer with --preflight.
registry                       Start a docker registry with certs in the mesos master.
web                            Run the dcos installer with --web.
```

### Requirements

- A Linux machine with systemd and docker installed.

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

By default the cluster will be spun up using a centos base image but if you
want to test something else you can run:

```console
$ make DISTRO=ubuntu
$ make DISTRO=debian
$ make DISTRO=fedora
```
