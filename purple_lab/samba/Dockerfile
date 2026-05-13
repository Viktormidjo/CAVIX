FROM debian:12-slim

# Installer Samba, SMB-klient og rsyslog for logg-forwarding
RUN apt update && \
    apt install -y samba smbclient rsyslog && \
    rm -rf /var/lib/apt/lists/*

# Opprett tre brukere som representerer ulike roller i organisasjonen
# Alle uten shell (nologin) for å begrense tilgang
RUN groupadd smbusers && \
    useradd -M -s /usr/sbin/nologin user && \
    useradd -M -s /usr/sbin/nologin admin && \
    useradd -M -s /usr/sbin/nologin oldadmin && \
    usermod -aG smbusers user && \
    usermod -aG smbusers admin && \
    usermod -aG smbusers oldadmin

# Opprett delte mapper for Samba-skripts og logging
RUN mkdir -p /mount/public /mount/sensitive /etc/samba/scripts /run/samba /var/log/samba

# Kopierer Samba-konfig, entrypoint og rsyslog-oppsett
COPY smb.conf /etc/samba/smb.conf
COPY entrypoint.sh /entrypoint.sh
COPY 50-forward.conf /etc/rsyslog.d/50-forward.conf
COPY rsyslog-samba.conf /etc/rsyslog.d/rsyslog-samba.conf

RUN chmod +x /entrypoint.sh

# Eksponer SMB-port
EXPOSE 445

# Start Samba via entrypoint
CMD ["/entrypoint.sh"]
