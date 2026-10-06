#!/usr/bin/env python3
"""Summarise results/trials_*.csv (+ streams_*.csv). Standard library only.

Handshake-time distributions on lossy links are heavy-tailed (retransmission timeouts),
so the median / p95 and the >2 s rate (with a Wilson 95% CI) are the headline numbers;
the mean +/- CI is shown for completeness but is dominated by a few slow trials.
"""
import csv, glob, math, os, statistics, sys

TIMEOUT_MS = 2000
RES = os.path.join(os.path.dirname(os.path.abspath(__file__)), "results")

def crit(n):
    try:
        from scipy import stats
        return stats.t.ppf(0.975, n - 1)
    except Exception:
        return statistics.NormalDist().inv_cdf(0.975)

def wilson(k, n, z=1.96):
    p = k / n
    d = 1 + z * z / n
    c = (p + z * z / (2 * n)) / d
    h = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / d
    return max(0.0, c - h) * 100, min(1.0, c + h) * 100

def pct(xs, p):
    xs = sorted(xs)
    k = (len(xs) - 1) * p
    lo, hi = math.floor(k), math.ceil(k)
    return xs[lo] if lo == hi else xs[lo] + (xs[hi] - xs[lo]) * (k - lo)

rows_out = []
for path in sorted(glob.glob(os.path.join(RES, "trials_*.csv"))):
    tag = os.path.basename(path)[len("trials_"):-len(".csv")]
    with open(path) as f:
        rows = list(csv.DictReader(f))
    if not rows:
        continue
    n = len(rows)
    ok = [r for r in rows if r["success"] == "1"]
    times = [float(r["handshake_ms"]) for r in ok]
    over = sum(1 for r in rows if r["success"] != "1" or float(r["handshake_ms"]) > TIMEOUT_MS)
    lo, hi = wilson(over, n)
    out = {"tag": tag, "scenario": rows[0]["scenario"], "channel": rows[0]["channel"],
           "n": n, "success_rate_pct": 100.0 * len(ok) / n, "over_2s_n": over,
           "over_2s_pct": 100.0 * over / n, "over_2s_lo": lo, "over_2s_hi": hi}
    if len(times) >= 2:
        m, sd = statistics.mean(times), statistics.stdev(times)
        out.update(mean_ms=m, sd_ms=sd, ci95_ms=crit(len(times)) * sd / math.sqrt(len(times)),
                   median_ms=statistics.median(times), p95_ms=pct(times, 0.95), max_ms=max(times))
    spath = os.path.join(RES, f"streams_{tag}.csv")
    if os.path.exists(spath):
        with open(spath) as f:
            srows = list(csv.DictReader(f))
        if srows:
            out["srv_segments_mean"] = statistics.mean(float(r["server_segments"]) for r in srows)
            out["srv_bytes_mean"] = statistics.mean(float(r["server_bytes"]) for r in srows)
    rows_out.append(out)

if not rows_out:
    sys.exit("No results/trials_*.csv files found.")

def g(r, k, fmt, width):
    return format(r[k], fmt) if k in r else "-".rjust(width)

print(f"{'condition':<16}{'n':>5}{'ok%':>7}{'>2s%':>7}{'  [95% CI]':>14}{'median':>9}{'p95':>9}{'max':>9}{'mean':>9}{'±CI':>9}{'segs':>7}{'bytes':>9}")
for r in rows_out:
    ci = f"[{r['over_2s_lo']:.1f}-{r['over_2s_hi']:.1f}]"
    print(f"{r['tag']:<16}{r['n']:>5}{r['success_rate_pct']:>7.1f}{r['over_2s_pct']:>7.1f}{ci:>14}"
          f"{g(r,'median_ms','9.1f',9)}{g(r,'p95_ms','9.1f',9)}{g(r,'max_ms','9.0f',9)}"
          f"{g(r,'mean_ms','9.1f',9)}{g(r,'ci95_ms','9.1f',9)}{g(r,'srv_segments_mean','7.1f',7)}{g(r,'srv_bytes_mean','9.0f',9)}")

cols = ["tag", "scenario", "channel", "n", "success_rate_pct", "over_2s_n", "over_2s_pct", "over_2s_lo",
        "over_2s_hi", "median_ms", "p95_ms", "max_ms", "mean_ms", "ci95_ms", "srv_segments_mean", "srv_bytes_mean"]
with open(os.path.join(RES, "summary.csv"), "w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=cols, extrasaction="ignore")
    w.writeheader(); w.writerows(rows_out)
print(f"\nWrote {os.path.join(RES, 'summary.csv')}  (times in ms; >2s% counts failed handshakes too)")