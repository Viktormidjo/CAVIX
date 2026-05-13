#!/bin/bash

# Stopper skriptet hvis noe feiler
set -e

# Starter rsyslog slik at webapplikasjonen sender logger til Graylog
rsyslogd

# Starter Python-applikasjonen som hovedprosess
exec python app.py
