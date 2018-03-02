FROM centos:7

RUN yum install -y \
		bash-completion \
		bind-utils \
		btrfs-progs \
		ca-certificates \
		curl \
		git \
		iproute \
		ipset \
		iptables \
		iputils \
		libcgroup \
		libselinux-utils \
		nano \
		net-tools \
		openssh-client \
		openssh-server \
		sudo \
		systemd \
		tar \
		tree \
		unzip \
		vim \
		which \
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

COPY include/systemd/systemd-journald-init.service /lib/systemd/system/
RUN systemctl enable systemd-journald-init.service || true

RUN curl --fail --location --silent --show-error --output "jq-linux64" "https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64" && \
    sha256sum jq-linux64 | grep -q c6b3a7d7d3e7b70c6f51b706a3b90bd01833846c54d32ca32f0027f00226ff6d && \
    chmod a+x jq-linux64 && \
    mv jq-linux64 /usr/sbin/jq

# systemd needs a different stop signal
STOPSIGNAL SIGRTMIN+3
CMD ["/sbin/init"]
