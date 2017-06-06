FROM mesosphere/dcos-docker:base-docker

RUN systemctl enable sshd.service || true

COPY include/sbin/dcos-postflight /usr/local/sbin/
COPY genconf /genconf
COPY include/ssh /root/.ssh
RUN cp /root/.ssh/id_*.pub /root/.ssh/authorized_keys
