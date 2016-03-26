#!/bin/bash -xe
sudo systemd-nspawn -D slave -b --bind-ro=/usr/bin/docker:/usr/bin/docker --bind=/var/run/docker.sock:/var/run/docker.sock --bind-ro=/bin/true:/usr/sbin/modprobe --network-bridge=docker0
