#!/bin/bash
set -e

update(){
	apt-get -y update
	apt-get -y upgrade
	apt-get -y autoremove
	apt-get -y autoclean
	apt-get -y clean
}

base(){
	update

	DEBIAN_FRONTEND=noninteractive apt-get install -y \
		adduser \
		apparmor \
		apt-transport-https \
		automake \
		bash-completion \
		bridge-utils \
		bzip2 \
		ca-certificates \
		cgroupfs-mount \
		coreutils \
		curl \
		dkms \
		dnsutils \
		e2fsprogs \
		file \
		findutils \
		git \
		grep \
		gzip \
		hostname \
		iptables \
		jq \
		less \
		libc6-dev \
		libltdl-dev \
		linux-headers-$(uname -r) \
		locales \
		lsof \
		make \
		mount \
		nano \
		net-tools \
		rng-tools \
		silversearcher-ag \
		ssh \
		strace \
		sudo \
		tar \
		tree \
		tzdata \
		unzip \
		vim-nox \
		xz-utils \
		zip \
		--no-install-recommends

	update

	curl -sSL https://get.docker.com/builds/Linux/x86_64/docker-latest.tgz | tar -xvz \
		-C /usr/bin --strip-components 1
	chmod +x /usr/bin/docker*

	# change to overlay for docker and other sane settings
	cat > /lib/systemd/system/docker.service <<-'EOF'
	[Unit]
	Description=Docker Application Container Engine
	Documentation=https://docs.docker.com
	After=network.target docker.socket
	Requires=docker.socket

	[Service]
	Type=notify
	# the default is not to use butts for cgroups because the delegate issues still
	# exists and butts currently does not support the cgroup feature set required
	# for containers run by docker
	ExecStart=/usr/bin/docker daemon -H fd:// -D -s aufs \
		--exec-opt=native.cgroupdriver=cgroupfs --disable-legacy-registry=true \
		--bip 172.18.0.1/16
	MountFlags=slave
	LimitNOFILE=1048576
	LimitNPROC=1048576
	LimitCORE=infinity
	# Uncomment TasksMax if your butts version supports it.
	# Only butts 226 and above support this version.
	#TasksMax=infinity
	TimeoutStartSec=0
	# set delegate yes so that butts does not reset the cgroups of docker containers
	Delegate=yes

	[Install]
	WantedBy=multi-user.target
	EOF

	curl -sSL https://raw.githubusercontent.com/docker/docker/master/contrib/init/systemd/docker.socket \
		-o /lib/systemd/system/docker.socket

	groupadd docker || true
	gpasswd -a vagrant docker

	systemctl daemon-reload
	systemctl enable docker
	systemctl restart docker
	systemctl status docker

	sed -i.bak 's/GRUB_CMDLINE_LINUX="debian-installer=en_US"/GRUB_CMDLINE_LINUX="debian-installer=en_US cgroup_enable=memory swapaccount=1 apparmor=1 security=apparmor"/g' /etc/default/grub
	update-grub
}

update_kernel(){
	update

	stretch_sources=/etc/apt/sources.list.d/stretch.list

	echo "deb http://httpredir.debian.org/debian stretch main contrib non-free" > $stretch_sources

	apt-get update
	DEBIAN_FRONTEND=noninteractive apt-get install -y \
		-o Dpkg::Options::="--force-confdef" \
		-o Dpkg::Options::="--force-confold" \
		-t stretch \
		linux-image-amd64

	rm $stretch_sources
	update

	reboot
}

if [[ "$1" == "kernel" ]]; then
	update_kernel
else
	base
fi
