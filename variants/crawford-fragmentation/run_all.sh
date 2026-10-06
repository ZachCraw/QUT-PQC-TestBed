#!/usr/bin/env bash
# Full matrix: 3 scenarios x 2 channels x N trials (default 100).
set -euo pipefail
cd "$(dirname "$0")"
N="${1:-100}"
for ch in eth plc; do
  for sc in baseline kem v1; do
    echo "=== $sc / $ch ($N trials) ==="
    ./run_experiment.sh "$sc" "$ch" "$N"
  done
done
python3 analyse.py
