import os, subprocess, sys, math, collections
FINAL = r'D:\VNUK\Bigdata_Analysis\Final'
MYSQL = r'C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe'
env = dict(os.environ)
for line in open(os.path.join(FINAL, '.env'), encoding='utf-8'):
    if '=' in line and not line.startswith('#'):
        k, v = line.rstrip('\r\n').split('=', 1)
        env[k.strip()] = v
if 'MYSQL_PWD' not in env and 'DATABASE_PASSWORD' in env:
    env['MYSQL_PWD'] = env['DATABASE_PASSWORD']
r = subprocess.run([MYSQL, '-u', 'root', '-B', '-N', 'bigdataprj', '-e',
                    "SELECT store_id, dept_id, week_idx, split, sales, snap_days, event_days, closed_days, series_mean FROM v_weekly_model"],
                   env=env, capture_output=True, text=True)
if r.returncode:
    sys.exit(r.stderr[:200])
rows = [l.split('\t') for l in r.stdout.splitlines()]
S = collections.defaultdict(dict)
for st, dp, w, sp, sa, sn, ev, cl, sm in rows:
    S[(st, dp)][int(w)] = dict(split=sp, sales=float(sa), snap=float(sn), event=float(ev), closed=float(cl), sm=float(sm))
print('series', len(S), 'rows', len(rows))


def quart(v, q):
    v = sorted(v); k = (len(v) - 1) * q; f = int(k); c = min(f + 1, len(v) - 1)
    return v[f] + (v[c] - v[f]) * (k - f)


def ols(X, Y):
    n = len(X[0])
    A = [[sum(x[i] * x[j] for x in X) for j in range(n)] + [sum(x[i] * y for x, y in zip(X, Y))] for i in range(n)]
    for i in range(n):
        p = max(range(i, n), key=lambda r: abs(A[r][i]))
        A[i], A[p] = A[p], A[i]
        for r in range(n):
            if r != i:
                f = A[r][i] / A[i][i]
                A[r] = [a - f * b for a, b in zip(A[r], A[i])]
    return [A[i][n] / A[i][i] for i in range(n)]


def feat(ser, w, sm, snap, event, closed):
    l1, l2 = ser[w - 1], ser[w - 2]
    r4 = sum(ser[w - j] for j in range(1, 5)) / 4
    return [1.0, snap, event, closed, l1 / sm, l2 / sm, r4 / sm]


def run(cap):
    X, Y, fences = [], [], 0
    capped_vals = 0
    models = {}
    for key, d in S.items():
        train_w = [w for w in range(6, 43)]
        base = [d[w]['sales'] for w in train_w]
        fence = quart(base, .75) + 1.5 * (quart(base, .75) - quart(base, .25))
        ser = {w: d[w]['sales'] for w in d}
        if cap:
            for w in range(1, 43):
                if ser[w] > fence:
                    ser[w] = fence
                    capped_vals += 1
        models[key] = ser
        for w in train_w:
            sm = d[w]['sm']
            X.append(feat(ser, w, sm, d[w]['snap'], d[w]['event'], d[w]['closed']))
            Y.append(ser[w] / sm)
    beta = ols(X, Y)
    # score on the test weeks with RAW inputs
    sse = sae = sact = sst = n = 0.0
    acts = []
    preds = []
    for key, d in S.items():
        raw = {w: d[w]['sales'] for w in d}
        for w in range(43, 53):
            sm = d[w]['sm']
            x = feat(raw, w, sm, d[w]['snap'], d[w]['event'], d[w]['closed'])
            p = max(0.0, sum(b * v for b, v in zip(beta, x))) * sm
            a = d[w]['sales']
            acts.append(a); preds.append(p)
    n = len(acts)
    mean = sum(acts) / n
    sse = sum((a - p) ** 2 for a, p in zip(acts, preds))
    sae = sum(abs(a - p) for a, p in zip(acts, preds))
    sst = sum((a - mean) ** 2 for a in acts)
    return dict(n=n, rmse=math.sqrt(sse / n), mae=sae / n, wape=100 * sae / sum(acts), r2=1 - sse / sst, capped=capped_vals, beta=beta)


a = run(False)
b = run(True)
print('RAW   ', {k: (round(v, 4) if isinstance(v, float) else v) for k, v in a.items() if k != 'beta'})
print('CAPPED', {k: (round(v, 4) if isinstance(v, float) else v) for k, v in b.items() if k != 'beta'})
print('RMSE change %', round(100 * (b['rmse'] - a['rmse']) / a['rmse'], 3), '| WAPE change pp', round(b['wape'] - a['wape'], 3), '| MAE change %', round(100 * (b['mae'] - a['mae']) / a['mae'], 3))
