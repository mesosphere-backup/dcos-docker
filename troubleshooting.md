# Troubleshooting

Common errors and their solutions.

## The cluster is running but it does not appear to be working

There are many potential root causes of this and so there is no silver bullet.
However, a useful technique is to look at the logs of `systemd units`.

First, `docker exec` into a master or agent on the cluster.
To do this, first find the name or ID of the container using `docker ps`.
By default, the single `master` container will be named `dcos-docker-master1`.

To get a shell on this node, run:

```
$ docker exec -it dcos-docker-master1 bash
```

Once on the node, list `systemd` units:

```
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
```

Choose a `systemd` unit with the `ACTIVE` status `exited` and check its status.
In the above example, the unit is named `systemd-fail.service`.

```
[root@dcos-docker-master1 /]# systemctl status systemd-fail
```

Then get the logs for this unit:

```
[root@dcos-docker-master1 /]# journalctl -xefu systemd-fail
```

On hosts without `systemd` such as macOS and legacy versions of Ubuntu, an unsupported Mesos setting is used.
See "Non-systemd host" in [`README.md`](./README.md) for details.

## `dcos-spartan` does not start

For the `dcos-spartan` service to start successfully, make sure that
you have dummy net driver support (`CONFIG_DUMMY`) enabled in your kernel.
Most standard distribution kernels should have this by default. On some
older kernels you may need to manually install this module with
`modprobe dummy` before starting the container cluster.

## Docker out of space

There are multiple symptoms and fixes for Docker being out of space.
If an error which suggests that Docker is out of space presents, try the following command:

```
docker volume prune
```

It is possible that DC/OS services will fail to start and an error similar to the following will be reported in `journalctl`.

```
Jun 26 22:32:44 dcos-docker-master1 start_exhibitor.py[6242]: Traceback (most recent call last):
Jun 26 22:32:44 dcos-docker-master1 start_exhibitor.py[6242]: File "/opt/mesosphere/packages/exhibitor--72d9d8f947e5411eda524d40dde1a58edeb158ed/usr/exhibitor/start_exhibitor.py", l
Jun 26 22:32:44 dcos-docker-master1 start_exhibitor.py[6242]: """)
Jun 26 22:32:44 dcos-docker-master1 start_exhibitor.py[6242]: File "/opt/mesosphere/packages/exhibitor--72d9d8f947e5411eda524d40dde1a58edeb158ed/usr/exhibitor/start_exhibitor.py", l
Jun 26 22:32:44 dcos-docker-master1 start_exhibitor.py[6242]: f.write(contents)
Jun 26 22:32:44 dcos-docker-master1 start_exhibitor.py[6242]: OSError: [Errno 28] No space left on device
```

On Docker for Mac, this can be fixed by deleting the disk image.
To do this, go to Docker > Preferences > Advanced to find the "Disk image location".
Delete this disk image and then quit and reopen Docker.
This is a destructive action which will delete various Docker-related things such as images.
The destruction is not limited to things related to DC/OS.
It is possible that a less destructive action could be found for particular cases where Docker is out of space, but this option will likely cover many causes.

## The installer is not recognised as a valid `tar` file on macOS

See "Mac Compatible Installers" in [`README.md`](./README.md).

## SSH to nodes does not work

See "Network Routing" in [`README.md`](./README.md).
