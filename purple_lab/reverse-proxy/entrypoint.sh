#!/bin/bash

# Stopper skriptet hvis noe feiler
set -e

# sshd får nødvendig runtime-mappe
mkdir -p /run/sshd

# Sikrer at root ikke kan logge inn, og at passordinnlogging er aktivert
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Tester nginx-konfigurasjonen før oppstart
nginx -t
nginx

# Starter rsyslog slik at reverse-proxy sender logger til Graylog
rsyslogd

# Starter SSH-serveren som hovedprosess
exec /usr/sbin/sshd -D -e
