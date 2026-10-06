#!/bin/bash
# Shared helpers, sourced by the other scripts.
SCENARIO="${SCENARIO:-baseline}"
CHANNEL="${CHANNEL:-eth}"
DELAY_MS="${DELAY_MS:-15}"
LOSS_PCT="${LOSS_PCT:-5}"

# Apply (or clear) the emulated PLC channel on this container's egress.
# MTU itself is set on the Docker network (see MTU in docker-compose.yml).
setup_channel() {
  # Disable segmentation/receive offloads. Otherwise TCP hands multi-KB "super packets"
  # to the veth device, which passes them on whole: netem then drops entire bursts and
  # captures show segments larger than the MTU. We want real MSS-sized packets on the wire.
  ethtool -K eth0 tso off gso off gro off lro off >/dev/null 2>&1 || true
  tc qdisc del dev eth0 root 2>/dev/null || true
  if [ "$CHANNEL" = "plc" ]; then
    local rate_args=""
    if [ -n "${RATE:-}" ]; then rate_args="rate ${RATE}"; fi
    # shellcheck disable=SC2086
    tc qdisc add dev eth0 root netem delay "${DELAY_MS}ms" loss "${LOSS_PCT}%" $rate_args
  fi
  echo "[$(hostname)] channel=$CHANNEL mtu=$(cat /sys/class/net/eth0/mtu) qdisc: $(tc qdisc show dev eth0 | head -1)"
  echo "[$(hostname)] offloads: $(ethtool -k eth0 2>/dev/null | grep -E '^(tcp-segmentation|generic-segmentation|generic-receive)' | tr -s ' ' | tr '\n' ';')"
}

# Map SCENARIO -> TLS group + certificate set.
#   baseline : X25519          + ECDSA P-256   (classical control)
#   kem      : X25519MLKEM768  + ECDSA P-256   (isolates the key-share cost)
#   v1       : X25519MLKEM768  + ML-DSA-65     (Variant 1)
scenario_vars() {
  case "$SCENARIO" in
    baseline) GROUP="X25519";         CERTSET="classical" ;;
    kem)      GROUP="X25519MLKEM768"; CERTSET="classical" ;;
    v1)       GROUP="X25519MLKEM768"; CERTSET="mldsa65"   ;;
    *) echo "Unknown SCENARIO '$SCENARIO' (use baseline|kem|v1)"; exit 1 ;;
  esac
  CERT_DIR="/certs/$CERTSET"
  SERVER_CERT="$CERT_DIR/server.crt"
  if [ "${CHAIN:-0}" = "1" ]; then SERVER_CERT="$CERT_DIR/server_chain.crt"; fi

  SERVER_ARGS=(-accept 4433 -tls1_3 -groups "$GROUP" -cert "$SERVER_CERT" -key "$CERT_DIR/server.key" -www -no_ticket)
  CLIENT_ARGS=(-connect server:4433 -tls1_3 -groups "$GROUP" -CAfile "$CERT_DIR/ca.crt" -verify_return_error -brief)
  if [ "${MUTUAL:-0}" = "1" ]; then
    SERVER_ARGS+=(-Verify 1 -CAfile "$CERT_DIR/ca.crt")
    CLIENT_ARGS+=(-cert "$CERT_DIR/client.crt" -key "$CERT_DIR/client.key")
  fi
}
