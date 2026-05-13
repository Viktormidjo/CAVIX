#!/bin/bash

# Stopper skriptet hvis noe feiler
set -e

# Starter rsyslog slik at klienten sender logger til Graylog
rsyslogd

# Holder containeren kjørende som en passiv bruker-PC
sleep infinity
