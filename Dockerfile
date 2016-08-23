FROM mesosphere/dcos-docker:base

ENV DOCKER_VERSION 1.11.2
ENV TERM xterm
ENV LANG en_US.UTF-8

# install dind and docker
RUN curl -sSL "https://get.docker.com/builds/Linux/x86_64/docker-${DOCKER_VERSION}.tgz" | tar xvzf - -C /usr/bin/ --strip 1 \
	&& curl -sSL "https://raw.githubusercontent.com/docker/docker/master/contrib/completion/bash/docker" -o /etc/bash_completion.d/docker \
	&& chmod +x /usr/bin/docker* \
	&& groupadd -r nogroup || true \
	&& groupadd -r docker || true \
	&& gpasswd -a "root" docker || true \
	&& rm -f /etc/securetty \
	&& ln -vf /bin/true /usr/sbin/modprobe \
	&& ln -vf /bin/true /sbin/modprobe

# systemd needs a different stop signal
STOPSIGNAL SIGRTMIN+3

COPY include/systemd/docker.service /lib/systemd/system/
RUN systemctl enable docker.service \
	&& systemctl enable sshd.service || true

COPY include/sbin/dcos-postflight /usr/local/sbin/

COPY genconf /genconf
COPY include/ssh /root/.ssh
RUN cp /root/.ssh/id_*.pub /root/.ssh/authorized_keys

CMD ["/sbin/init"]
