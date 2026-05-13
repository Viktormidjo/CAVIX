FROM mongo:6.0

# Kopierer forhåndslagret Graylog-dump (brukes til å slippe setup)
COPY graylog.dump /graylog.dump

# Init-skriptet som importerer databasen ved container-start
COPY init.sh /init.sh
RUN chmod +x /init.sh

# kjør init-skriptet som hovedprosess
CMD ["/init.sh"]
