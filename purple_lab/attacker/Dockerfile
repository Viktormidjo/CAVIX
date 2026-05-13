FROM kalilinux/kali-rolling

# Installerer verktøy for scanning, bruteforce, SMB, nettverk og python
RUN apt-get update -qq && \
    apt-get install -y -qq \
      nmap \
      hydra \
      sshpass \
      smbclient \
      smbmap \
      curl \
      zip \
      iproute2 \
      iputils-ping \
      netcat-openbsd \
      openssh-client \
      python3 \
      python3-pip \
      ncat \
      libcap2-bin && \
    setcap -r /usr/lib/nmap/nmap 2>/dev/null || true && \
    pip3 install impacket --break-system-packages -q 2>/dev/null || true && \
    rm -rf /var/lib/apt/lists/*


# Opprett arbeidsmappe og SSH-mappe
RUN mkdir -p /workspace /root/.ssh

# Kopier skripts og arbeidsfiler
COPY workspace/ /workspace/
COPY entrypoint.sh /entrypoint.sh

# Gjør skripts kjørbare
RUN chmod +x /entrypoint.sh /workspace/angrep.sh

# Start entrypoint-skriptet
CMD ["/entrypoint.sh"]
