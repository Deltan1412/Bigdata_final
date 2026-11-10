#!/usr/bin/env python3
"""Collect the numbers that required_numbers.md marks as RUN, from the flow that just ran.

Sources (nothing is typed by hand):
  - MySQL: sales_predictions_weekly (what the KNIME DB Writer wrote), v_weekly_model, weekly_features
  - the KNIME workspace folder of the workflow (workflow.knime: nodes, boxes)
  - knime.log (node execution timestamps)

Metrics are recomputed from the written predictions with the same definitions as the KNIME
Numeric Scorer / GroupBy nodes (MAE, RMSE, R2 = 1 - SSE/SST, WAPE = 100*sum|e|/sum(actual)).

Usage:
  python collect_run_numbers.py [--model LinearRegression_weekly_v1] [--workspace D:/KNIME_workspace]
                                [--workflow Bigdata_final_weekly] [--out D:/.../process]
The MySQL password is read from Final/.env (MYSQL_PWD=...) and never printed.
"""
import argparse, csv, os, re, subprocess, sys, datetime

HERE = os.path.dirname(os.path.abspath(__file__))
FINAL = os.path.abspath(os.path.join(HERE, "..", ".."))
MYSQL = r"C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe"

ap = argparse.ArgumentParser()
ap.add_argument("--model", default="LinearRegression_weekly_v1")
ap.add_argument("--workspace", default="D:/KNIME_workspace")
ap.add_argument("--workflow", default="Bigdata_final_weekly")
ap.add_argument("--db", default="bigdataprj")
ap.add_argument("--out", default=os.path.join(FINAL, "process"))
args = ap.parse_args()


def load_env():
    env = dict(os.environ)
    p = os.path.join(FINAL, ".env")
    if os.path.exists(p):
        for line in open(p, encoding="utf-8"):
            if "=" in line and not line.startswith("#"):
                k, v = line.rstrip("\r\n").split("=", 1)
                env[k.strip()] = v
    if "MYSQL_PWD" not in env and "DATABASE_PASSWORD" in env:
        env["MYSQL_PWD"] = env["DATABASE_PASSWORD"]
    return env


ENV = load_env()


def sql(query):
    r = subprocess.run([MYSQL, "-u", "root", "-B", "-N", args.db, "-e", query], env=ENV,
                       capture_output=True, text=True)
    if r.returncode != 0:
        sys.exit("MySQL error: " + r.stderr.strip()[:300])
    return [line.split("\t") for line in r.stdout.splitlines() if line != ""]


rows_out = []  # (id, value, unit, source, note)


def put(i, v, unit, source, note=""):
    if isinstance(v, float):
        v = round(v, 4)
    rows_out.append((i, v, unit, source, note))


# ----------------------------------------------------------------------------- data
M = args.model
pred_rows = sql(f"""
SELECT p.store_id, m.state_id, p.dept_id, p.week_idx, p.wm_yr_wk, p.predicted_sales, p.actual_sales,
       m.lag1, m.lag2, m.roll4, m.snap_days, m.event_days, m.closed_days, m.series_mean, m.sales
FROM sales_predictions_weekly p
JOIN v_weekly_model m ON m.store_id = p.store_id AND m.dept_id = p.dept_id AND m.wm_yr_wk = p.wm_yr_wk
WHERE p.model_name = '{M}'""")
if not pred_rows:
    sys.exit(f"No rows for model_name = {M} in sales_predictions_weekly")
cols = ["store", "state", "dept", "week", "wk", "pred", "act", "lag1", "lag2", "roll4", "snap", "event", "closed", "smean", "src_sales"]
D = [dict(zip(cols, r)) for r in pred_rows]
for d in D:
    for k in cols:
        if k not in ("store", "state", "dept"):
            d[k] = float(d[k])


def wape(rs, f=lambda d: d["pred"]):
    s = sum(d["act"] for d in rs)
    return 100 * sum(abs(d["act"] - f(d)) for d in rs) / s


def bias(rs, f=lambda d: d["pred"]):
    s = sum(d["act"] for d in rs)
    return 100 * (sum(f(d) for d in rs) - s) / s


