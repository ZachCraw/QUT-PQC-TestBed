#!/usr/bin/env python3
"""Two panels: (left) ECDF of handshake time on the PLC channel, (right) share of handshakes
exceeding the 2.0 s timeout (Wilson 95% CI). ECDFs show the heavy tail that a mean hides."""
import csv, math, os
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

RES = os.path.join(os.path.dirname(os.path.abspath(__file__)), "results")
TIMEOUT_MS = 2000
ALIASES = {"baseline_plc": ["gate"], "baseline_eth": ["check"]}   # use earlier runs if full ones don't exist yet
SCEN = [("baseline", "Classical (X25519 + ECDSA)"),
        ("kem", "Hybrid KEM only (X25519MLKEM768 + ECDSA)"),
        ("v1", "Variant 1 (X25519MLKEM768 + ML-DSA-65)")]
COL = {"baseline": "#4c72b0", "kem": "#dd8452", "v1": "#c44e52"}

def load(sc, ch):
    for tag in [f"{sc}_{ch}"] + ALIASES.get(f"{sc}_{ch}", []):
        p = os.path.join(RES, f"trials_{tag}.csv")
        if os.path.exists(p):
            with open(p) as f:
                return list(csv.DictReader(f))
    return None

def wilson(k, n, z=1.96):
    p = k / n; d = 1 + z * z / n
    c = (p + z * z / (2 * n)) / d
    h = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / d
    return max(0, c - h) * 100, min(1, c + h) * 100

fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(13, 5))

# --- left: ECDF on PLC (failed handshakes never complete, so curves can plateau below 1)
for sc, label in SCEN:
    rows = load(sc, "plc")
    if not rows:
        continue
    t = sorted(float(r["handshake_ms"]) for r in rows if r["success"] == "1")
    n = len(rows)
    ys = [(i + 1) / n for i in range(len(t))]
    ax1.step(t, ys, where="post", color=COL[sc], label=f"{label} (n={n})")
ax1.axvline(TIMEOUT_MS, color="red", ls="--", lw=1)
ax1.text(TIMEOUT_MS * 1.08, 0.3, "2.0 s\nV2G_EVCC_\nMsg_Timeout", color="red", fontsize=8)
ax1.set_xscale("log"); ax1.set_xlim(20, 12000); ax1.set_ylim(0, 1.02)
ax1.set_xlabel("Handshake time (ms, log scale; includes ~30 ms client process start-up)")
ax1.set_ylabel("Fraction of handshakes completed within time t")
ax1.set_title("Emulated PLC channel (1280 B MTU, loss + delay)")
ax1.grid(alpha=0.3, which="both"); ax1.legend(loc="lower right", fontsize=8)

# --- right: share of handshakes over 2 s, both channels
width = 0.38
for j, (ch, chlabel) in enumerate([("eth", "Ethernet"), ("plc", "Emulated PLC")]):
    for i, (sc, _) in enumerate(SCEN):
        rows = load(sc, ch)
        if not rows:
            continue
        n = len(rows)
        k = sum(1 for r in rows if r["success"] != "1" or float(r["handshake_ms"]) > TIMEOUT_MS)
        lo, hi = wilson(k, n)
        p = 100.0 * k / n
        x = i + (j - 0.5) * width
        ax2.bar(x, p, width, color=["#8da0cb", "#fc8d62"][j], label=chlabel if i == 0 else None,
                yerr=[[p - lo], [hi - p]], capsize=4)
        ax2.text(x, hi + 0.5, f"{k}/{n}", ha="center", fontsize=8)
ax2.set_xticks(range(len(SCEN))); ax2.set_xticklabels(["Classical", "Hybrid KEM\nonly", "Variant 1"])
ax2.set_ylabel("Handshakes slower than 2.0 s or failed (%)  [Wilson 95% CI]")
ax2.set_title("Timeout-limit violations"); ax2.legend(); ax2.grid(alpha=0.3, axis="y")

fig.tight_layout()
out = os.path.join(RES, "handshake_results.png")
fig.savefig(out, dpi=200)
print("Wrote", out)