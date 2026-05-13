#!/bin/bash
set -e		# Stopp skriptet hvis en kommando feiler

# Aktiver passordinnlogging for SSH
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config

# sshd får nødvendig runtime-mappe
mkdir -p /run/sshd

# starter cron for å kjøre backup-jobben
service cron start

# Start rsyslog for å sende logger til Graylog
rsyslogd

# Start SSH-serveren og den kjører som hovedprosessen
exec /usr/sbin/sshd -D -e
