FROM ubuntu:22.04


#installerer nødvendige verktøy for SSH, backup, logging, drift
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      openssh-server \			
      sudo \				
      smbclient \			
      sshpass \				
      cron \				
      rsyslog \				
      iproute2 \			
      net-tools \			
      curl \				
      iputils-ping \			
      python3 \				
      zip && \				
    rm -rf /var/lib/apt/lists/*		


# Opprett brukere med passord
RUN useradd -m -s /bin/bash drift && \
    echo 'drift:Aq9!sT4#Lm2@vX8$Pr7&bF1*Zw5%Kd3^Hn0' | chpasswd && \
    useradd -m -s /bin/bash ola_nordmann && \
    echo 'ola_nordmann:Stjernevegen10' | chpasswd


# Gir drift-bruker begrenset sudo-rettighet til kun python3
RUN echo "drift ALL=(ALL) NOPASSWD: /usr/bin/python3" > /etc/sudoers.d/drift && \
    chmod 440 /etc/sudoers.d/drift
 
# Opprett mapper for SSH og scripts
RUN mkdir -p /opt/scripts /run/sshd

# Kopierer inn backupscript, config, bash-historikk og entrypoint
COPY smb-backup.sh /opt/scripts/smb-backup.sh
COPY backup.conf /etc/backup.conf
COPY drift_bash_history /home/drift/.bash_history
COPY entrypoint.sh /entrypoint.sh
COPY ola_nordmann/ /home/ola_nordmann/
COPY 50-forward.conf /etc/rsyslog.d/50-forward.conf

# Sett riktige rettigheter
RUN chmod 700 /opt/scripts/smb-backup.sh && \
    chmod 600 /etc/backup.conf && \
    chmod +x /entrypoint.sh && \
    chown -R drift:drift /home/drift && \
    chown -R ola_nordmann:ola_nordmann /home/ola_nordmann

# Cron-jobb som kjører backup hvert minutt
RUN echo "* * * * * root /opt/scripts/smb-backup.sh" > /etc/cron.d/backup && \
    chmod 644 /etc/cron.d/backup

# Eksponerer SSH-port
EXPOSE 22

# Start entrypoint
CMD ["/entrypoint.sh"]

