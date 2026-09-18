#!/bin/bash
set -e

CERT_DIR=/app/certs
LOG_DIR=/app/results
mkdir -p "$LOG_DIR"

echo "[client] waiting for server certs and port to be ready..."
until [ -f "$CERT_DIR/ca-cert.pem" ]; do
  sleep 1
done
sleep 3  # small grace period for the server process itself to bind

CSV="$LOG_DIR/handshake_log.csv"
if [ ! -f "$CSV" ]; then
  echo "timestamp,group,result,rtt_ms" > "$CSV"
fi

echo "[client] connecting to server:4433 with hybrid group X25519MLKEM768"

START=$(date +%s%3N)
RESULT="FAIL"

if echo -e "GET / HTTP/1.0\r\n\r\n" | openssl s_client \
    -connect server:4433 \
    -tls1_3 \
    -groups X25519MLKEM768 \
    -CAfile "$CERT_DIR/ca-cert.pem" \
    -msg -quiet > "$LOG_DIR/last_handshake.log" 2>&1; then
  RESULT="SUCCESS"
fi

END=$(date +%s%3N)
RTT=$((END - START))

echo "$(date -u +%FT%TZ),X25519MLKEM768,$RESULT,$RTT" >> "$CSV"
echo "[client] handshake result: $RESULT (${RTT} ms) — logged to $CSV"

# Keep the container alive so you can exec in and re-run manually while developing
tail -f /dev/null
