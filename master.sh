#!/bin/bash -xe
sudo systemd-nspawn -D master -b --bind-ro=/usr/bin/docker:/usr/bin/docker --bind=/var/run/docker.sock:/var/run/docker.sock --bind-ro=/bin/true:/usr/sbin/modprobe --bind=/home:/home --network-bridge=docker0
