FROM python:3.11-slim

# Installer rsyslog slik at applikasjonen kan sende logger til Graylog
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends rsyslog && \
    rm -rf /var/lib/apt/lists/*

# Sett arbeidskatalog for applikasjonen
WORKDIR /app

# Installer Python-avhengigheter
COPY requirements.txt .
RUN pip install -r requirements.txt

# Kopier applikasjonen og tilhørende ressurser, rsyslog-konfig, entrypoint
COPY app.py .
COPY templates/ templates/
COPY static/ static/
COPY 50-forward.conf /etc/rsyslog.d/50-forward.conf
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Start webapplikasjonen
CMD ["/entrypoint.sh"]
