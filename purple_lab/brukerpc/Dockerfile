FROM ubuntu:22.04

# Installerer grunnleggende verktøy for nettverk, SMB og logg-forwarding
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      smbclient \
      rsyslog \ 
      curl \
      iproute2 \
      net-tools \
      iputils-ping && \
    rm -rf /var/lib/apt/lists/*

# Entrypoint og rsyslog-konfig
COPY entrypoint.sh /entrypoint.sh
COPY 50-forward.conf /etc/rsyslog.d/50-forward.conf

RUN chmod +x /entrypoint.sh

# Start bruker-PCen
CMD ["/entrypoint.sh"]
