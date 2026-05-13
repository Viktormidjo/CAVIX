#!/bin/bash

# Stopper skriptet hvis noe feiler
set -e

# Sørger for at mødvendige kataloger finnes før Samba starter
mkdir -p /mount/public /mount/sensitive /etc/samba/scripts /run/samba /var/log/samba

# Opprett brukerne hvis de ikke finnes (unngår feil ved rebuild)
useradd -M -s /usr/sbin/nologin user 2>/dev/null || true
useradd -M -s /usr/sbin/nologin admin 2>/dev/null || true
useradd -M -s /usr/sbin/nologin oldadmin 2>/dev/null || true

# Legg brukerne i smbusers-gruppen (tilgangskontroll for shares)
usermod -aG smbusers user 2>/dev/null || true
usermod -aG smbusers admin 2>/dev/null || true
usermod -aG smbusers oldadmin 2>/dev/null || true

# Sett Samba-passord for hver bruker
printf '%s\n%s\n' 'UserPass123' 'UserPass123' | smbpasswd -a -s user || true
printf '%s\n%s\n' 'AdminPass123' 'AdminPass123' | smbpasswd -a -s admin || true
printf '%s\n%s\n' 'Bedriften1!' 'Bedriften1!' | smbpasswd -a -s oldadmin || true

# Aktiver kontoene i Samba
smbpasswd -e user || true
smbpasswd -e admin || true
smbpasswd -e oldadmin || true

# mapusers.sh - brukes av samba til å mappe brukernavn
cat > /etc/samba/scripts/mapusers.sh << 'EOF'
#!/bin/bash
USERNAME="$1"
eval echo "$USERNAME" 2>/dev/null
EOF
chmod +x /etc/samba/scripts/mapusers.sh

# backup.sh - placeholder for backup-integrasjon (ikke aktivert)
cat > /etc/samba/scripts/backup.sh << 'EOF'
#!/bin/bash
ADMIN_USER=drift
ADMIN_PASS=DriftPass123
SSH_HOST=172.22.0.20
# sshpass -p "$ADMIN_PASS" ssh $ADMIN_USER@$SSH_HOST "echo backup ok"
EOF
chmod 644 /etc/samba/scripts/backup.sh

# Sørg for at loggfilen eksisterer slik at rsyslog kan overvåke den
touch /var/log/samba/log.smbd

# Start rsyslog for å sende Samba-logger til Graylog
rsyslogd

# Start Samba i foreground (holder containeren i live)
exec smbd --foreground --no-process-group
