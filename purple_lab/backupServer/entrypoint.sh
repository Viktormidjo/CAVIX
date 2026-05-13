#!/bin/bash

# Avslutt skriptet hvis noe feiler
set -e

# Sørger for at sshd har nødvendig runtime-mappe
mkdir -p /var/run/sshd

# Starter rsyslog slik at serveren sender logger til Graylog
rsyslogd

# Starter SSH-serveren som hovedprosess
exec /usr/sbin/sshd -D -e
