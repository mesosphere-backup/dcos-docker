FROM ubuntu:xenial

RUN apt-get update \
	&& apt-get install -y \
		aufs-tools \
		bash-completion \
		btrfs-tools \
		ca-certificates \
		curl \
		debianutils \
		dbus \
		gawk \
		git \
		iproute \
		ipset \
		iptables \
		iputils-ping \
		libcgroup-dev \
		libpopt0 \
		nano \
		net-tools \
		openssh-client \
		openssh-server \
		sudo \
		systemd \
		tar \
		tree \
		unzip \
		vim-nox \
		xz-utils \
	&& rm -rf /var/lib/apt/lists/* \
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
RUN ln -s /bin/mkdir /usr/bin/mkdir
RUN ln -s /bin/ln /usr/bin/ln
RUN ln -s /bin/tar /usr/bin/tar
RUN ln -s /usr/sbin/useradd /usr/bin/useradd
RUN ln -s /usr/sbin/groupadd /usr/bin/groupadd
RUN ln -s /bin/systemd-tmpfiles /usr/bin/systemd-tmpfiles

COPY include/systemd/systemd-journald-init.service /lib/systemd/system/
RUN systemctl enable systemd-journald-init.service || true

RUN curl --fail --location --silent --show-error --output "jq-linux64" "https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64" && \
    sha256sum jq-linux64 | grep -q c6b3a7d7d3e7b70c6f51b706a3b90bd01833846c54d32ca32f0027f00226ff6d && \
    chmod a+x jq-linux64 && \
    mv jq-linux64 /usr/sbin/jq

# systemd needs a different stop signal
STOPSIGNAL SIGRTMIN+3
CMD ["/sbin/init"]
