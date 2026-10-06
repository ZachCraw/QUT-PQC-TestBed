#!/usr/bin/env bash
# Usage: ./validate.sh <eth|plc>   -> FR1 channel validation (MTU, loss, delay, iperf3)
set -euo pipefail
cd "$(dirname "$0")"
export CHANNEL="${1:-plc}" SCENARIO=baseline
if [ "$CHANNEL" = "plc" ]; then export MTU=1280; else export MTU=1500; fi
docker compose down -v --remove-orphans >/dev/null 2>&1 || true
docker compose up -d --build
docker compose exec -T client /scripts/validate_channel.sh | tee "results/validate_${CHANNEL}.txt"
docker compose down -v >/dev/null 2>&1
