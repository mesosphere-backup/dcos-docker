FROM mesosphere/dcos-docker:base

ENV DIND_COMMIT 3b5fac462d21ca164b3778647420016315289034
ENV DOCKER_VERSION 1.10.3
ENV TERM xterm
ENV LANG en_US.UTF-8

# install dind and docker
RUN curl -sSL "https://raw.githubusercontent.com/docker/docker/${DIND_COMMIT}/hack/dind" -o /usr/local/bin/dind \
	&& curl -sSL "https://get.docker.com/builds/Linux/x86_64/docker-${DOCKER_VERSION}" -o /usr/bin/docker \
	&& curl -sSL "https://raw.githubusercontent.com/docker/docker/master/contrib/completion/bash/docker" -o /etc/bash_completion.d/docker \
	&& chmod +x /usr/bin/docker \
	&& chmod +x /usr/local/bin/dind \
	&& groupadd -r nogroup || true \
	&& groupadd -r docker \
	&& gpasswd -a "root" docker \
	&& rm -f /etc/securetty \
	&& ln -vf /bin/true /usr/sbin/modprobe

# systemd needs a different stop signal
STOPSIGNAL SIGRTMIN+3

COPY include/systemd/docker.service /lib/systemd/system/
RUN systemctl enable docker.service \
	&& systemctl enable sshd.service || true

COPY genconf /genconf
COPY include/ssh /root/.ssh
RUN cp /root/.ssh/id_*.pub /root/.ssh/authorized_keys

ENTRYPOINT ["dind"]
CMD ["/sbin/init"]
