#!/usr/bin/env bash
# Usage: ./run_experiment.sh <baseline|kem|v1> <eth|plc> [trials=100] [tag]
set -euo pipefail
cd "$(dirname "$0")"
SCENARIO="${1:?usage: $0 <baseline|kem|v1> <eth|plc> [trials] [tag]}"
CHANNEL="${2:?usage: $0 <baseline|kem|v1> <eth|plc> [trials] [tag]}"
TRIALS="${3:-100}"
TAG="${4:-${SCENARIO}_${CHANNEL}}"
export SCENARIO CHANNEL
if [ "$CHANNEL" = "plc" ]; then export MTU=1280; else export MTU=1500; fi

mkdir -p results certs
docker compose down -v --remove-orphans >/dev/null 2>&1 || true
docker compose up -d --build
docker compose exec -T -e TRIALS="$TRIALS" -e TAG="$TAG" client /scripts/run_trials.sh
docker compose exec -T client chown -R "$(id -u):$(id -g)" /results /certs 2>/dev/null || true
docker compose down -v >/dev/null 2>&1
