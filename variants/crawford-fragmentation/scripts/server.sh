#!/bin/bash
set -eu
source /scripts/common.sh
setup_channel
/scripts/gen_certs.sh
scenario_vars
iperf3 -s -D >/dev/null 2>&1 || true
echo "[server] scenario=$SCENARIO group=$GROUP certset=$CERTSET mutual=${MUTUAL:-0} chain=${CHAIN:-0}"
exec openssl s_server "${SERVER_ARGS[@]}"
