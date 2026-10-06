#!/bin/bash
# FR1 validation: MTU, loss/delay and goodput of the emulated channel.
source /scripts/common.sh
setup_channel
until timeout 3 bash -c 'echo > /dev/tcp/server/4433' 2>/dev/null; do sleep 0.5; done
echo; echo "== MTU: 1252B payload (=1280 on wire) should pass =="
ping -M do -s 1252 -c 5 -W 2 server | tail -3
echo; echo "== MTU: 1253B payload should be rejected ('message too long') when MTU is 1280 =="
ping -M do -s 1253 -c 1 -W 2 server 2>&1 | head -3
echo; echo "== Loss / delay: 200 pings (round-trip loss ~ 1-(1-p)^2 when both sides drop) =="
ping -c 200 -i 0.05 -q server | tail -3
echo; echo "== iperf3 TCP goodput, 10 s =="
iperf3 -c server -t 10 | tail -6
