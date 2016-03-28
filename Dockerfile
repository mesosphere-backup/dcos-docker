FROM centos:7

RUN yum install -y \
	aufs-tools \
	btrfs-progs \
	ca-certificates \
	curl \
	git \
	iptables \
	openssh-client \
	openssh-server \
	libselinux-utils \
	sudo \
	systemd \
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

# install dind and docker
RUN curl -sSL "https://raw.githubusercontent.com/docker/docker/${DIND_COMMIT}/hack/dind" -o /usr/local/bin/dind \
	&& curl -sSL "https://get.docker.com/builds/Linux/x86_64/docker-${DOCKER_VERSION}" -o /usr/bin/docker \
	&& chmod +x /usr/local/bin/dind \
	&& chmod +x /usr/bin/docker \
	&& groupadd -r nogroup \
	&& groupadd docker \
	&& gpasswd -a "root" docker \
	&& rm -f /etc/securetty

COPY genconf /genconf
COPY dcos_generate_config.ee.sh /
COPY docker.service /lib/systemd/system/
COPY ssh /root/.ssh
RUN cp /root/.ssh/id_rsa.pub /root/.ssh/authorized_keys

RUN systemctl enable docker.service

ENTRYPOINT ["dind"]
CMD ["/sbin/init"]
