#!/bin/bash
# Runs N TLS handshakes from the client, logs one CSV row per trial, captures a pcap.
set -uo pipefail
source /scripts/common.sh
TRIALS="${TRIALS:-100}"
TAG="${TAG:-${SCENARIO}_${CHANNEL}}"
CSV="/results/trials_${TAG}.csv"
PCAP="/results/${TAG}.pcap"
STREAMS="/results/streams_${TAG}.csv"

setup_channel
scenario_vars
echo "[client] scenario=$SCENARIO channel=$CHANNEL group=$GROUP certset=$CERTSET trials=$TRIALS"

until timeout 3 bash -c 'echo > /dev/tcp/server/4433' 2>/dev/null; do sleep 0.5; done
sleep 1

echo "scenario,channel,trial,timestamp_utc,handshake_ms,success,rc" > "$CSV"
tcpdump -i eth0 -U -w "$PCAP" "tcp port 4433" >/dev/null 2>&1 &
TCPDUMP_PID=$!
trap 'kill -INT $TCPDUMP_PID 2>/dev/null || true' EXIT
sleep 1

ok=0
for i in $(seq 1 "$TRIALS"); do
  t0=$(date +%s%N)
  out=$(timeout 10 openssl s_client "${CLIENT_ARGS[@]}" </dev/null 2>&1); rc=$?
  t1=$(date +%s%N)
  ms=$(( (t1 - t0) / 1000000 ))
  success=0
  if [ "$rc" -ne 124 ] && grep -q "CONNECTION ESTABLISHED" <<<"$out"; then success=1; ok=$((ok+1)); fi
  echo "$SCENARIO,$CHANNEL,$i,$(date -u +%FT%T.%3NZ),$ms,$success,$rc" >> "$CSV"
  if [ "$success" -eq 0 ] && [ ! -f "/results/first_failure_${TAG}.txt" ]; then
    printf 'trial=%s rc=%s ms=%s\n%s\n' "$i" "$rc" "$ms" "$out" > "/results/first_failure_${TAG}.txt"
  fi
done

sleep 1
kill -INT "$TCPDUMP_PID" 2>/dev/null || true
wait "$TCPDUMP_PID" 2>/dev/null || true
trap - EXIT

# Server->client data segments and bytes per TCP stream, as seen at the client.
echo "tcp_stream,server_segments,server_bytes" > "$STREAMS"
tshark -r "$PCAP" -Y "tcp.srcport==4433 && tcp.len>0" -T fields -e tcp.stream -e tcp.len 2>/dev/null \
  | awk '{s[$1]++; b[$1]+=$2} END{for(k in s) print k","s[k]","b[k]}' | sort -n >> "$STREAMS"

echo "[client] done: $ok/$TRIALS handshakes succeeded -> $CSV"
