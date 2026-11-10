"""Slide 20 (SQ-A) and slide 21 (recommendation dollars) from the raw CSVs plus the 700 written predictions.
Same definitions as 03_kpi_queries.sql C.0/C.1/C.6 and 06_slide_numbers.sql sections 4 and 5."""
import csv, os, subprocess, sys, time, json, collections

FINAL = r'D:\VNUK\Bigdata_Analysis\Final'
RAW = FINAL + r'\data\raw'
MYSQL = r'C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe'
MODEL = 'LinearRegression_weekly_v1'
HOLD_WEEK = 0.25 / 52
SQA = 20.0
Q2, Q3 = 20.0, 10.0

# ---------------------------------------------------------------- calendar
cal = {}
with open(RAW + r'\calendar.csv', newline='', encoding='utf-8') as f:
    for r in csv.DictReader(f):
        n = int(r['d'][2:])
        if 1577 <= n <= 1941:
            cal[n] = dict(wm=int(r['wm_yr_wk']), wday=int(r['wday']), snap={'CA': int(r['snap_CA']), 'TX': int(r['snap_TX']), 'WI': int(r['snap_WI'])})
weeks = sorted({v['wm'] for v in cal.values()})
widx = {w: i + 1 for i, w in enumerate(weeks)}
test_wm = {w for w in weeks if 43 <= widx[w] <= 52}
print('weeks', len(weeks), 'test weeks', sorted(test_wm))

# ---------------------------------------------------------------- one pass over the sales CSV
t0 = time.time()
su = collections.defaultdict(int)          # (store, dept, wm) units, all weeks
iu = collections.defaultdict(int)          # (store, item, wm) units, test weeks
sc_first = collections.defaultdict(int)    # (store, cat)
sc_last = collections.defaultdict(int)
scd = collections.defaultdict(int)         # (state, cat, day) units
with open(RAW + r'\m5_sales_last_365_days.csv', 'rb', buffering=1 << 20) as f:
    f.readline()
    for line in f:
        p = line.decode('ascii').split(',')
        s = int(p[7])
        d = int(p[6][2:])
        store, dept, cat, state, item = p[4], p[2], p[3], p[5], p[1]
        wm = cal[d]['wm']
        if s:
            su[(store, dept, wm)] += s
            scd[(state, cat, d)] += s
            if wm in test_wm:
                iu[(store, item, wm)] += s
            if d <= 1604:
                sc_first[(store, cat)] += s
            elif d >= 1914:
                sc_last[(store, cat)] += s
print('sales pass %.0fs' % (time.time() - t0), len(su), len(iu))

# ---------------------------------------------------------------- prices for the test weeks
t0 = time.time()
need = set(iu)
pm = {}
with open(RAW + r'\sell_prices.csv', 'rb', buffering=1 << 20) as f:
    f.readline()
    for line in f:
        p = line.decode('ascii').rstrip('\r\n').split(',')
        k = (p[0], p[1], int(p[2]))
        if k in need:
            pm[k] = float(p[3])
print('price pass %.0fs' % (time.time() - t0), 'priced', len(pm), 'of', len(need), '(rows without a price count as 0, as in C.0)')

rev = collections.defaultdict(float)       # (store, dept, wm) revenue, test weeks
rev_sc = collections.defaultdict(float)    # (store, cat) revenue, test weeks
rev_stc = collections.defaultdict(float)   # (state, cat)
units_sc = collections.defaultdict(int)
units_stc = collections.defaultdict(int)
for (store, item, wm), u in iu.items():
    price = pm.get((store, item, wm), 0.0)
    dept = item.rsplit('_', 1)[0]
    cat = item.split('_')[0]
    state = store.split('_')[0]
    rev[(store, dept, wm)] += u * price
    rev_sc[(store, cat)] += u * price
    rev_stc[(state, cat)] += u * price
    units_sc[(store, cat)] += u
    units_stc[(state, cat)] += u

# ---------------------------------------------------------------- the 700 written predictions (small read)
r = subprocess.run([MYSQL, '-u', 'root', '-B', '-N', 'bigdataprj', '-e',
                    "SELECT store_id, dept_id, wm_yr_wk, week_idx, predicted_sales, actual_sales FROM sales_predictions_weekly WHERE model_name='%s'" % MODEL],
                   env={**os.environ, **{k: v for k, v in (l.rstrip('\r\n').split('=', 1) for l in open(FINAL + r'\.env', encoding='utf-8') if '=' in l and not l.startswith('#'))}},
                   capture_output=True, text=True)
if r.returncode:
    sys.exit('MySQL: ' + r.stderr[:200])
P = []
for l in r.stdout.splitlines():
    a = l.split('\t')
    P.append(dict(store=a[0], dept=a[1], wm=int(a[2]), wk=int(a[3]), pred=float(a[4]), act=float(a[5])))
print('predictions', len(P))
bad = [x for x in P if abs(su.get((x['store'], x['dept'], x['wm']), 0) - x['act']) > 1e-6]
print('actual units: CSV vs written actual_sales mismatches:', len(bad), '| sum actual', round(sum(x['act'] for x in P), 1))

