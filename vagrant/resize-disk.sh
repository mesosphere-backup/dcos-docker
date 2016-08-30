#!/usr/bin/env bash

# Resize a Centos 7 VirtualBox disk... the hard way
# Currently only support _increasing_ the size of the dcos-docker volume.

set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

vagrant up
vagrant halt

# Disk size in MB (default 100GB)
DISK_SIZE=${1:-102400}

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE}")/.." && pwd)"

MACHINE_NAME="dcos-docker"
MACHINE_DIR="${HOME}/VirtualBox VMs/${MACHINE_NAME}"

cd "${MACHINE_DIR}"

OLD_DISK_FILE="$(VBoxManage showvminfo "${MACHINE_NAME}" | grep '.vmdk' | sed "s:.*\\${MACHINE_NAME}/\(.*.vmdk\).*:\1:")"

TEMP_FILE="$(mktemp centos-disk1.XXXXXXXX)"
rm "${TEMP_FILE}"

TEMP_DISK_FILE="temp-${TEMP_FILE}.vdi"
NEW_DISK_FILE="${TEMP_FILE}.vmdk"

# If the following steps fail, you may need to nuke your vbox disks:
# VBoxManage list hdds | grep "^UUID:" | sed 's/UUID:[ \t]*//' | xargs -n1 VBoxManage closemedium disk

# Reformat to VDI, resize, reformat back to VMDK, and delete old/temp disks
VBoxManage clonehd "${OLD_DISK_FILE}" "${TEMP_DISK_FILE}" --format vdi
VBoxManage modifyvm "${MACHINE_NAME}" --hda none
VBoxManage closemedium disk "${OLD_DISK_FILE}" --delete
VBoxManage modifyhd "${TEMP_DISK_FILE}" --resize ${DISK_SIZE}
VBoxManage clonehd "${TEMP_DISK_FILE}" "${NEW_DISK_FILE}" --format vmdk
VBoxManage closemedium disk "${TEMP_DISK_FILE}" --delete

CONTROLLER_NAME="$(VBoxManage showvminfo "${MACHINE_NAME}" | grep 'Storage Controller Name' | sed 's/Storage Controller Name (0):[ \t]*//')"

# Attach new disk as the primary storage device
VBoxManage storageattach "${MACHINE_NAME}" --storagectl "${CONTROLLER_NAME}" --port 0 --device 0 --type hdd --medium "${NEW_DISK_FILE}"

cd "${PROJECT_ROOT}"

vagrant up

# Repartition and reformat
# Requires passwordless login (ssh key)
vagrant ssh << EOFOUTER
set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

# Requires passwordless sudo
sudo su -

# Programmatically script fdisk input.
# The sed script strips the comments, which are present for maintainability.
# Blank lines will use the default option.
# TODO: find a way to ignore 'ioctl' error without ignoring all errors
sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF | fdisk /dev/sda || true
  n # new partition
  p # primary partition
  3 # partition number 3
    # default - start at beginning of disk
    # default - extend partition to end of disk
  t # change partition type
  3 # partition number 3
  8e # set to Linux LVM (hex code)
  p # print the in-memory partition table
  w # write the partition table and quit
EOF

# Refresh disk partition without rebooting
partprobe

# Create physical volume from partition
pvcreate /dev/sda3

# Add the new physical volume to the centos volume group
vgextend centos /dev/sda3

# Resize the root logical volume to include the new space
lvextend -l +100%FREE /dev/mapper/centos-root

# Grow the root file-system to fit the logical volume
xfs_growfs /dev/centos/root

# Print new disk sizes (root & boot are xfs on centos)
df -h -t xfs
EOFOUTER
