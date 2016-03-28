#!/bin/bash -xe

#docker pull centos:centos7
#docker export "$(docker create --name centos7 centos:centos7 /bin/true)" > centos7.tar

#docker pull fedora:23
#docker export "$(docker create --name f23 fedora:23 /bin/true)" > f23.tar

sudo rm -rf master slave

mkdir -p boot
sudo tar -x -C boot -f centos7.tar
#sudo tar -x -C boot -f f23.tar

#PKGMGR=/usr/bin/dnf
PKGMGR=/usr/bin/yum

sudo mkdir -p boot/etc/systemd/network
sudo tee boot/etc/resolv.conf > /dev/null <<EOF
nameserver 8.8.8.8
EOF

sudo systemd-nspawn -D boot $PKGMGR install -y libseccomp openssh-server iproute systemd-networkd sudo openssh-clients libselinux-utils wget git unzip curl xz ipset net-tools nano passwd
#sudo systemd-nspawn -q -D boot $PKGMGR install -y libseccomp openssh-server iproute sudo openssh-clients libselinux-utils wget git unzip curl xz ipset net-tools nano passwd

echo secret123 | sudo chroot boot passwd root --stdin
sudo systemd-nspawn -q -D boot systemctl mask systemd-remount-fs.service network.service rhel-dmesg.service
sudo systemd-nspawn -q -D boot systemctl enable systemd-networkd.service sshd.service
sudo systemd-nspawn -q -D boot groupadd -r nogroup
sudo systemd-nspawn -q -D boot rm -f /etc/securetty

sudo mkdir -p boot/root/.ssh && sudo chmod 700 boot/root/.ssh && sudo cp id_rsa.pub boot/root/.ssh/authorized_keys

sudo cp -a boot master
sudo tee master/etc/systemd/network/master.network > /dev/null <<EOF
[Match]
Name=host0
[Network]
DNS=8.8.8.8
Address=172.17.0.100/24
Gateway=172.17.0.1
EOF

sudo cp -a boot slave
sudo tee slave/etc/systemd/network/slave.network > /dev/null <<EOF
[Match]
Name=host0
[Network]
DNS=8.8.8.8
Address=172.17.0.101/24
Gateway=172.17.0.1
EOF
