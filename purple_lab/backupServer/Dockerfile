FROM ubuntu:22.04


# Installerer SSH-server og rsyslog for logg-forwarding
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      openssh-server \
      rsyslog && \
    rm -rf /var/lib/apt/lists/*

# Opprett backup-bruker
RUN useradd -m -s /bin/bash backupuser && \
    echo "backupuser:Backup123" | chpasswd

# Opprett mappe for opplastede backupfiler
RUN mkdir -p /data && chown backupuser:backupuser /data

# Skript som begrenser brukeren til kun SCP (ingen shell)
COPY scp-only /usr/local/bin/scp-only


# Konfigurer SSH for sikker, begrenset tilgang
RUN chmod +x /usr/local/bin/scp-only && \
    mkdir -p /var/run/sshd && \
    sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config && \
    echo "" >> /etc/ssh/sshd_config && \
    echo "Match User backupuser" >> /etc/ssh/sshd_config && \
    echo "    ForceCommand /usr/local/bin/scp-only" >> /etc/ssh/sshd_config && \
    echo "    AllowTcpForwarding no" >> /etc/ssh/sshd_config && \
    echo "    X11Forwarding no" >> /etc/ssh/sshd_config && \
    echo "    PermitTTY no" >> /etc/ssh/sshd_config

# Forward logger til Graylog og entrypoint som starter SSH og rsyslog
COPY 50-forward.conf /etc/rsyslog.d/50-forward.conf
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Eksponerer SSH-port
EXPOSE 22

# Start backupserveren
CMD ["/entrypoint.sh"]
