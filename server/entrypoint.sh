#!/bin/bash
set -e

CERT_DIR=/app/certs

if [ ! -f "$CERT_DIR/server-cert.pem" ]; then
  echo "[server] no cert found, generating a self-signed ECDSA (P-256) cert..."
  openssl ecparam -name prime256v1 -genkey -noout -out "$CERT_DIR/server-key.pem"
  openssl req -new -x509 -key "$CERT_DIR/server-key.pem" \
      -out "$CERT_DIR/server-cert.pem" \
      -days 365 -subj "/CN=pqc-server"
  # For this basic single-server setup, the server's own cert doubles as the CA file
  cp "$CERT_DIR/server-cert.pem" "$CERT_DIR/ca-cert.pem"
  echo "[server] certs written to $CERT_DIR"
fi

echo "[server] listing available PQC groups from the oqsprovider:"
openssl list -kem-algorithms -provider oqsprovider | grep -i mlkem || true

echo "[server] starting hybrid PQC TLS 1.3 server on 0.0.0.0:4433 (group: X25519MLKEM768)"
exec openssl s_server \
    -accept 4433 \
    -cert "$CERT_DIR/server-cert.pem" \
    -key "$CERT_DIR/server-key.pem" \
    -tls1_3 \
    -groups X25519MLKEM768 \
    -www