def mae(rs, f=lambda d: d["pred"]):
    return sum(abs(d["act"] - f(d)) for d in rs) / len(rs)


def rmse(rs, f=lambda d: d["pred"]):
    return (sum((d["act"] - f(d)) ** 2 for d in rs) / len(rs)) ** 0.5


def r2(rs, f=lambda d: d["pred"]):
    m = sum(d["act"] for d in rs) / len(rs)
    return 1 - sum((d["act"] - f(d)) ** 2 for d in rs) / sum((d["act"] - m) ** 2 for d in rs)


def groups(key):
    g = {}
    for d in D:
        g.setdefault(d[key], []).append(d)
    return g


base = lambda d: d["lag1"]
roll = lambda d: d["roll4"]

# ----------------------------------------------------------------------------- core metrics
SRC_P = "sales_predictions_weekly + v_weekly_model"
put("N016", wape(D), "%", SRC_P, "Test WAPE, model (clipped = as written)")
put("N139", mae(D), "units", SRC_P, "Test MAE, model")
put("N141", rmse(D), "units", SRC_P, "Test RMSE, model")
put("N143", r2(D), "ratio", SRC_P, "Test R2, model (1 - SSE/SST)")
put("N140", mae(D, base), "units", SRC_P, "Test MAE, last-week baseline (lag1)")
put("N142", rmse(D, base), "units", SRC_P, "Test RMSE, last-week baseline")
put("N144", r2(D, base), "ratio", SRC_P, "Test R2, last-week baseline")
put("N145", wape(D, base), "%", SRC_P, "Test WAPE, last-week baseline")
put("EXTRA-roll4", wape(D, roll), "%", SRC_P, "Test WAPE, 4-week-average baseline (fairer baseline)")
put("EXTRA-bias", bias(D), "%", SRC_P, "Total bias (sum forecast - sum actual) / sum actual")

# by store / dept
for key, lo, hi, nm in (("store", "N146", "N147", "store"), ("dept", "N148", "N149", "department")):
    w = {k: wape(v) for k, v in groups(key).items()}
    kmin, kmax = min(w, key=w.get), max(w, key=w.get)
    put(lo, w[kmin], "%", SRC_P, f"Lowest {nm} WAPE ({kmin})")
    put(hi, w[kmax], "%", SRC_P, f"Highest {nm} WAPE ({kmax})")

# by state bias
sb = {k: bias(v) for k, v in groups("state").items()}
smin, smax = min(sb, key=sb.get), max(sb, key=sb.get)
put("N150", sb[smin], "%", SRC_P, f"Lowest state bias ({smin})")
put("N151", sb[smax], "%", SRC_P, f"Highest state bias ({smax})")
for s in sorted(sb):
    put(f"N18x-{s}", sb[s], "%", SRC_P, f"Forecast bias, {s} (feeds N182-N184)")
put("N185", sum(1 for v in sb.values() if abs(v) > 5), "states", SRC_P, "States with |bias| above 5%")

# SNAP vs non-SNAP weeks
snap = [d for d in D if d["snap"] > 0]
nsnap = [d for d in D if d["snap"] == 0]
put("N154", bias(snap), "%", SRC_P, f"Bias in SNAP weeks (snap_days > 0, {len(snap)} rows)")
put("N155", bias(nsnap), "%", SRC_P, f"Bias in non-SNAP weeks ({len(nsnap)} rows)")

# weekly
gw = groups("week")
wk_m = {k: wape(v) for k, v in gw.items()}
wk_b = {k: wape(v, base) for k, v in gw.items()}
put("N152", sum(1 for k in gw if wk_m[k] < wk_b[k]), f"of {len(gw)} weeks", SRC_P, "Test weeks where model WAPE < last-week WAPE")
put("EXTRA-weeks-vs-roll4", sum(1 for k in gw if wk_m[k] < wape(gw[k], roll)), f"of {len(gw)} weeks", SRC_P, "Test weeks where model beats the 4-week average")
put("N196", min(wk_m.values()), "%", SRC_P, f"Lowest weekly WAPE (week_idx {min(wk_m, key=wk_m.get):.0f})")
put("N197", max(wk_m.values()), "%", SRC_P, f"Highest weekly WAPE (week_idx {max(wk_m, key=wk_m.get):.0f})")

