## dcos-docker

Run dcos with systemd and docker in two containers.

## Quick Start

1. Put a `dcos_generate_config.sh` in the root of this directory.

2. From this directory run `make`.

## Vagrant Setup

1. Install & Configure Vagrant & VirtualBox

    This repo assumes Vagrant and VirtualBox are installed and configured to work together.

    See the [Architecture docs](./docs/architecture.md) for details about the DC/OS Vagrant cluster architecture.

1. Configure VirtualBox Networking

    Configure the host-only `vboxnet0` network to use the 192.168.65.0/24 subnet.

    1. Create the `vboxnet0` network if it does not exist:

        ```bash
        VBoxManage list hostonlyifs | grep vboxnet0 -q || VBoxManage hostonlyif create
        ```

    1. Set the `vboxnet0` subnet:

        ```
        VBoxManage hostonlyif ipconfig vboxnet0 --ip 192.168.65.1
        ```

1. Install Vagrant Host Manager Plugin

    The [Host Manager Plugin](https://github.com/smdahlen/vagrant-hostmanager) manages the `/etc/hosts` on the VMs and host to allow access by hostname.

    ```bash
    vagrant plugin install vagrant-hostmanager
    ```

    This will update `/etc/hosts` every time VMs are created or destroyed.

    To avoid entering your password on `vagrant up` & `vagrant destroy` you may enable [passwordless sudo](https://github.com/smdahlen/vagrant-hostmanager#passwordless-sudo).

    On some versions of Mac OS X, installing vagrant plugins may require [installing a modern version of Ruby](./docs/install-ruby.md).


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

#### Changing the number of agents &/or masters

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
