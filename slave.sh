#!/bin/bash -xe

sudo mkdir -p /sys/fs/cgroup/blkio/machine.slice/machine-slave.scope
sudo mkdir -p /sys/fs/cgroup/cpu,cpuacct/machine.slice/machine-slave.scope
sudo mkdir -p /sys/fs/cgroup/cpuset/machine.slice/machine-slave.scope
sudo mkdir -p /sys/fs/cgroup/devices/machine.slice/machine-slave.scope
sudo mkdir -p /sys/fs/cgroup/freezer/machine.slice/machine-slave.scope
sudo mkdir -p /sys/fs/cgroup/hugetlb/machine.slice/machine-slave.scope
sudo mkdir -p /sys/fs/cgroup/memory/machine.slice/machine-slave.scope
sudo mkdir -p /sys/fs/cgroup/net_cls,net_prio/machine.slice/machine-slave.scope
sudo mkdir -p /sys/fs/cgroup/perf_event/machine.slice/machine-slave.scope

sudo systemd-nspawn \
	-b \
	-D slave \
	--bind-ro=/bin/true:/usr/sbin/modprobe \
	--bind=/home:/home \
	--bind /sys/fs/cgroup/blkio/machine.slice/machine-slave.scope:/sys/fs/cgroup/blkio \
	--bind /sys/fs/cgroup/cpu,cpuacct/machine.slice/machine-slave.scope:/sys/fs/cgroup/cpu,cpuacct \
	--bind /sys/fs/cgroup/cpuset/machine.slice/machine-slave.scope:/sys/fs/cgroup/cpuset \
	--bind /sys/fs/cgroup/devices/machine.slice/machine-slave.scope:/sys/fs/cgroup/devices \
	--bind /sys/fs/cgroup/freezer/machine.slice/machine-slave.scope:/sys/fs/cgroup/freezer \
	--bind /sys/fs/cgroup/hugetlb/machine.slice/machine-slave.scope:/sys/fs/cgroup/hugetlb \
	--bind /sys/fs/cgroup/memory/machine.slice/machine-slave.scope:/sys/fs/cgroup/memory \
	--bind /sys/fs/cgroup/net_cls,net_prio/machine.slice/machine-slave.scope:/sys/fs/cgroup/net_cls,net_prio \
	--bind /sys/fs/cgroup/perf_event/machine.slice/machine-slave.scope:/sys/fs/cgroup/perf_event \
	--network-bridge=docker0
