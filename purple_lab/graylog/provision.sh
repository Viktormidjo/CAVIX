#!/bin/bash

# Start Graylog via original entrypoint i bakgrunnen
tini -- /docker-entrypoint.sh server &
GRAYLOG_PID=$!

echo "Venter på at Graylog skal bli tilgjengelig..."
until curl -s -u admin:admin http://localhost:9000/api/system/inputstates > /dev/null 2>&1; do
  echo "Ikke klar ennå, prøver om 5 sekunder..."
  sleep 5
done

echo "Sjekker om input eksisterer..."
EXISTING=$(curl -s -u admin:admin \
  -H "X-Requested-By: cli" \
  http://localhost:9000/api/system/inputs | grep -c "Syslog TCP")

if [ "$EXISTING" -gt "0" ]; then
  echo "Input eksisterer allerede."
else
  echo "Oppretter Syslog TCP input..."
  curl -s -u admin:admin \
    -H "Content-Type: application/json" \
    -H "X-Requested-By: cli" \
    -X POST http://localhost:9000/api/system/inputs \
    -d '{
      "title": "Syslog TCP",
      "type": "org.graylog2.inputs.syslog.tcp.SyslogTCPInput",
      "global": true,
      "configuration": {
        "bind_address": "0.0.0.0",
        "port": 6514,
        "recv_buffer_size": 1048576,
        "number_worker_threads": 2,
        "tls_enable": false,
        "tcp_keepalive": false,
        "use_null_delimiter": false,
        "allow_override_date": true,
        "store_full_message": false,
        "expand_structured_data": false,
        "force_rdns": false
      }
    }'
  echo "Ferdig."
fi

wait $GRAYLOG_PID
