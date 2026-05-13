#!/bin/bash
set -e		# Avslutt skriptet hvis noe feiler


# Generer SSH-nøkkel hvis den ikke finnes
if [ ! -f /root/.ssh/id_rsa ]; then
    ssh-keygen -t rsa -b 2048 -f /root/.ssh/id_rsa -N '' -q
fi

# Holder containerern kjørende slik at angriperen kan brukes interaktivt
sleep infinity
