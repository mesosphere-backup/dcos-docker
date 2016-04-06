FROM centos:7

RUN yum install -y \
	aufs-tools \
	bash-completion \
	btrfs-progs \
	ca-certificates \
	curl \
	git \
	iproute \
	ipset \
	iptables \
	libcgroup \
	libselinux-utils \
	nano \
	net-tools \
	openssh-client \
	openssh-server \
	sudo \
	systemd \
	tree \
	unzip \
	xz \
	&& ( \
		cd /lib/systemd/system/sysinit.target.wants/; \
		for i in *; do \
			if [ "$i" != "systemd-tmpfiles-setup.service" ]; then \
				rm -f $i; \
			fi \
		done \
	) \
	&& rm -f /lib/systemd/system/multi-user.target.wants/* \
	&& rm -f /etc/systemd/system/*.wants/* \
	&& rm -f /lib/systemd/system/local-fs.target.wants/* \
	&& rm -f /lib/systemd/system/sockets.target.wants/*udev* \
	&& rm -f /lib/systemd/system/sockets.target.wants/*initctl* \
	&& rm -f /lib/systemd/system/anaconda.target.wants/* \
	&& rm -f /lib/systemd/system/basic.target.wants/* \
	&& rm -f /lib/systemd/system/graphical.target.wants/* \
	&& ln -vf /lib/systemd/system/multi-user.target /lib/systemd/system/default.target

ENV DIND_COMMIT 3b5fac462d21ca164b3778647420016315289034
ENV DOCKER_VERSION 1.10.3
ENV TERM xterm
ENV LANG en_US.UTF-8

# install dind and docker
RUN curl -sSL "https://raw.githubusercontent.com/docker/docker/${DIND_COMMIT}/hack/dind" -o /usr/local/bin/dind \
	&& curl -sSL "https://get.docker.com/builds/Linux/x86_64/docker-${DOCKER_VERSION}" -o /usr/bin/docker \
	&& chmod +x /usr/bin/docker \
	&& chmod +x /usr/local/bin/dind \
	&& groupadd -r nogroup \
	&& groupadd -r docker \
	&& gpasswd -a "root" docker \
	&& rm -f /etc/securetty \
	&& ln -vf /bin/true /usr/sbin/modprobe

COPY genconf /genconf
COPY include/systemd/docker.service /lib/systemd/system/
COPY include/ssh /root/.ssh
RUN cp /root/.ssh/id_*.pub /root/.ssh/authorized_keys

# systemd needs a different stop signal
STOPSIGNAL SIGRTMIN+3

ENTRYPOINT ["dind"]
CMD ["/sbin/init"]
