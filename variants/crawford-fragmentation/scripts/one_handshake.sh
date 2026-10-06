#!/bin/bash
# One verbose handshake so you can eyeball what's actually negotiated.
source /scripts/common.sh
setup_channel; scenario_vars
until timeout 3 bash -c 'echo > /dev/tcp/server/4433' 2>/dev/null; do sleep 0.5; done
echo "[client] scenario=$SCENARIO group=$GROUP"
openssl s_client "${CLIENT_ARGS[@]}" </dev/null
echo "exit code: $?"