# lag1 = previous week's units of the same series
wm_of_idx = {widx[w]: w for w in weeks}
for x in P:
    x['lag1'] = su.get((x['store'], x['dept'], wm_of_idx[x['wk'] - 1]), 0)
    x['arev'] = rev[(x['store'], x['dept'], x['wm'])]
    x['prev'] = x['pred'] * x['arev'] / x['act'] if x['act'] else None
    x['over'] = max(x['prev'] - x['arev'], 0.0)
    x['base'] = abs(x['lag1'] - x['act']) * x['arev'] / x['act']
    x['model'] = abs(x['prev'] - x['arev'])

# ---------------------------------------------------------------- slide 20: revenue error per store
sw = collections.defaultdict(lambda: [0.0, 0.0])
for x in P:
    sw[(x['store'], x['wk'])][0] += x['prev']
    sw[(x['store'], x['wk'])][1] += x['arev']
st_mae = collections.defaultdict(list)
for (store, wk), (pr, ar) in sw.items():
    st_mae[store].append(abs(pr - ar))
tot_abs = sum(sum(v) for v in st_mae.values())
rows = sorted(((sum(v) / len(v), 100 * sum(v) / tot_abs, s) for s, v in st_mae.items()), reverse=True)
print('\nSLIDE 20  store | revenue MAE USD/week | share of total revenue error %')
for m, sh, s in rows:
    print('  %s  %9.2f  %6.2f' % (s, m, sh))
print('N181 stores above %.0f%%:' % SQA, sum(1 for m, sh, s in rows if sh > SQA), '| stores', len(rows))
out = {'rows': [(s, round(m, 2), round(sh, 2)) for m, sh, s in rows], 'n181': sum(1 for m, sh, s in rows if sh > SQA)}

# ---------------------------------------------------------------- slide 21
nwk = len({x['wk'] for x in P})
n188 = sum(x['base'] - x['model'] for x in P) / nwk
n189 = sum(x['over'] for x in P) * HOLD_WEEK / nwk
print('\nREC 1  weeks', nwk, '| N188 benefit %.2f | N189 cost %.2f | last-week $ error/wk %.2f | model $ error/wk %.2f | over-stock $/wk %.2f'
      % (n188, n189, sum(x['base'] for x in P) / nwk, sum(x['model'] for x in P) / nwk, sum(x['over'] for x in P) / nwk))
out.update(n188=round(n188, 2), n189=round(n189, 2))

tf, tl = sum(sc_first.values()), sum(sc_last.values())
rg = 100 * (tl / tf - 1)
print('\nREC 2  regional growth %.2f%%' % rg)
ben2 = cost2 = ex2 = 0.0
for (store, cat), fv in sorted(sc_first.items()):
    lv = sc_last[(store, cat)]
    gap = 100 * (lv / fv - 1) - rg
    if gap > Q2:
        excess = (lv - fv * (1 + rg / 100)) / 4
        price = rev_sc[(store, cat)] / units_sc[(store, cat)]
        print('  %s %s gap %.2f pp  extra units/wk %.0f  price %.3f  benefit %.2f' % (store, cat, gap, excess, price, excess * price))
        ex2 += excess; ben2 += excess * price
cost2 = ben2 * HOLD_WEEK
print('  N190 benefit %.2f | N191 cost %.2f | extra units/wk %.0f' % (ben2, cost2, ex2))
out.update(n190=round(ben2, 2), n191=round(cost2, 2))

print('\nREC 3')
ben3 = ex3 = 0.0
for state in ('CA', 'TX', 'WI'):
    for cat in ('FOODS', 'HOBBIES', 'HOUSEHOLD'):
        sn = [scd.get((state, cat, d), 0) for d in cal if cal[d]['snap'][state] == 1]
        ns = [scd.get((state, cat, d), 0) for d in cal if cal[d]['snap'][state] == 0]
        a, b = sum(sn) / len(sn), sum(ns) / len(ns)
        up = 100 * (a / b - 1)
        if up > Q3:
            extra = (a - b) * len(sn) / (len(cal) / 7)
            price = rev_stc[(state, cat)] / units_stc[(state, cat)]
            print('  %s %s uplift %.2f%%  snap days %d  extra units/wk %.0f  price %.3f  benefit %.2f' % (state, cat, up, len(sn), extra, price, extra * price))
            ex3 += extra; ben3 += extra * price
cost3 = ben3 * HOLD_WEEK
print('  N192 benefit %.2f | N193 cost %.2f | extra units/wk %.0f' % (ben3, cost3, ex3))
out.update(n192=round(ben3, 2), n193=round(cost3, 2))
# lower bound (06 section 5.4)
low = 0.0
for x in P:
    if x['store'].split('_')[0] in ('TX', 'WI') and x['dept'].startswith('FOODS'):
        pass
json.dump(out, open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'dollars.json'), 'w'))
