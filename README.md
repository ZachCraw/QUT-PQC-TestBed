# PQC Testbed — Basic Docker Skeleton

Minimal client / server / attacker setup for hybrid post-quantum TLS 1.3
(`X25519MLKEM768`), built with the [liboqs](https://github.com/open-quantum-safe/liboqs)
and [oqs-provider](https://github.com/open-quantum-safe/oqs-provider) projects on
Ubuntu 22.04.

## Structure

```
pqc-testbed/
├── docker-compose.yml       # defines the three containers + shared network
├── docker/
│   ├── Dockerfile           # shared image: Ubuntu 22.04 + liboqs + oqs-provider
│   └── openssl-oqs.cnf      # OpenSSL config that activates the oqs provider
├── server/entrypoint.sh     # generates certs, runs hybrid TLS 1.3 server
├── client/entrypoint.sh     # connects with hybrid TLS 1.3, logs result to CSV
├── attacker/entrypoint.sh   # idle placeholder — same network, NET_ADMIN/NET_RAW
├── certs/                   # shared volume — certs land here at runtime
└── results/                 # shared volume — handshake_log.csv lands here
```

All three containers build from the **same Dockerfile** (so you only compile
liboqs/oqs-provider once, cached by Docker); each service just mounts its own
`entrypoint.sh` at runtime to decide what role it plays.

## Running it

```bash
docker compose up --build
```

First build will take a few minutes (compiling liboqs + oqs-provider from
source). After that, `docker compose up` reuses the cached image.

What happens:
1. `server` generates a self-signed ECDSA cert on first run and starts an
   `openssl s_server` offering the `X25519MLKEM768` hybrid group.
2. `client` waits for the cert to appear, connects with the same hybrid
   group, and appends a row to `results/handshake_log.csv`
   (`timestamp, group, result, rtt_ms`).
3. `attacker` just sits on the network, idle, ready to be extended.

Check the result:
```bash
cat results/handshake_log.csv
cat results/last_handshake.log   # full openssl -msg handshake trace
```

Tear down (and wipe certs/results if you want a clean slate):
```bash
docker compose down
rm -rf certs/* results/*
```

## Re-running the client manually

Useful while developing, exec into the running client container and fire
handshakes on demand instead of waiting for the container to restart:

```bash
docker exec -it pqc-client bash
openssl s_client -connect server:4433 -tls1_3 -groups X25519MLKEM768 -CAfile /app/certs/ca-cert.pem -msg
```

## Switching groups

To compare against a classical baseline or pure PQC, just change `-groups`
in both `server/entrypoint.sh` and `client/entrypoint.sh`:

- `X25519` — classical baseline
- `MLKEM768` — pure post-quantum (no classical fallback)
- `X25519MLKEM768` — hybrid (default here, matches the supervisor's paper)