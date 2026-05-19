#!/bin/bash
set -e

# Aktiver IPv4 forwarding
sysctl -w net.ipv4.ip_forward=1

# drift-pc til internal
iptables -A FORWARD -s 172.21.0.40 -d 172.22.0.0/24 -j ACCEPT
iptables -t nat -A POSTROUTING -s 172.21.0.40 -d 172.22.0.0/24 -j MASQUERADE

# drift-pc til backup-nett
iptables -A FORWARD -s 172.21.0.40 -d 172.23.0.0/24 -j ACCEPT
iptables -t nat -A POSTROUTING -s 172.21.0.40 -d 172.23.0.0/24 -j MASQUERADE


# Videresend syslog TCP 6514 fra backend til Graylog
iptables -t nat -A PREROUTING -p tcp -d 172.21.0.254 --dport 6514 \
  -j DNAT --to-destination 172.30.0.10:6514

# Videresend syslog TCP 6514 fra internal til Graylog
iptables -t nat -A PREROUTING -p tcp -d 172.22.0.254 --dport 6514 \
  -j DNAT --to-destination 172.30.0.10:6514

# Videresend syslog TCP 6514 fra backup-net til Graylog
iptables -t nat -A PREROUTING -p tcp -d 172.23.0.254 --dport 6514 \
  -j DNAT --to-destination 172.30.0.10:6514

# Sørg for at returtrafikken går riktig tilbake via ruteren
iptables -t nat -A POSTROUTING -p tcp -d 172.30.0.10 --dport 6514 \
  -j MASQUERADE

# Tillat forwarding av syslog til Graylog
iptables -A FORWARD -p tcp -d 172.30.0.10 --dport 6514 -j ACCEPT
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT


# svartrafikk
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Start logging
rsyslogd

# Hold containeren i live
tail -f /dev/null