# clipped vs unclipped
minp = min(d["pred"] for d in D)
put("N153", 0.0 if minp > 0 else None, "pp", SRC_P,
    f"Unclipped minus clipped WAPE: min written prediction is {minp:.2f} > 0, so max(pred, 0) never fired and both are identical"
    if minp > 0 else "Some predictions were clipped: needs the unclipped column from KNIME")

# state correction on held-out weeks (calibrate on first half of test weeks, apply to second)
weeks = sorted(gw)
cal_w, held_w = weeks[: len(weeks) // 2], weeks[len(weeks) // 2:]
fac = {}
for s in sb:
    c = [d for d in D if d["state"] == s and d["week"] in cal_w]
    fac[s] = sum(d["act"] for d in c) / sum(d["pred"] for d in c)
held = [d for d in D if d["week"] in held_w]
corr = lambda d: d["pred"] * fac[d["state"]]
put("N186", mae(held), "units", "derived (SQ-B, held-out test weeks)", f"MAE before state correction, weeks {int(held_w[0])}-{int(held_w[-1])}")
put("N187", mae(held, corr), "units", "derived (SQ-B, held-out test weeks)",
    "MAE after state factors calibrated on weeks %d-%d: %s" % (cal_w[0], cal_w[-1], ", ".join(f"{s} x{fac[s]:.3f}" for s in sorted(fac))))
put("EXTRA-bias-held-before", bias(held), "%", "derived", "Total bias on held-out weeks, uncorrected")
put("EXTRA-bias-held-after", bias(held, corr), "%", "derived", "Total bias on held-out weeks, corrected (accept only if MAE and bias both improve)")

# ----------------------------------------------------------------------------- write-back and counts (MySQL)
n_rows = int(sql(f"SELECT COUNT(*) FROM sales_predictions_weekly WHERE model_name='{M}'")[0][0])
n_keys = int(sql(f"SELECT COUNT(DISTINCT store_id,dept_id,wm_yr_wk) FROM sales_predictions_weekly WHERE model_name='{M}'")[0][0])
mismatch = int(sql(f"""SELECT COUNT(*) FROM sales_predictions_weekly p JOIN weekly_features f
   ON f.store_id=p.store_id AND f.dept_id=p.dept_id AND f.wm_yr_wk=p.wm_yr_wk
   WHERE p.model_name='{M}' AND ABS(p.actual_sales - f.sales) > 0.0001""")[0][0])
put("N157", n_rows, "rows", "MySQL", "Rows in sales_predictions_weekly for this model after the run (run 1 if this was the first run)")
put("N158", n_keys, "keys", "MySQL", "Distinct (store, dept, week) keys written")
put("N159", minp, "units", "MySQL", "Minimum predicted_sales written")
put("N160", mismatch, "rows", "MySQL", "Rows where actual_sales differs from weekly_features.sales")
put("N045", n_rows, "rows", "MySQL", "Rows in sales_predictions_weekly (this model)")
vm = sql("""SELECT COUNT(*), SUM(model_ready=1), SUM(model_ready=1 AND split='train'), SUM(model_ready=1 AND split='test'),
            MAX(CASE WHEN split='train' AND model_ready=1 THEN week_idx END), MIN(CASE WHEN split='test' THEN week_idx END),
            SUM(model_ready=1 AND (lag1 IS NULL OR lag2 IS NULL OR roll4 IS NULL))
            FROM v_weekly_model""")[0]
put("N043", int(vm[0]), "rows", "MySQL", "Rows in the weekly table/view (v_weekly_model)")
put("N059", int(vm[1]), "rows", "MySQL", "Rows the DB Query Reader returns (model_ready = 1)")
put("N061", int(vm[2]), "rows", "MySQL", "Training rows")
put("N062", int(vm[3]), "rows", "MySQL", "Test rows")
put("N039", int(vm[5]) - int(vm[4]), "weeks", "MySQL", f"MIN(test week_idx) {vm[5]} - MAX(train week_idx) {vm[4]}")
put("N063", int(vm[6]), "cells", "MySQL", "NULL lags among the rows the Reader returns")

# ----------------------------------------------------------------------------- refit check (coefficients, NaN)
train = sql("""SELECT sales, series_mean, lag1, lag2, roll4, snap_days, event_days, closed_days
               FROM v_weekly_model WHERE model_ready=1 AND split='train'""")
X, Y = [], []
for r in train:
    s, sm, l1, l2, r4, sn, ev, cl = map(float, r)
    X.append([1.0, sn, ev, cl, l1 / sm, l2 / sm, r4 / sm])
    Y.append(s / sm)


def ols(X, Y):
    n = len(X[0])
    A = [[sum(x[i] * x[j] for x in X) for j in range(n)] + [sum(x[i] * y for x, y in zip(X, Y))] for i in range(n)]
    for i in range(n):
        p = max(range(i, n), key=lambda r: abs(A[r][i]))
        A[i], A[p] = A[p], A[i]
        if abs(A[i][i]) < 1e-12:
            return None
        for r in range(n):
            if r != i:
                f = A[r][i] / A[i][i]
                A[r] = [a - f * b for a, b in zip(A[r], A[i])]
    return [A[i][n] / A[i][i] for i in range(n)]


beta = ols(X, Y)
names = ["Intercept", "snap_days", "event_days", "closed_days", "lag1_s", "lag2_s", "roll4_s"]
if beta is None:
    put("N156", "singular", "count", "refit", "Normal equations singular: check the features in the Learner")
else:
    nan = sum(1 for b in beta if b != b)
    put("N156", nan, "count", "refit of the Learner on the train rows", "NaN coefficients; " + ", ".join(f"{n}={b:.4f}" for n, b in zip(names, beta)))
    dmax = 0.0
    for d in D:
        x = [1.0, d["snap"], d["event"], d["closed"], d["lag1"] / d["smean"], d["lag2"] / d["smean"], d["roll4"] / d["smean"]]
        p = max(0.0, sum(b * v for b, v in zip(beta, x))) * d["smean"]
        dmax = max(dmax, abs(p - d["pred"]))
    put("EXTRA-refit-check", dmax, "units", "refit vs written predictions",
        "Max |refit prediction - written prediction|. About 0 means the written predictions come from exactly these coefficients")

# ----------------------------------------------------------------------------- validation checks (N064 / N065)
checks = [
    ("Leakage: MIN(test week) > MAX(train week)", int(vm[5]) > int(vm[4])),
    ("Written rows = test rows", n_rows == int(vm[3])),
    ("No duplicate keys (distinct keys = rows)", n_keys == n_rows),
    ("MIN(predicted_sales) >= 0", minp >= 0),
    ("actual_sales equals the source weekly sales", mismatch == 0),
    ("No NULL lags in the rows the model reads", int(vm[6]) == 0),
]
put("N065", len(checks), "checks", "this script", "; ".join(c[0] for c in checks))
put("N064", sum(1 for c in checks if c[1]), "checks", "this script", "Failed: " + (", ".join(c[0] for c in checks if not c[1]) or "none") + ". The re-run (run 2 vs run 1) check needs a second run")

# ----------------------------------------------------------------------------- workflow structure (workspace)
wf = os.path.join(args.workspace, args.workflow, "workflow.knime")
sections = []
if os.path.exists(wf):
    t = open(wf, encoding="utf-8").read()
    nodes = []
    for m in re.finditer(r'<config key="node_(\d+)">(.*?)</config>\s*</config>\s*</config>', t, flags=re.S):
        blk = m.group(2)
        f = re.search(r'node_settings_file" type="xstring" value="([^"]+)/settings.xml', blk).group(1)
        b = re.findall(r'extrainfo.node.bounds.*?key="0" type="xint" value="(-?\d+)".*?key="1" type="xint" value="(-?\d+)"', blk, flags=re.S)
        nodes.append((int(m.group(1)), f, int(b[0][0]), int(b[0][1])))
    boxes = []
    ann = t[t.index('key="annotations"'): t.index('key="nodes"')] if 'key="annotations"' in t else ""
    import html
    for blk in re.split(r'<config key="annotation_\d+">', ann)[1:]:
        g = lambda k: re.search(rf'key="{k}" type="x\w+" value="([^"]*)"', blk).group(1)
        boxes.append((html.unescape(g("text")), int(g("x-coordinate")), int(g("y-coordinate")), int(g("width")), int(g("height"))))
    put("N032", len(nodes), "nodes", "workflow.knime (saved workspace copy)", "Total nodes on the canvas: " + args.workflow)
    for i, (txt, x, y, w, h) in enumerate(boxes, 1):
        inside = [n for n in nodes if x <= n[2] <= x + w and y <= n[3] <= y + h]
        sections.append((i, txt[:70], len(inside)))
        put(f"SECTION-{i}", len(inside), "nodes", "workflow.knime", txt[:90] + "  (guide N051-N058 expects 8 sections: map by hand)")
else:
    put("N032", None, "nodes", "workflow.knime", f"not found: {wf}")

# ----------------------------------------------------------------------------- run time from knime.log
logp = os.path.join(args.workspace, ".metadata", "knime", "knime.log")
if os.path.exists(logp):
    ev = []
    for line in open(logp, encoding="utf-8", errors="ignore"):
        m = re.match(r"(\d{4}-\d\d-\d\d \d\d:\d\d:\d\d),(\d+) .*?: (.+?) \d+:(\d+) End execute \((\d+) secs\)", line)
        if m:
            ts = datetime.datetime.strptime(m.group(1), "%Y-%m-%d %H:%M:%S") + datetime.timedelta(milliseconds=int(m.group(2)))
            ev.append((ts, int(m.group(4)), int(m.group(5))))
    if ev:
        last = [ev[-1]]
        for e in reversed(ev[:-1]):
            if (last[-1][0] - e[0]).total_seconds() < 120:
                last.append(e)
            else:
                break
        last.reverse()
        span = (last[-1][0] - last[0][0]).total_seconds()
        put("N066", round(span / 60, 2), "min", "knime.log",
            f"INDICATIVE ONLY: first to last 'End execute' of the last run cluster = {span:.0f} s, from {last[0][0]:%H:%M:%S} to {last[-1][0]:%H:%M:%S}. "
            "If the run was done in stages by hand this includes your waiting time; time one clean Reset all + Execute all for the real value")

# ----------------------------------------------------------------------------- not derivable
put("N195", None, "%", "not available", "No capped (outlier) branch exists in the workflow; skip or build the optional branch")
put("N161", None, "units", "needs KNIME", "MAE gap, MySQL minus KNIME: read the Numeric Scorer MAE in KNIME and subtract N139")
put("N067", None, "rows", "needs run 2", "Row growth between run 1 and run 2: run Reset all + Execute all again, then re-run this script and subtract N157")

# ----------------------------------------------------------------------------- write files
os.makedirs(args.out, exist_ok=True)
csvp = os.path.join(args.out, "numbers_collected.csv")
with open(csvp, "w", newline="", encoding="utf-8") as f:
    w = csv.writer(f)
    w.writerow(["id", "value", "unit", "source", "note"])
    w.writerows(rows_out)
mdp = os.path.join(args.out, "numbers_collected.md")
with open(mdp, "w", encoding="utf-8") as f:
    f.write(f"# Numbers collected from the run of `{M}`\n\n")
    f.write(f"Generated {datetime.datetime.now():%Y-%m-%d %H:%M} by `process/knime/collect_run_numbers.py` from MySQL, the KNIME workspace and knime.log. ")
    f.write("Metrics are recomputed from the written predictions (sales_predictions_weekly).\n\n")
    f.write("| ID | Value | Unit | Source | Note |\n|---|---:|---|---|---|\n")
    for i, v, u, s, n in rows_out:
        f.write(f"| {i} | {'' if v is None else v} | {u} | {s} | {n} |\n")
print(f"{len(rows_out)} rows -> {mdp}\n                 {csvp}")
for i, v, u, s, n in rows_out:
    print(f"{i:22s} {str(v):>12s} {u:12s} {n[:90]}")
