FROM quay.io/shift/coreos:stable-1298.7.0


COPY include/systemd/systemd-journald-init.service /lib/systemd/system/
RUN systemctl enable systemd-journald-init.service || true

RUN curl --fail --location --silent --show-error --output "jq-linux64" "https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64" && \
    sha256sum jq-linux64 | grep -q c6b3a7d7d3e7b70c6f51b706a3b90bd01833846c54d32ca32f0027f00226ff6d && \
    chmod a+x jq-linux64 && \
    mv jq-linux64 /usr/sbin/jq

# systemd needs a different stop signal
STOPSIGNAL SIGRTMIN+3
CMD ["/sbin/init"]
