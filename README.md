# Cavix
## Containerbasert purple lab for demonstrasjon av realistiske angrepsscenarioer

---

## Innhold

- [Oversikt](#oversikt)
- [Formål](#formål)
- [Arkitektur](#arkitektur)
- [Nettverkstopologi](#nettverkstopologi)
- [Containere](#containere)
- [Oppsett](#oppsett)
- [Gjennomføring av scenario](#gjennomføring-av-scenario)
- [Graylog – Brukerveiledning](#graylog--brukerveiledning)
- [Feilsøking](#feilsøking)
- [Sikker bruk](#sikker-bruk)

---

## Oversikt

Cavix er en containerbasert purple lab utviklet som del av en bacheloroppgave i digital infrastruktur og cybersikkerhet. Laben er bygget for å demonstrere hvordan kjente sårbarheter og angrepsmønstre fra norske IKT-systemer kan oversettes til realistiske, kontrollerte og observerbare angrepsscenarioer.

Miljøet er utviklet for demonstrasjon, læring og analyse. Målet er ikke å simulere hele kompleksiteten i et reelt virksomhetsmiljø, men å vise hvordan flere vanlige svakheter kan kombineres i en sammenhengende angrepskjede. Laben er bygget slik at sentrale hendelser kan observeres fra et defensivt perspektiv gjennom sentralisert logging i Graylog.

---

## Formål

Laben er laget for å:

- demonstrere hvordan angripere kan utnytte flere svakheter i kombinasjon
- vise hvordan mangelfull segmentering, svake passord og dårlig håndtering av autentiseringsdata kan gi videre tilgang i miljøet
- gi et observerbart miljø der blue team kan følge hendelser i logger
- støtte bacheloroppgavens evaluering av hvor godt en containerbasert purple lab kan brukes til adversary emulation

---

## Arkitektur

Laben er delt inn i fem nettverkssoner for å synliggjøre hvordan et angrep kan bevege seg fra en ytre flate til interne ressurser.

### Soner

| Sone | Subnet | Innhold |
|------|--------|---------|
| frontend | 172.20.0.0/24 | Attacker, edge-router |
| backend | 172.21.0.0/24 | Reverse-proxy, webapp, db, drift-pc, edge-router, router |
| internal | 172.22.0.0/24 | Filserver, brukerpc, router |
| backup-net | 172.23.0.0/24 | Backupserver, router |
| log-net | 172.30.0.0/24 | Graylog, OpenSearch, MongoDB, router |

---

## Nettverkstopologi

```
INTERNETT / ATTACKER (172.20.0.50)
         │
         │  port 8080 (HTTP) og port 2222 (SSH – eksponert ved uhell)
         ▼
┌──────────────────────────────────┐
│  edge-router                     │
│  172.20.0.254  (frontend)        │
│  172.21.0.253  (backend)         │
└──────────────────┬───────────────┘
                   │
                   ▼ backend-nett (172.21.0.0/24)
┌──────────────────────────────────┐
│  reverse-proxy  172.21.0.10      │  ← eneste eksponerte tjeneste
└──────────────────┬───────────────┘
                   │
       ┌───────────┼───────────────┐
       │           │               │
┌──────▼──────┐  ┌─▼───────────┐  ┌▼────────────┐
│   webapp    │  │     db      │  │   drift-pc  │
│ 172.21.0.20 │  │ 172.21.0.30 │  │ 172.21.0.40 │
└─────────────┘  └─────────────┘  └─────────────┘

┌──────────────────────────────────────────────────────────┐
│  router                                                  │
│  172.21.0.254 (backend)   172.22.0.254 (internal)        │
│  172.23.0.254 (backup-net) 172.30.0.254 (log-net)        │
└──────────────────────────────────────────────────────────┘

internal (172.22.0.0/24)        backup-net (172.23.0.0/24)
  ┌─────────────┐                 ┌─────────────────┐
  │  filserver  │                 │  backupserver   │
  │ 172.22.0.10 │                 │  172.23.0.67    │
  └─────────────┘                 └─────────────────┘
  ┌─────────────┐
  │  brukerpc   │
  │ 172.22.0.30 │
  └─────────────┘

log-net (172.30.0.0/24)
  ┌───────────────┐   ┌──────────────┐   ┌──────────────┐
  │    graylog    │   │  opensearch  │   │    mongo     │
  │  172.30.0.10  │   │ 172.30.0.11  │   │ 172.30.0.12  │
  └───────────────┘   └──────────────┘   └──────────────┘
```

---

## Containere

| Container | IP-adresse(r) | Nettverk | Rolle |
|-----------|--------------|----------|-------|
| attacker | 172.20.0.50 | frontend | Angripermaskin med verktøy (nmap, hydra, smbclient, sshpass) |
| edge-router | 172.20.0.254, 172.21.0.253 | frontend, backend | Ruter mellom frontend og backend |
| reverse-proxy | 172.21.0.10 | backend | nginx + SSH – eneste eksponerte tjeneste |
| webapp | 172.21.0.20 | backend | Flask-nettside |
| db | 172.21.0.30 | backend | PostgreSQL-database |
| drift-pc | 172.21.0.40 | backend | Drifts-maskin |
| router | 172.21.0.254, 172.22.0.254, 172.23.0.254, 172.30.0.254 | backend, internal, backup-net, log-net | Intern ruter mellom alle soner |
| brukerpc | 172.22.0.30 | internal | Brukernes PC |
| filserver | 172.22.0.10 | internal | Samba-filserver med sensitiv informasjon |
| backupserver | 172.23.0.67 | backup-net | Backup-node, SCP-only |
| graylog | 172.30.0.10 | log-net | Sentral loggserver – web UI på port 9000 |
| opensearch | 172.30.0.11 | log-net | Søkemotor for Graylog-logger |
| mongo | 172.30.0.12 | log-net | MongoDB – Graylog metadata |

**Eksponerte porter på host-maskinen:**

| Port (host) | Container-port | Tjeneste |
|-------------|---------------|----------|
| 8080 | 80 | Webapp (HTTP via reverse-proxy) |
| 2222 | 22 | SSH på reverse-proxy |
| 2223 | 22 | SSH på backupserver |
| 9000 | 9000 | Graylog Web UI |
| 6514/tcp | 6514/tcp | Graylog Syslog TCP input |

---

## Oppsett

```bash
git clone https://github.com/Viktormidjo/CAVIX.git
cd /CAVIX

# Bygge nødvendig Docker miljø
chmod +x ./setup_vm.sh
./setup_vm.sh

# Start alle containere
cd /purple_lab
docker compose up -d --build

# Verifiser at alle kjører
docker compose ps

# Koble til attacker-containeren
docker exec -it attacker bash

# Starte attackscript
cd workspace
./angrep.sh

```

> **Merk:** Alle verktøy (nmap, hydra, smbclient, sshpass, nc) og ordlister
> (`/opt/wordlists/users.txt`, `/opt/wordlists/passwords.txt`) er
> forhåndslastet i attacker-containeren ved oppstart.

> **Graylog:** Det kan ta 1–2 minutter etter `docker compose up` før Graylog
> er tilgjengelig på `http://localhost:9000`.

---

## Gjennomføring av scenario

Scenarioet er bygget som en fasevis angrepskjede. Hver fase representerer et steg i et realistisk angrepsforløp, fra første rekognosering til videre tilgang og uthenting av data.

Det anbefales å:

1. starte hele miljøet på nytt
2. verifisere at alle containere er oppe med `docker compose ps`
3. åpne Graylog i nettleseren før scenariet kjøres
4. kjøre faseskript eller kommandoer i riktig rekkefølge
5. følge hendelsene parallelt i Graylog

### Angrepskjeden – faseoversikt

| Fase | Beskrivelse | NSM-sårbarhet |
|------|-------------|---------------|
| F1 | Rekognosering – nettverkskontakt mot reverse-proxy | #9 Mangelfull segmentering |
| F2 | Password spray mot SSH på reverse-proxy | #1 Svake passord, #2 Passordgjetting |
| F3 | Fotfeste på proxy, tunnel videre i backend | #9 Mangelfull segmentering |
| F4 | Password spray mot drift-pc via tunnel | #1 Svake passord, #2 Passordgjetting |
| F5 | Rekognosering på drift-pc | #9 Mangelfull segmentering |
| F6 | Passord i klartekst, sudo-eskalering til root | #4 Ubeskyttede passord, #6 For høye rettigheter |
| F7 | Manipulering av backup-konfigurasjon | #4 Ubeskyttede passord, #6 For høye rettigheter |
| F8 | Cron sender backup til proxy – eksfiltrering fullført | #3 Standardpassord, #9 Segmentering |

---

## Graylog – Brukerveiledning

Graylog brukes som defensivt observasjonspunkt i laben. Her kan man følge hvordan hendelser fra ulike deler av miljøet samles inn og vises sentralt.

### Tilgang via nettleser

Etter at labben er startet, åpner du nettleseren og går til:

```
http://localhost:9000
```

> Kjører du labben på en ekstern VM eller server, erstatter du `localhost` med
> IP-adressen til maskinen, f.eks.:
> ```
> http://192.168.1.100:9000
> ```

**Innlogging:**

| Felt | Verdi |
|------|-------|
| Brukernavn | `admin` |
| Passord | `admin` |

> Det kan ta **1–2 minutter** etter oppstart før Graylog er klar. Prøv å laste siden
> på nytt hvis du får feilmelding. Sjekk status med:
> ```bash
> docker logs graylog --tail 30
> ```

---

### Navigasjon i Graylog

Når du er logget inn ser du dashboardet. De viktigste delene er:

- **Search** – søk i alle innkommende logger
- **Streams** – filtrerte visninger av logger per kilde eller type
- **Dashboards** – egendefinerte oversikter
- **System → Inputs** – konfigurasjon og status for logginngang

---

### Syslog TCP input

Graylog er konfigurert med én logginngang:

| Parameter | Verdi |
|-----------|-------|
| Type | Syslog TCP |
| Port | `6514` |
| Bind-adresse | `0.0.0.0` |
| Container-IP | `172.30.0.10` |

Containere i laben sender logger via rsyslog til `172.30.0.10:6514`.
Verifiser at input er aktiv under **System → Inputs** – statusen skal vise **Running**.

---

### Søk etter logger

**Se alle logger de siste 5 minuttene:**
Sett tidsvindu til `Last 5 minutes` og trykk **Search**.

**Nyttige søk:**

```
sshd
sudo
cron
smb
source_ip:172.20.0.50
webadmin OR drift
```

**Kombiner med AND/OR:**

```
message:Failed AND source:172.21.0.10
```

**Filtrer etter tidsperiode:**
Bruk nedtrekksmenyen øverst til høyre – `Last 1 hour`, `Last 24 hours`, eller `Absolute` for eget intervall.

---

### Fasevis observasjon i Graylog

| Fase | Hva forventer du å se | Søk i Graylog |
|------|----------------------|---------------|
| F1 – Rekognosering | Nettverkskontakt mot proxy | `source:172.21.0.10` |
| F2 – Hydra mot SSH | Mange feilede innlogginger | `message:Failed password` |
| F3 – SSH-tunnel | Vellykket innlogging, ny sesjon | `message:Accepted AND source:172.21.0.10` |
| F4 – Hydra mot drift-pc | Feilede forsøk via tunnel | `message:Failed password AND source:172.21.0.40` |
| F5 – Intern rekognosering | Kommandoer på drift-pc | `source:172.21.0.40` |
| F6 – Sudo-eskalering | Sudo-bruk og privilegieendring | `message:sudo` |
| F7 – Konfig-endring | Skriving til backup.conf | `message:backup` |
| F8 – Eksfiltrering | SCP-overføring av backup | `message:scp OR message:backup` |

---

## Feilsøking

### Graylog starter ikke

Sjekk containerstatus:

```bash
docker compose ps
```

Sjekk logger:

```bash
docker compose logs graylog
docker compose logs opensearch
docker compose logs mongo
```

Vanlige årsaker:
- OpenSearch er ikke klar når Graylog starter
- MongoDB er ikke oppe
- Portkonflikt på 9000 eller 6514

### Logger mangler i Graylog

Sjekk at:
- Syslog TCP input er **Running** under System → Inputs
- Loggkildene peker til `172.30.0.10:6514`
- Port 6514 er åpen internt i miljøet
- Containerne faktisk produserer logger

Nyttige kommandoer:

```bash
docker compose logs <container-navn>
docker compose logs graylog
```

### Container starter ikke

Bygg alt på nytt:

```bash
docker compose down -v
docker compose up -d --build
```

---

## Sikker bruk

Laben er utviklet for et kontrollert og isolert miljø. Den skal ikke eksponeres mot internett eller brukes mot eksterne systemer. Alle sårbarheter, brukerkontoer og passord i miljøet er opprettet for demonstrasjonsformål.
