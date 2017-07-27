FROM mesosphere/dcos-docker:base

ENV DOCKER_VERSION 1.13.1
ENV TERM xterm
ENV LANG en_US.UTF-8

# install dind and docker
RUN curl -sSL --fail "https://get.docker.com/builds/Linux/x86_64/docker-${DOCKER_VERSION}.tgz" | tar xvzf - -C /usr/bin/ --strip 1 \
	&& curl -sSL --fail "https://raw.githubusercontent.com/docker/docker/v1.13.1/contrib/completion/bash/docker" -o /etc/bash_completion.d/docker \
	&& chmod +x /usr/bin/docker* \
	&& groupadd -r nogroup || true \
	&& groupadd -r docker || true \
	&& gpasswd -a "root" docker || true \
	&& rm -f /etc/securetty \
	&& ln -vf /bin/true /usr/sbin/modprobe \
	&& ln -vf /bin/true /sbin/modprobe

COPY include/systemd/docker.service /lib/systemd/system/
RUN systemctl enable docker.service || true
