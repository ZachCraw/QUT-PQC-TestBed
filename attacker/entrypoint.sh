#!/bin/bash
set -e

echo "[attacker] idle placeholder container."
echo "[attacker] sitting on the same 'pqc-net' bridge as client and server."
echo "[attacker] has NET_ADMIN/NET_RAW so it can run iptables/nftables/tc/tcpdump"
echo "[attacker] once someone builds out MITM / replay / downgrade / fuzz scenarios here."
echo ""
echo "[attacker] example starting points once you're ready to extend this:"
echo "  - tcpdump -i eth0 -w /app/results/capture.pcap   (passive capture)"
echo "  - iptables + arpspoof style redirection            (active MITM)"
echo "  - tc qdisc add ... netem loss/delay                (network impairment)"

tail -f /dev/null
