## dcos-docker

Run DC/OS with systemd and docker in two containers.

## Requirements

### Linux

- systemd
- make
- Docker 1.11
- A recent kernel that supports Overlay FS
- git

### Mac

- VirtualBox 5.0.18 or later
- Vagrant 1.8.1 or later
- git

## Setup

**The following steps are REQUIRED on all hosts.**

1. Clone this repo

    ```
    git clone https://github.com/dcos/dcos-docker
    cd dcos-docker
    ```

1. Download [DC/OS](https://dcos.io/releases/) or [Enterprise DC/OS](https://mesosphere.com/product/)
1. Move the installer to `dcos_generate_config.sh` in the root of this repo directory.

**The following steps are OPTIONAL on Linux hosts.**

1. Install [VirtualBox](https://www.virtualbox.org/wiki/Downloads)
1. Install [Vagrant](https://www.vagrantup.com/)
1. (Optional) Install vagrant-vbguest plugin (auto-updates vbox additions)

    ```console
    vagrant plugin install vagrant-vbguest
    ```

1. (Optional) Resize the vagrant disk

    DC/OS should deploy with the default disk size of 10GB, but for larger deployments you may need to increase the size of the VM.

    The first argument is the desired disk size in MB (ex: 102400 is 100GB).

    ```console
    vagrant/resize-disk.sh 102400
    ```

1. Bring up the virtual machine

    ```console
    vagrant up
    ```

1. SSH into the virtual machine

    ```console
    vagrant ssh
    ```

1. Change into the mounted repo directory

    ```console
    cd /vagrant
    ```

## Deploy

1. Deploy DC/OS in Docker

    ```console
    make
    ```

1. (Optional) Wait for DC/OS to come up

    ```console
    make postflight
    ```

For other make commands, see `make help`.

## Network Routing

To make the Docker containers in the VM reachable from the host, you can route Docker's IP subnet (`172.17.0.0/16`) through the VM's IP (`192.168.65.50`):

1. Setup routing

    On **Linux**:
    ```console
    host$ sudo ip route replace 172.17.0.0/16 via 192.168.65.50
    host$ ping 172.17.0.2 #ping DC/OS master after cluster is up
    host$ curl http://172.17.0.2
    ```

    On **Mac OS X**:
    ```console
    host$ sudo route -nv add -net 172.17.0.0/16 192.168.65.50
    ```

1. SSH directly into a container

    ```console
    host$ ssh -i genconf/ssh_key root@172.17.0.2
    ```

## Graphdriver/Storage driver

There is no requirement on the hosts storage driver type, but the docker daemon
running inside docker container supports only `aufs` and `overlay`. The loopback
devicemapper may be problematic when it comes to loopback devices - they may not
be properly cleaned up and thus prevent docker daemon from starting. YMMV
though.

Unless user specifies graphdriver using `DOCKER_GRAPHDRIVER` env variable,
the script tries to use the same one as the host uses. It detects it using
`docker info` command. The resulting graphdriver must be among supported ones,
or the script will terminate.

## Settings

### Changing the number of masters or agents

This defaults to 1 master and 1 agent. You can change the number of masters by
setting the variable `MASTERS`. You can change the number of agents by setting
the variable `AGENTS`. For example:

```console
$ make MASTERS=3 AGENTS=5
# start a cluster with 3 masters and 5 agents
```

### Changing the distro

> **NOTE:** This feature should only be used for testing, it is unstable.

By default the cluster will be spun up using a centos base image but if you
want to test something else you can run:

```console
$ make DISTRO=fedora
```

## Troubleshooting

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

For the `dcos-spartan` service to start successfully, make sure that
you have dummy net driver support (`CONFIG_DUMMY`) enabled in your kernel.
Most standard distribution kernels should have this by default. On some
older kernels you may need to manually install this module with
`modprobe dummy` before starting the container cluster.

## Github Pull Request (PR) Labels

Various labels used on pull requests and what they mean

 - `Work in progress` The code is a work in progress / not yet ready to be
   reviewed or acted upon by others. It can be handy to open up a PR in order
   to share work / ideas with others. Use this label to indicate the PR isn't
   intended to be reviewed or merged.
 - `Request for comment` The code is some idea which may or may not land, but
    there are questions if the approach is right. Review should focus on
    whether or not it is overall a good idea to do this and how to structure it.
 - `Ready for review` The author thinks the PR is ready to land, and is looking for a
    review in order to get it in. The PR may bounce back to "work in progress"
    or "request for comment" if it needs more work or discussion. Might also
    just do all the review and fixup with the label attached.
