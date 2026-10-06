#!/bin/bash
# Generates two certificate sets (idempotent): classical ECDSA P-256 and ML-DSA-65.
# NOTE: CA/leaf extensions are explicit because our custom OPENSSL_CONF has no [req]
# section; without basicConstraints=CA:TRUE, OpenSSL 3.4 rejects the CA ("invalid CA certificate").
set -euo pipefail
ROOT="${CERT_ROOT:-/certs}"

gen_set() {
  local name="$1" keyargs="$2"
  local d="$ROOT/$name"
  mkdir -p "$d"; cd "$d"
  if [ -f .done ]; then echo "[certs] $name already present"; return; fi
  echo "[certs] generating $name set"
  # shellcheck disable=SC2086
  openssl req -x509 -new $keyargs -keyout ca.key -out ca.crt -nodes -subj "/CN=PQC Test CA" -days 365 \
    -addext "basicConstraints=critical,CA:TRUE" -addext "keyUsage=critical,keyCertSign,cRLSign"
  printf "basicConstraints=CA:FALSE\nkeyUsage=critical,digitalSignature\nextendedKeyUsage=serverAuth,clientAuth\n" > leaf.ext
  for n in server client; do
    # shellcheck disable=SC2086
    openssl req -new $keyargs -keyout $n.key -out $n.csr -nodes -subj "/CN=$n"
    openssl x509 -req -in $n.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out $n.crt -days 365 -extfile leaf.ext
  done
  cat server.crt ca.crt > server_chain.crt
  touch .done
  echo "[certs] $name: server.crt = $(openssl x509 -in server.crt -outform der | wc -c) bytes (DER)"
}

gen_set classical "-newkey ec -pkeyopt ec_paramgen_curve:prime256v1"
if [ "${SKIP_PQ:-0}" != "1" ]; then gen_set mldsa65 "-newkey mldsa65"; fi
