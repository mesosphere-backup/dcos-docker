#!/bin/bash -xe
sudo mkdir -p /sys/fs/cgroup/cpu,cpuacct/machine.slice/machine-slave.scope
sudo mkdir -p /sys/fs/cgroup/memory/machine.slice/machine-slave.scope
sudo mkdir -p /sys/fs/cgroup/freezer/machine.slice/machine-slave.scope
sudo mkdir -p /sys/fs/cgroup/net_cls,net_prio/machine.slice/machine-slave.scope
sudo mkdir -p /sys/fs/cgroup/perf_event/machine.slice/machine-slave.scope
sudo systemd-nspawn \
	-D slave \
	-b --bind-ro=/usr/bin/docker:/usr/bin/docker \
	--bind=/var/run/docker.sock:/var/run/docker.sock \
	--bind-ro=/bin/true:/usr/sbin/modprobe \
	--bind=/home:/home \
	--bind /sys/fs/cgroup/cpu,cpuacct/machine.slice/machine-slave.scope:/sys/fs/cgroup/cpu,cpuacct \
	--bind /sys/fs/cgroup/memory/machine.slice/machine-slave.scope:/sys/fs/cgroup/memory \
	--bind /sys/fs/cgroup/freezer/machine.slice/machine-slave.scope:/sys/fs/cgroup/freezer \
	--bind /sys/fs/cgroup/net_cls,net_prio/machine.slice/machine-slave.scope:/sys/fs/cgroup/net_cls,net_prio \
	--bind /sys/fs/cgroup/perf_event/machine.slice/machine-slave.scope:/sys/fs/cgroup/perf_event \
	--network-bridge=docker0
