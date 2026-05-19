FROM ubuntu:22.04

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      iproute2 \
      iptables \
      iputils-ping \
      net-tools \
      rsyslog && \
    rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /entrypoint.sh
COPY 50-forward.conf /etc/rsyslog.d/50-forward.conf

RUN chmod +x /entrypoint.sh

CMD ["/entrypoint.sh"]
