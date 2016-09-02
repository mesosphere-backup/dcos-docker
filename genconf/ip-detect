#!/bin/bash -e
/sbin/ip -4 -o addr show dev eth0 | awk '{split($4,a,"/");print a[1]}'
