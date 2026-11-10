"""Fence report (N078, N079, N083, N084, N091, N092) and N090 from the raw CSV in one pass.
Same definitions as 06_slide_numbers.sql section 3: train days d_1583-d_1869, positive days only,
nearest-rank quartiles (smallest value whose CUME_DIST reaches 0.25 / 0.75), fence = Q3 + 1.5 (Q3 - Q1),
series with fewer than 8 positive train days get no fence, a day is flagged when sales > fence."""
import csv, math, time
from array import array
from collections import Counter

RAW = r'D:\VNUK\Bigdata_Analysis\Final\data\raw'
MIN_POS = 8
T0, T1 = 1583, 1869

wday = {}
with open(RAW + r'\calendar.csv', newline='', encoding='utf-8') as f:
    for r in csv.DictReader(f):
        wday[int(r['d'][2:])] = int(r['wday'])
print('train days', sum(1 for d in range(T0, T1 + 1)), 'sat/sun share %.2f' % (100 * sum(1 for d in range(T0, T1 + 1) if wday[d] in (1, 2)) / (T1 - T0 + 1)))

t0 = time.time()
vals = {}
days = {}
hist = Counter()
rows = zero = 0
mx = 0
train_units = 0
n_series_day = Counter()
with open(RAW + r'\m5_sales_last_365_days.csv', 'rb', buffering=1 << 20) as f:
    f.readline()
    for line in f:
        p = line.decode('ascii').split(',')
        sid = p[0]
        d = int(p[6][2:])
        s = int(p[7])
        rows += 1
        hist[s] += 1
        if s == 0:
            zero += 1
        elif s > mx:
            mx = s
        if s > 0 and T0 <= d <= T1:
            a = vals.get(sid)
            if a is None:
                vals[sid] = a = array('H')
                days[sid] = array('H')
            a.append(s)
            days[sid].append(d)
            train_units += s
        if d == 1870:
            n_series_day['n'] += 1
print('pass done %.0fs' % (time.time() - t0), 'rows', rows, 'series with a positive train day', len(vals))
n_series = n_series_day['n']
train_rows = n_series * (T1 - T0 + 1)


def nearest(sorted_v, q):
    k = max(1, math.ceil(q * len(sorted_v) - 1e-9))
    return sorted_v[k - 1]


flag_rows = flag_units_over = flag_units_sold = flag_ss = 0
fenced = nofence_few = 0
example = None
for sid, a in vals.items():
    sv = sorted(a)
    n = len(sv)
    if n < MIN_POS:
        nofence_few += 1
        continue
    q1, q3 = nearest(sv, .25), nearest(sv, .75)
    fence = q3 + 1.5 * (q3 - q1)
    fenced += 1
    d = days[sid]
    nf = 0
    for s, dd in zip(a, d):
        if s > fence:
            nf += 1
            flag_rows += 1
            flag_units_over += s - fence
            flag_units_sold += s
            if wday[dd] in (1, 2):
                flag_ss += 1
    if sid == 'HOBBIES_1_004_CA_1_evaluation':
        example = (n, q1, q3, fence, nf, sum(a), sum(s for s in a if s > fence), sum(1 for s, dd in zip(a, d) if s > fence and wday[dd] in (1, 2)))

# N090: nearest-rank 99th percentile of daily sales over all 365 days
cum = 0
p99 = None
for v in sorted(hist):
    cum += hist[v]
    if cum >= 0.99 * rows:
        p99 = v
        break

print()
print('check: rows %d (expect 11,128,850) | max %d (expect 349) | zero %% %.2f (expect 59.22) | series/day %d (expect 30,490)' % (rows, mx, 100 * zero / rows, n_series))
print('example HOBBIES_1_004_CA_1 (n_pos, q1, q3, fence, flagged days, units, units on flagged days, flagged on sat/sun):', example, ' expect fence 6, 10 of 11 sat/sun')
print()
print('N078 rows above fence      :', flag_rows)
print('N079 %% of train rows       : %.3f   (train rows %d)' % (100 * flag_rows / train_rows, train_rows))
print('N084 units over the fence  :', round(flag_units_over))
print('N083 %% of train units      : %.3f   (train units %d)' % (100 * flag_units_over / train_units, train_units))
print('context units on flagged days: %d (%.3f %% of train units)' % (flag_units_sold, 100 * flag_units_sold / train_units))
print('N092 %% flagged on Sat/Sun  : %.2f' % (100 * flag_ss / flag_rows))
print('N091 series without fence  :', n_series - fenced, '| never sold in train:', n_series - len(vals), '| fewer than %d positive days: %d' % (MIN_POS, nofence_few))
print('series with a fence        :', fenced)
print('N090 p99 daily sales       :', p99)
