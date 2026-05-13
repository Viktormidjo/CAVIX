FROM ubuntu:22.04

# Installer nginx, SSH, nettverksverktøy og rsyslog for logg-forwarding
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends nginx openssh-server iproute2 net-tools rsyslog ca-certificates && \
    rm -rf /var/lib/apt/lists/* && echo "AllowTcpForwarding yes" >> /etc/ssh/sshd_config

# Gammel, glemt admin-konto (standardpassord)
RUN useradd -m -s /bin/bash webadmin && \
    echo 'webadmin:admin' | chpasswd && \
    mkdir -p /run/sshd

# Ny faktisk admin-konto (sterkt passord)
RUN useradd -m -s /bin/bash driftadmin && \
    echo 'driftadmin:EtSterktPassord123!#' | chpasswd

# Konfigurasjon for nginx, rsyslog og oppstartsskript
COPY nginx.conf /etc/nginx/nginx.conf
COPY entrypoint.sh /entrypoint.sh
COPY 50-forward.conf /etc/rsyslog.d/50-forward.conf

RUN chmod +x /entrypoint.sh

# Eksponer HTTP og SSH
EXPOSE 80 22

# Start reverse-proxyen
CMD ["/entrypoint.sh"]
