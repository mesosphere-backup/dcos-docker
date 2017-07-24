# DC/OS Docker

Run DC/OS in Docker containers!

Each container on the host emulates a DC/OS node, using Docker-in-Docker to run DC/OS jobs & services.

DC/OS Docker is designed to optimize development cycle time. For a more production-like local experience, see [DC/OS Vagrant](https://github.com/dcos/dcos-vagrant) which runs each node in its own VM.

- Smoke Tests (latest stable DC/OS): [![Build Status](https://jenkins.mesosphere.com/service/jenkins/buildStatus/icon?job=dcos-docker-test-smoke)](https://jenkins.mesosphere.com/service/jenkins/view/dcos-docker/job/dcos-docker-test-smoke/)
- Integration Tests (latest stable DC/OS): [![Build Status](https://jenkins.mesosphere.com/service/jenkins/buildStatus/icon?job=dcos-docker-test-integration)](https://jenkins.mesosphere.com/service/jenkins/view/dcos-docker/job/dcos-docker-test-integration/)

## Issue Tracking

- Issue tracking is in [DCOS JIRA](https://jira.mesosphere.com/issues/?jql=project%20%3D%20DCOS_OSS%20AND%20component%20%3D%20dcos-docker%20AND%20status%20%3D%20Open%20). Use the `dcos-docker` component in the `DCOS_OSS` JIRA project.
- Remember to make a DC/OS JIRA account and login so you can get update notifications!

## Memory Warning

Because containerization does not affect resource detection tools, each DC/OS node will think it can allocate all of the host's resources to use tasks, leading to unprotected over-subscription.

**Mitigation Options:**
- Run dcos-docker in a VM and configure the VM resources in the `Vagrantfile` to be less than the host's resources.
- Run dcos-docker on a systemd machine and configure the `mesos_executors.slice` to [configure max resources](https://www.freedesktop.org/software/systemd/man/systemd.resource-control.html) for all DC/OS user tasks (slice does not include DC/OS system tasks).

**Memory Requirements:**
- 4GiB (Required for smoke tests to pass)
- 6GiB (Recommended)

## Recommended Environments

- Virtual Machine
  - [Vagrant](https://www.vagrantup.com/) 1.9.3+ & [VirtualBox](https://www.virtualbox.org/wiki/Downloads) 5.1.18+ (CentOS 7.3 VM)
- Linux
  - Ubuntu 16.04
  - CentOS 7.3
  - [Non-systemd OS](#non-systemd-host) (experimental)
- macOS
  - [Docker for Mac](https://docs.docker.com/docker-for-mac/) (experimental)

## Requirements

- git
- make
- bash

## Quick Start

The following instructions are for Linux and Mac (w/ Docker for Mac). To use Vagrant/VirtualBox, see [Vagrant Quick Start](#vagrant-quick-start).

```
# download
git clone https://github.com/dcos/dcos-docker
cd dcos-docker

# auto-configure based on environment & download latest stable DC/OS release
./configure --auto

# build and deploy
make

# wait for async setup to complete
make postflight
```

For macOS-specific routing setup, see  [Network Routing: Docker for Mac](#network-routing-docker-for-mac).

For other make commands, see `make help`.

## Vagrant Quick Start

```
# download
git clone https://github.com/dcos/dcos-docker
cd dcos-docker

# start a CentOS VM
vagrant up

# SSH into the VM
vagrant ssh

# auto-configure based on environment & download latest stable DC/OS release
./configure --auto

# build and deploy
make

# wait for async setup to complete
make postflight
```

For OS-specific routing setup, see [Network Routing: Vagrant](#network-routing-vagrant).

## Vagrant Disk Size

By default, the `Vagrantfile` provided uses a sparse VMDK box with a 100GiB disk.

To increase this, specify the desired size in MiB before running `make`. For example:

```
vagrant/resize-disk.sh 204800
```

## Configuration

The `make-config.mk` file is expected to contain persistent configurations. Use one of the following methods to generate it:

**Automatic:**

```console
./configure --auto
```

**Interactive:**

```console
./configure
```

**Manual (example):**

```console
cat > make-config.mk << EOM
MASTERS := 3
EOM
```

See [make-defaults.mk](make-defaults.mk) for a full list of manually configurable options.

## DC/OS Versions

Official releases of DC/OS can be found at <http://dcos.io/releases/>.

By default, DC/OS Docker (`./configure`) downloads the latest **stable** version of DC/OS.

To use a different version, specify the path to the installer interactively when running `./configure` or manually in `make-config.mk` by setting `DCOS_GENERATE_CONFIG_PATH`.

[Enterprise DC/OS](https://mesosphere.com/product/) is also supported. Ask your sales representative for release artifacts.

## DC/OS Login

DC/OS uses OAuth for authentication, configured through [Auth0](https://auth0.com/) by default.

Use a Google, Github, Microsoft email account to authenticate.

### Enterprise DC/OS Login

Enterprise DC/OS uses built-in identity and access management (IAM), instead of OAuth.

For dcos-docker, the superuser account is pre-configured:

- Username: `admin`
- Password: `admin`

## Network Routing

By default with Vagrant or Docker for Mac, containers are not reachable from the host.
This will prohibit SSHing into a container (not `docker exec`) and viewing the DC/OS GUI in a browser.
However, there are a few workarounds described below.

### Network Routing: Vagrant

To make the Docker containers in the VM reachable from the host, you can route Docker's IP subnet (`172.17.0.0/16`) through the VM's IP (`192.168.65.50`). This routing is not required if you deployed DC/OS to Docker on a native Linux host.

Execute the following on the host machine. Once routing is set up, you can access DC/OS directly from the host.

**Setup**

On Linux:
```console
$ sudo ip route replace 172.17.0.0/16 via 192.168.65.50
```

On macOS:
```console
$ sudo route -nv add -net 172.17.0.0/16 192.168.65.50
```

**Cleanup**

On Linux:
```console
$ sudo ip route del 172.17.0.0/16
```

On macOS:
```console
$ sudo route delete 172.17.0.0/16
```

### Network Routing: Docker for Mac

HyperKit (the hypervisor used by Docker for Mac) does not currently support IP routing on Mac.

Use one of the following alternative solutions instead:

- [docker-mac-network](https://github.com/wojas/docker-mac-network) sets up a VPN running in containers and uses a VPN client to route traffic to other containers.
- [Docker for Mac - Host Bridge](https://github.com/mal/docker-for-mac-host-bridge) uses a kernel extension to add a new network interface and Docker network bridge.

### Node Shell Access

With network routing configured, you can SSH directly into DC/OS nodes from the host:

```console
host$ ssh -i genconf/ssh_key root@172.17.0.2
```

Or you can SSH with the DC/OS CLI:

```console
$ dcos node ssh --leader --user=root --option IdentityFile=genconf/ssh_key
```

From the host (or SSH'd into Vagrant) you can also use Docker exec to open a shell:

```console
$ docker ps --format="table {{.ID}}\t{{.Names}}\t{{.Status}}"
CONTAINER ID        NAMES                   STATUS
7498dcbe4e3e        dcos-docker-pubagent1   Up About a minute
b66175f0a18a        dcos-docker-agent1      Up About a minute
e80466ce71c9        dcos-docker-master1     Up About a minute

$ docker exec -it dcos-docker-master1 bash
```

## Storage Driver

By default, the docker daemon in the DC/OS node containers is configured to use
the same storage driver as the host docker daemon, but this method is only verified
to work for `aufs` and `overlay`. Other storage drivers may work, but are not tested.
They can be configured manually by setting the `DOCKER_STORAGEDRIVER` make variable.

To check the current host storage driver, use `docker info --format "{{json .Driver}}"`.

### Loopback

The loopback `devicemapper` storage driver may cause loopback devices to not be
properly cleaned up and thus prevent the docker daemon from starting. YMMV though.

### Overlay2

Newer versions of docker (17+) default to the `overlay2` storage driver. Since `overlay2`
is not supported by Docker 1.11.2 (the default version in the "node" containers), you must
also specify a newer version of Docker to use in the "node" containers:

```
make DOCKER_STORAGEDRIVER=overlay2 DOCKER_VERSION=1.13.1
```

Alternatively, Docker itself can be configured to use `overlay`.

To configure Docker for Mac, go to `Docker > Preferences > Daemon Advanced`, add
`"storage-driver" : "overlay"` to the configuration file, and click `Apply & Restart`.

To configure other versions of Docker, see the Docker docs appropriate to your version.

## Settings

### Changing the number of masters or agents

This defaults to 1 master and 1 agent. You can change the number of masters by
setting the variable `MASTERS`. You can change the number of agents by setting
the variable `AGENTS`. For example:

```console
# start a cluster with 3 masters and 5 agents
$ make MASTERS=3 AGENTS=5
```

### Changing the distro

> **NOTE:** This feature should only be used for testing, it is unstable.

By default the cluster will be spun up using a centos base image but if you
want to test something else you can run:

```console
$ make DISTRO=fedora
```

### Non-systemd Host

By default, systemd is used on the host to create a [systemd
slice](https://www.freedesktop.org/software/systemd/man/systemd.slice.html).
This is the supported configuration.

It is possible to run DC/OS Docker on hosts without systemd.  Set the variable
`MESOS_SYSTEMD_ENABLE_SUPPORT` to `false` to disable systemd on the host. This
changes a Mesos setting. Although this setting works at the time of writing, it is not officially supported by DC/OS and so this feature is experimental.

One problem which may occur when not using `systemd` on the host is that executors and tasks will be killed when the agent is restarted. [A JIRA issue](https://jira.mesosphere.com/browse/DCOS_OSS-1131) tracks making it possible to run DC/OS Docker in a supported manner without `systemd`.


### Docker version

By default the "node" containers will include Docker 1.11.2.
Docker 1.13.1 is also supported, but must be configured:

```console
$ make DOCKER_VERSION=1.13.1
```

One reason to use Docker 1.13.1 might be to use the `overlay2` storage driver,
which is not supported by Docker 1.11.2.
See [Storage Driver](#storage-driver) for details.


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

## Mac Compatible Installers

DC/OS installers are not immediately compatible with the BSD sed that ships with macOS. This will be fixed in a future release of DC/OS: https://github.com/dcos/dcos/pull/1571 . For now, use one of the following options:

1. Modify the installer with the following script:

    ```
    sed -e 'H;1h;$!d;x' -e "s/sed '0,/sed '1,/" dcos_generate_config.sh > dcos_generate_config.sh.bak
    mv dcos_generate_config.sh.bak dcos_generate_config.sh
    ```

2. Install GNU sed with Homebrew:

    ```
    brew install gnu-sed --with-default-names
    ```

    Warning: This method will make GNU sed the default sed, which may have unforeseen side-effects.

## Troubleshooting

See [`the troubleshooting document`](./troubleshooting.md) for details.
