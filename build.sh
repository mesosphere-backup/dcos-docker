#!/bin/bash -xe

#docker pull centos:centos7
#docker run -i -t --name=centos7 centos:centos7 /bin/true
#docker rm -f centos7 || true
#docker export "$(docker create --name centos7 centos:centos7 /bin/true)" > centos7.tar

sudo rm -rf boot master slave

mkdir -p boot
sudo tar -x -C boot -f centos7.tar
echo -ne 'secret123\nsecret123\n' | sudo chroot boot passwd root
sudo mkdir -p boot/etc/systemd/network
sudo tee boot/etc/resolv.conf > /dev/null <<EOF
nameserver 8.8.8.8
EOF
sudo chroot boot yum install -y libseccomp openssh-server iproute systemd-networkd sudo openssh-clients libselinux-utils wget git unzip curl xz ipset net-tools nano
sudo chroot boot systemctl mask systemd-remount-fs.service network.service rhel-dmesg.service
sudo chroot boot systemctl enable systemd-networkd.service sshd.service
sudo chroot boot groupadd -r nogroup
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
