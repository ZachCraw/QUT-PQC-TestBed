# Variant testbed — Week 11 (PLC channel + Variant 1 dataset)

Self-contained: does not touch the team's shared `core/` testbed.
Drop this folder in as `variants/crawford-fragmentation/`.

## Scenarios (3) x channels (2)
| SCENARIO | TLS group | Certificates | Purpose |
|---|---|---|---|
| `baseline` | X25519 | ECDSA P-256 | classical control / testbed gate |
| `kem` | X25519MLKEM768 | ECDSA P-256 | isolates the cost of the PQ key share |
| `v1` | X25519MLKEM768 | ML-DSA-65 | **Variant 1** |

| CHANNEL | MTU | netem |
|---|---|---|
| `eth` | 1500 | none |
| `plc` | 1280 | delay 15 ms + loss 5 %, on **each** side's egress |

## Commands (run from this folder)
    ./validate.sh plc                        # FR1: MTU / loss / delay / iperf3 check
    ./run_experiment.sh baseline plc 20 gate # testbed gate (20 trials)
    ./run_experiment.sh v1 plc 30            # pilot
    ./run_all.sh 100                         # full matrix, then summary
    python3 analyse.py && python3 plot.py    # table + results/handshake_times.png

Optional environment switches: `MUTUAL=1` (mutual TLS), `CHAIN=1` (server sends leaf+CA),
`DELAY_MS`, `LOSS_PCT`, `RATE=5mbit`.

Debugging: `docker compose up -d --build` then
`docker compose exec client /scripts/check_env.sh` or `/scripts/one_handshake.sh`
(set `SCENARIO=v1` / `CHANNEL=plc` / `MTU=1280` in your shell first).

## Known limitations (state these in the report)
* Handshake time is measured around the `openssl s_client` process, so it includes process start-up (a constant offset).
* netem acts on egress, so pcaps taken at the client do not show packets dropped by the server's netem; `server_segments` counts segments that *arrived* (including retransmissions). Exact retransmission counts need a router-container topology.
* Loss/delay are applied on both sides, so round-trip loss is about 1-(1-p)^2 and RTT about 2 x delay.
