FROM graylog/graylog:6.0

# Bytt til root for å installere ekstra verktøy
USER root

# Installer curl for provisioning skriptet
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends curl && \
    rm -rf /var/lib/apt/lists/*

# Kopier provisioning-skript som setter opp inputs, streams
COPY provision.sh /provision.sh
RUN chmod +x /provision.sh

# Overstyrer standard entrypoint slik at kun vårt skript kjører
ENTRYPOINT []

# Kjør provisioning-skriptet ved containerstart
CMD ["/provision.sh"]
