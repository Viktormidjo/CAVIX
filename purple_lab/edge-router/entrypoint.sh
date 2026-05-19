#!/bin/bash
set -e

# Aktiver ruting mellom nettverk
sysctl -w net.ipv4.ip_forward=1

# Nullstill gamle regler
iptables -F
iptables -t nat -F

# Blacklist-modell:
# Standard er at forwarding er tillatt.
iptables -P FORWARD ACCEPT

# DNS-/ekstern-adresse-simulering:
# Trafikk mot edge-routerens frontend-IP sendes videre til reverse-proxy.
iptables -t nat -A PREROUTING -p tcp -d 172.20.0.254 --dport 80 \
  -j DNAT --to-destination 172.21.0.10:80

# SSH er "glemt blokkert".
# Derfor videresendes også port 22 til reverse-proxy.
iptables -t nat -A PREROUTING -p tcp -d 172.20.0.254 --dport 22 \
  -j DNAT --to-destination 172.21.0.10:22

# Sørg for at returtrafikk fungerer
iptables -t nat -A POSTROUTING -s 172.20.0.0/24 -d 172.21.0.10 \
  -j MASQUERADE

# Blokker direkte tilgang fra frontend til andre backend-maskiner
iptables -A FORWARD -s 172.20.0.0/24 -d 172.21.0.20 -j DROP  # webapp
iptables -A FORWARD -s 172.20.0.0/24 -d 172.21.0.30 -j DROP  # db
iptables -A FORWARD -s 172.20.0.0/24 -d 172.21.0.40 -j DROP  # drift-pc

# Blokker utvalgte porter mot reverse-proxy,
# men SSH/22 er ikke blokkert og blir derfor tilgjengelig.
iptables -A FORWARD -s 172.20.0.0/24 -d 172.21.0.10 -p tcp --dport 3306 -j DROP
iptables -A FORWARD -s 172.20.0.0/24 -d 172.21.0.10 -p tcp --dport 445 -j DROP
iptables -A FORWARD -s 172.20.0.0/24 -d 172.21.0.10 -p tcp --dport 8080 -j DROP

# Tillat etablert returtrafikk
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Start logging
rsyslogd

# Hold containeren i live
tail -f /dev/null
