# Decision-maker and decision questions (Phase 1, scope v2)

## Decision-maker

**Regional Inventory Manager (RIM)** for the Walmart stores in CA, TX and WI (10 stores).

- Owns: weekly reorder quantities and stock allocation between stores.
- Decides: weekly, a week ahead of demand.
- Uses our output: store x department weekly forecast, store-category growth flags, SNAP/weekday/event uplift per state.

## Grain

Store x department (or category) x week. Daily item-level forecasts failed (WAPE 70-118%); weekly store x department reached WAPE 6.8%.

## Decision questions

### Q1 - Forecast

> How many units will each store sell in each department next week, so the regional inventory manager (RIM) can set weekly reorder quantities, with forecast error (WAPE) <= 10%?

- Inventory action: set weekly reorder quantities.
- Metric and target: WAPE <= 10% on held-out weeks.
- Evidence so far: weekly dept-store WAPE 6.8%.

### Q2 - Growth diagnosis

> Which store-categories grew fastest or slowest in the last 28 days compared with the first 28 days, so the RIM can shift stock allocation from slow-growing to fast-growing stores, flagging any store-category whose growth differs from the regional average by more than 20 percentage points?

- Inventory action: shift stock allocation between stores.
- Metric and target: growth gap vs regional average (all 10 stores, weighted by units) > 20 percentage points.
- Evidence so far: WI +25%, TX +7%, CA_3 -4% (state/store level).
- Decided 2026-11-10: 20 pp. On the full data 10 pp flags 12 of 30 store-categories, 20 pp flags 3 (CA_2, WI_3 and WI_2 FOODS), which meets the target of about 2-4 (`03_kpi_queries.sql` B.1b).

### Q3 - Demand drivers

> By how many percent do SNAP days, weekdays and events raise demand over non-SNAP days for each state-category, so the RIM can add stock one week ahead of the high-demand days, acting when the uplift exceeds 10%?

- Inventory action: add stock one week ahead of high-demand days.
- Metric and target: uplift % vs non-SNAP days per state-category; act when uplift > 10%.
- Evidence so far: SNAP uplift WI +20.5%, TX +10.1%, CA +6.0%; events about -4%. With a 10% threshold, WI and TX trigger extra stock, CA does not.
- Not used: holiday lift +14.2% (not reproducible).
- Decided 2026-11-10: 10%, confirmed on the full data (`03_kpi_queries.sql` B.2): 2 of 9 state-categories pass, TX FOODS (+14.60%) and WI FOODS (+27.77%); the other 7 are below 10%.

## Wording rules used

- Every question ends in an inventory action the RIM can take.
- Every question has a number target or threshold.
- SNAP is described as *timing* of stock, not as a lever Walmart controls.
- Q1 is judged by WAPE (forecast error); Q2 by growth gap; Q3 by uplift %. Do not mix the metrics.

## Supporting questions (extras, not counted among the 3 required decision questions)

Placed after the core MAE / RMSE / R2 work. They add dollar and bias evidence for the recommendations (ROI and trade-offs).

### SQ-A - Revenue error

> Which stores carry the largest weekly forecast error in dollars (units x price), so the RIM can focus the weekly reorder review on the stores where a wrong forecast costs most, reviewing any store that makes up more than 20% of total revenue error?

- Inventory action: put the reorder review first on the stores with the highest dollar error.
- Metric and target: weekly revenue MAE (USD) per store and each store's share of total revenue error, full test weeks only.
- Check: does the dollar ranking match the unit-error ranking? If not, explain (price mix).
- Open: 20% is provisional. Pick it from the real shares so about 1-3 stores flag.

### SQ-B - State bias

> Is the forecast systematically too low or too high in any state, so the RIM can raise or lower that state's reorder quantities, acting when the state's forecast bias is beyond +/-5% and is not caused by a single store?

- Inventory action: adjust a state's reorder quantities (per-state correction factor).
- Metric and target: bias = (sum forecast - sum actual) / sum actual per state over the test weeks, plus the same per store inside that state.
- Accept rule: use a correction only if bias and MAE both improve on held-out weeks.
- Open: +/-5% is provisional. Earlier state figures (CA -20.20%, TX +4.76%, WI +3.27%) are unverified; recompute them.

## Outlier policy decision (Phase 2, decided 2026-11-10)

### Decision

**Outliers are not removed.** No rows and no sales values are deleted or changed in the training data. Sales stay as recorded.

- Detection is still done, per series (store x item), on TRAIN days only: IQR with k = 1.5 on positive-sales days, upper side only (zero is real demand).
- The fence is used to report, not to edit: rows and units above the fence, per series, per category and in total.
- Capping to the fence is not part of the main pipeline. It may be run once as a sensitivity check (fit on raw vs capped, compare test RMSE on raw actuals).
- The test period is never altered; Q1 WAPE is judged on raw actuals.

### Reasons

1. **The brief allows it.** `required_files.md` asks for a rationale for "retaining or handling" outliers (not removal) and a record of the rows/units affected.
2. **The old rule destroyed the signal.** Deleting sales above the IQR bound removed 14% of rows = 73% of units (roadmap p2t9). The Week 1 fence (sales > 2) was one global number for all series, so it hit normal days of high-volume items.
3. **The spikes are the weekly pattern, not errors.** Checked on the full 365-day window: weekend (Sat+Sun) mean sales per row is 1.573 vs 1.205 on weekdays (+30.5%). Example series `HOBBIES_1_004_CA_1` (train d_1577-d_1868): per-series fence = 6, which flags 11 of 292 days (39 of 555 units); 10 of those 11 days are Saturdays or Sundays (Sunday mean 3.95 vs Tuesday 1.02). Capping would teach the model that weekends are weaker than they are. The old global fence of 2 would flag 84 of 292 days (29%) and 38% of the units for the same series.
4. **The decision questions depend on the spikes.** Q3 measures the percent uplift of SNAP days, weekdays and events; capping or removing the high days shrinks the very effect we are asked to measure. Q1 needs the model to see real peak weeks to set reorder quantities.
5. **Fewer moving parts.** Capping per series would also need day-type buckets (weekday / weekend / event), a sparse-bucket fallback and a rule for the test period. Not needed when values stay as they are.
6. **No leakage.** The fence is fitted on train days only, and nothing in the test period is edited.

### Risk accepted

- Linear regression (OLS) is sensitive to large values. Expected mitigation: weekday, event, SNAP and price features explain most weekend/event spikes instead of treating them as noise. This is expected, not yet measured; the optional capped-vs-raw comparison is how to check it.
- If capping is ever tried: compute the fence on positive-sales days only. On all days, Q1 = Q3 = 0 for sparse series, the fence is 0 and every sale is capped to 0.

### What to record in the report (Section 3 Before/After)

| Item | Value |
|---|---|
| Rows before / after | equal (no rows removed) |
| Series with a fence / without (fewer than about 8 positive train days) | count |
| Rows above fence (train) | count and % of train rows |
| Units above fence | units above fence, and % of train units |
| Max sales | value (unchanged) |
| Share of above-fence days that are weekend / event | % vs the share of all days |
| Rationale | this section |

## Split decision: cut by week_idx, not by day (Phase 2, decided 2026-11-10)

### Decision

Train/test is cut on **`week_idx` over full 7-day weeks**, not on the day number. The old Week 2 rule `d <= 1868` (train `d_1577`-`d_1868`, test `d_1869`-`d_1941`) is retired for the weekly pipeline.

| Item | Value |
|---|---|
| Window | `d_1577`-`d_1941` = 53 Walmart weeks (`wm_yr_wk` 11517-11617; Walmart weeks run Saturday to Friday) |
| Excluded (partial) | week 1 (11517, 2015-05-24 to 05-29): 6 days; week 53 (11617, 2016-05-21 to 05-22): 2 days. Kept in the view with `n_days`, left out of train, test and KPIs |
| Full weeks | `week_idx` 2-52 = 51 weeks |
| Train | `week_idx` 2-42 (11518-11606, `d_1583`-`d_1869`) = 41 weeks |
| Test | `week_idx` 43-52 (11607-11616, `d_1870`-`d_1939`) = 10 weeks (about 20%, as in the old 80/20 split) |
| `week_idx` | `DENSE_RANK() OVER (ORDER BY wm_yr_wk)` over the window; `wm_yr_wk` itself jumps at year end and is not a counter |

Dates and day counts were checked against `data/raw/calendar.csv`. The weekly view `v_weekly_features` and the split are **verified in MySQL** (results under "Check after the view is built" below); they are **not yet run in KNIME**.

### Reasons

1. **The grain is weekly.** Q1 is judged on held-out weeks, so train and test must be whole weeks. `d_1868` is a Thursday (2016-03-10) inside week 11606, so a day cut puts the first 5 days of that week in train and the last 2 in test. The same `wm_yr_wk` would then sit in both sets.
2. **Partial weeks look like demand drops.** A 2-day week 53 has about 2/7 of the usual units, and a 6-day week 1 about 6/7. In a weekly forecast these read as real falls and distort lags, WAPE and the weekly Actual vs Predicted chart. The roadmap already requires "complete 7-day weeks only" for the KPI queries (e5d).
3. **No leakage across the cut.** With one cut on `week_idx`, every row of a week is on one side, lags (`LAG ... ORDER BY week_idx`) only look backwards, and the leakage check becomes `MIN(test week_idx) > MAX(train week_idx)`.
4. **Consistent with other decisions.** The test length (10 weeks) matches the Limitations item in the roadmap (p6t6). The per-series outlier fence stays "TRAIN only": its train days are the days inside train weeks (`d_1583`-`d_1869`), so the day-level report and the weekly model use the same boundary.

### Cost accepted

- The first 6 days and the last 2 days of the year are not used for training or scoring (8 of 365 days, 2.2%).
- Train is 41 weeks, so the first 2 lagged weeks (`week_idx` 2-3) have no full lag history. Drop them from the lag model or fill them as NULL; do not backfill from the test period.
- Weekday and SNAP effects for Q3 can still be measured at day level on the full 365 days (EDA); only the forecast model uses the weekly split.
- Week 2 deliverables that quote the day cut (`Week2_Person2_Machine_Learning.md`, section 4) describe the old design and should be marked superseded when the Week 3 text is written.

### Check after the view is built

- `n_days < 7` appears exactly for `week_idx` 1 and 53.
- Train rows = 70 x 41 = 2,870; test rows = 70 x 10 = 700 (assuming 10 stores x 7 departments).
- `SUM(sales)` in the view equals `SUM(sales)` in `sales_history`.

**Verified in MySQL (2026-11-10)**: view `v_weekly_features` (defined in `02_feature_engineering.sql`, section 5), checks 5.2 a-e, read once into a temporary table.

| Check | Expected | MySQL result |
|---|---|---|
| a) `SUM(sales)` view vs `sales_history` | diff = 0 | 14,585,821 vs 14,585,821, diff = 0 |
| b) weeks with `n_days < 7` | `week_idx` 1 and 53 only | `week_idx` 1 (11517, 2015-05-24 to 2015-05-29, 6 days) and 53 (11617, 2016-05-21 to 2016-05-22, 2 days), 70 series each |
| c) rows per split | train 2,870 / test 700 / excluded 140 | train 2,870 (`week_idx` 2-42), test 700 (43-52), excluded 140 (1 and 53); 70 series each |
| d) leakage: every test week after every train week | ok = 1 | ok = 1 |
| e) week range | 53 weeks, `wm_yr_wk` 11517-11617 | 53 weeks, 11517 to 11617 |
| Total rows, series | 70 series x 53 weeks | 3,710 rows; 70 series = 10 stores x 7 departments |
| `snap_days` range / `event_days` range | 0-7 | 0-7 / 0-3 |
| `sales` per row (min / max) | n/a | 49 / 23,501 |

Sample (CA_1, FOODS_1): `week_idx` 1 is 6 days and `excluded`; `week_idx` 2 starts 2015-05-30, 7 days, 3,025 units, 5 SNAP days, `train`.

## Data quality audit results (Phase 2, full 365-day data)

Dataset: M5 last 365 days (`d_1577`-`d_1941`, 2015-05-24 to 2016-05-22), 11,128,850 rows = 30,490 item-store series x 365 days. Supersedes the Week 1 audit, which ran on `LIMIT 100000`.

> **Verification status.** Figures were computed by streaming the raw CSVs (`calendar.csv`, `m5_sales_last_365_days.csv`, `sell_prices.csv`). The matching SQL is `process/sql/data_manipulating/01_full_year_stats_and_quality_audit.sql` and `02_structural_zeros.sql`. **Verified in MySQL (2026-11-10): queries A.1 to A.3, Part B (B.1-B.4), the four-dimension audit, the structural zeros and the weekly view with its split** (blocks below and in "Split decision"). Not run: section 4 of `02_feature_engineering.sql` (informational list) and the KNIME steps. Run it and confirm before submitting.

### Verified in MySQL: A.1 full-year statistics (2026-11-10)

Source: `process/sql/result/03_kpi_queries.sql`, query A.1, run on `bigdataprj` (`sales_history`). Every value matches the figure computed from the CSVs.

| Figure | MySQL result | Matches CSV figure |
|---|---|---|
| `total_rows` | 11,128,850 | yes |
| `distinct_days` | 365 | yes |
| `total_units` | 14,585,821 | yes |
| `min_sales` | 0 | yes |
| `max_sales` | 349 | yes |
| `mean_sales` | 1.311 | yes |
| `sd_sales` (sample SD) | 3.634 | yes |
| `zero_rows` | 6,590,443 | yes |
| `zero_pct` | 59.22 | yes |

### Verified in MySQL: A.2 category shares, full year (2026-11-10)

Source: `process/sql/result/03_kpi_queries.sql`, query A.2, run on `bigdataprj` (`sales_history`). Unit shares match the CSV-based figures (65.87% / 9.80% / 24.33%).

| `cat_id` | `row_cnt` | `row_share_pct` | `units` | `unit_share_pct` | `mean_sales` |
|---|---|---|---|---|---|
| FOODS | 5,245,050 | 47.13 | 9,607,704 | 65.87 | 1.832 |
| HOBBIES | 2,062,250 | 18.53 | 1,429,391 | 9.80 | 0.693 |
| HOUSEHOLD | 3,821,550 | 34.34 | 3,548,726 | 24.33 | 0.929 |
| **Total** | 11,128,850 | 100.00 | 14,585,821 | 100.00 | 1.311 |

Cross-check against A.1: row counts sum to 11,128,850 and units to 14,585,821.

### Verified in MySQL: A.3 state / store (2026-11-10)

Source: `03_kpi_queries.sql`, query A.3. Every store has 1,112,885 rows (3,049 items x 365 days).

| `state_id` | `store_id` | `row_cnt` | `units` | `mean_sales` |
|---|---|---|---|---|
| CA | CA_1 | 1,112,885 | 1,627,681 | 1.463 |
| CA | CA_2 | 1,112,885 | 1,482,388 | 1.332 |
| CA | CA_3 | 1,112,885 | 2,298,523 | 2.065 |
| CA | CA_4 | 1,112,885 | 911,180 | 0.819 |
| TX | TX_1 | 1,112,885 | 1,167,967 | 1.049 |
| TX | TX_2 | 1,112,885 | 1,414,938 | 1.271 |
| TX | TX_3 | 1,112,885 | 1,374,532 | 1.235 |
| WI | WI_1 | 1,112,885 | 1,326,144 | 1.192 |
| WI | WI_2 | 1,112,885 | 1,672,973 | 1.503 |
| WI | WI_3 | 1,112,885 | 1,309,495 | 1.177 |

### Verified in MySQL: Part B, Q2 and Q3 metrics (2026-11-10)

Source: `03_kpi_queries.sql`, queries B.0-B.4, run on `bigdataprj`. B.0 created the view `v_state_cat_day` (state x category x day, 3,285 rows). The view is not materialised, so each query on it rescans `sales_history` (minutes per query).

#### B.1 Q2 growth per store x category (last 28 days d_1914-d_1941 vs first 28 days d_1577-d_1604)

Regional growth (all 10 stores, units-weighted) = **+14.18%**. `gap_pp` = growth minus regional growth. `flag_10pp` = 1 when |gap| > 10.

| Store | Category | first28 | last28 | growth_pct | gap_pp | flag_10pp |
|---|---|---|---|---|---|---|
| CA_2 | FOODS | 54,390 | 87,218 | 60.36 | 46.18 | 1 |
| WI_3 | FOODS | 59,999 | 84,176 | 40.30 | 26.12 | 1 |
| WI_2 | FOODS | 81,800 | 114,133 | 39.53 | 25.35 | 1 |
| CA_2 | HOBBIES | 9,523 | 12,557 | 31.86 | 17.68 | 1 |
| CA_2 | HOUSEHOLD | 25,646 | 33,145 | 29.24 | 15.06 | 1 |
| WI_2 | HOBBIES | 6,608 | 8,404 | 27.18 | 13.00 | 1 |
| CA_4 | HOUSEHOLD | 13,444 | 16,142 | 20.07 | 5.89 | 0 |
| CA_4 | FOODS | 43,195 | 51,640 | 19.55 | 5.37 | 0 |
| WI_2 | HOUSEHOLD | 27,151 | 31,439 | 15.79 | 1.62 | 0 |
| WI_1 | FOODS | 68,454 | 78,933 | 15.31 | 1.13 | 0 |
| TX_2 | HOBBIES | 10,476 | 11,818 | 12.81 | -1.37 | 0 |
| WI_3 | HOBBIES | 7,058 | 7,948 | 12.61 | -1.57 | 0 |
| TX_3 | HOBBIES | 10,378 | 11,624 | 12.01 | -2.17 | 0 |
| TX_3 | FOODS | 69,408 | 77,102 | 11.09 | -3.09 | 0 |
| TX_2 | HOUSEHOLD | 24,825 | 27,202 | 9.58 | -4.60 | 0 |
| WI_3 | HOUSEHOLD | 21,006 | 22,651 | 7.83 | -6.35 | 0 |
| TX_2 | FOODS | 71,127 | 76,238 | 7.19 | -6.99 | 0 |
| TX_1 | HOUSEHOLD | 25,077 | 26,837 | 7.02 | -7.16 | 0 |
| CA_1 | HOBBIES | 14,460 | 15,405 | 6.54 | -7.64 | 0 |
| CA_1 | FOODS | 85,554 | 90,833 | 6.17 | -8.01 | 0 |
| WI_1 | HOBBIES | 11,316 | 12,009 | 6.12 | -8.05 | 0 |
| TX_1 | FOODS | 58,835 | 62,345 | 5.97 | -8.21 | 0 |
| TX_1 | HOBBIES | 7,911 | 8,349 | 5.54 | -8.64 | 0 |
| WI_1 | HOUSEHOLD | 20,512 | 21,502 | 4.83 | -9.35 | 0 |
| CA_4 | HOBBIES | 10,778 | 11,076 | 2.76 | -11.41 | 1 |
| CA_1 | HOUSEHOLD | 28,155 | 27,794 | -1.28 | -15.46 | 1 |
| CA_3 | HOUSEHOLD | 50,468 | 48,824 | -3.26 | -17.43 | 1 |
| CA_3 | HOBBIES | 17,256 | 16,666 | -3.42 | -17.60 | 1 |
| TX_3 | HOUSEHOLD | 28,888 | 27,884 | -3.48 | -17.65 | 1 |
| CA_3 | FOODS | 115,123 | 109,870 | -4.56 | -18.74 | 1 |

**B.1b threshold helper** (30 store-categories):

| threshold_pp | 5 | 7.5 | 10 | 12.5 | 15 | 20 |
|---|---|---|---|---|---|---|
| n_flagged | 23 | 18 | 12 | 11 | 10 | **3** |

**Finding for Q2.** The provisional 10 pp threshold flags 12 of 30 store-categories, far above the target of about 2-4 flags. Only **20 pp (3 flags: CA_2 FOODS, WI_3 FOODS, WI_2 FOODS on the upside; CA_3 FOODS at -18.74 does not reach 20)** meets the 2-4 target. Decide the final threshold and update Q2 above. Note that CA_3 is still the weakest store (FOODS -4.56%, HOUSEHOLD -3.26%, HOBBIES -3.42%), consistent with the earlier "CA_3 -4%".

#### B.2 / B.2b Q3 SNAP uplift (mean daily units on SNAP days over non-SNAP days; every state-category has 120 SNAP days)

| State | Category | avg_snap_day | avg_non_snap_day | snap_uplift_pct |
|---|---|---|---|---|
| CA | FOODS | 11,525.69 | 10,856.41 | 6.16 |
| CA | HOBBIES | 1,978.78 | 1,924.43 | 2.82 |
| CA | HOUSEHOLD | 4,384.03 | 4,252.43 | 3.09 |
| TX | FOODS | 7,586.68 | 6,620.08 | 14.60 |
| TX | HOBBIES | 1,058.84 | 1,030.89 | 2.71 |
| TX | HOUSEHOLD | 2,933.35 | 2,830.56 | 3.63 |
| WI | FOODS | 9,727.44 | 7,613.01 | 27.77 |
| WI | HOBBIES | 944.26 | 928.62 | 1.68 |
| WI | HOUSEHOLD | 2,621.80 | 2,533.44 | 3.49 |

| State (all categories) | snap_uplift_pct (B.2b) | Earlier figure |
|---|---|---|
| CA | 5.02 | +6.0% |
| TX | 10.47 | +10.1% |
| WI | 20.03 | +20.5% |

**Finding for Q3.** The MySQL day-level figures differ slightly from the earlier ones (CA 5.02 vs 6.0, TX 10.47 vs 10.1, WI 20.03 vs 20.5). The conclusion is unchanged with the 10% threshold: WI and TX trigger extra stock, CA does not. By category, only **FOODS** passes 10% (TX 14.60, WI 27.77); HOBBIES and HOUSEHOLD stay under 4% everywhere.

#### B.3 Q3 weekday profile: % vs the mean of all days (M5 `wday`: 1 = Saturday, 2 = Sunday, 3 = Monday ... 7 = Friday)

| State | Category | Sat | Sun | Mon | Tue | Wed | Thu | Fri |
|---|---|---|---|---|---|---|---|---|
| CA | FOODS | 20.04 | 24.89 | -2.37 | -11.16 | -13.40 | -13.14 | -4.85 |
| CA | HOBBIES | 19.21 | 15.83 | -6.12 | -8.63 | -8.29 | -9.09 | -2.92 |
| CA | HOUSEHOLD | 25.96 | 29.26 | -2.60 | -13.09 | -15.77 | -16.48 | -7.28 |
| TX | FOODS | 12.46 | 21.02 | 0.73 | -9.92 | -11.61 | -8.67 | -4.01 |
| TX | HOBBIES | 13.61 | 17.39 | -3.43 | -10.32 | -8.52 | -7.68 | -1.05 |
| TX | HOUSEHOLD | 19.76 | 20.40 | -2.78 | -11.90 | -12.56 | -9.95 | -2.98 |
| WI | FOODS | 19.31 | 15.52 | -6.45 | -10.23 | -10.28 | -8.24 | 0.37 |
| WI | HOBBIES | 28.86 | 6.23 | -12.96 | -14.42 | -9.45 | -8.65 | 10.39 |
| WI | HOUSEHOLD | 26.02 | 12.11 | -11.01 | -15.21 | -13.16 | -8.11 | 9.38 |

**B.3b** weekend (Sat + Sun) vs weekday uplift over all rows: **+30.52%** (earlier figure +30.5%, confirmed).

#### B.4 Q3 event days vs non-event days (30 event days per state-category)

| State | Category | event_days | event_uplift_pct |
|---|---|---|---|
| CA | FOODS | 30 | -2.84 |
| CA | HOBBIES | 30 | -9.00 |
| CA | HOUSEHOLD | 30 | -5.44 |
| TX | FOODS | 30 | -0.70 |
| TX | HOBBIES | 30 | -7.06 |
| TX | HOUSEHOLD | 30 | -6.11 |
| WI | FOODS | 30 | -3.70 |
| WI | HOBBIES | 30 | -12.94 |
| WI | HOUSEHOLD | 30 | -10.82 |

**Finding for Q3.** Event days are *lower* than non-event days in every state-category (-0.70% to -12.94%), so events are not a stock-up trigger. This agrees with the earlier "about -4%".

### Week 1/2 figures replaced (p2t6)

`LIMIT 100000` = 3.28 days (`d_1577`-`d_1580`), because rows are stored in day order with 30,490 series per day. Every Week 1/2 statistic described four days.

| Statistic | Week 1/2 sample (4 days) | Full year |
|---|---|---|
| Rows | 100,000 | 11,128,850 |
| Mean sales | 1.153 | **1.311** |
| SD | 3.147 | **3.634** |
| Max | 194 | **349** |
| FOODS / HOBBIES / HOUSEHOLD, share of units | 61.7% / 11.2% / 27.1% | **65.87% / 9.80% / 24.33%** |

### Four-dimension audit (p2t7)

| Dimension | Check | Result | Verdict |
|---|---|---|---|
| Completeness | Blank/NULL in any of 8 columns | 0 | Pass |
| | Rows per day | exactly 30,490 on every day | Pass |
| | Rows with no `calendar` match | 0 | Pass |
| | Rows with no price (store, item, week) | 21,049 (0.19%), all `sales = 0` | Explained (structural zeros) |
| Uniqueness | Duplicate (`id`, `day`) | 0 | Pass |
| Validity | Negative `sales` | 0 | Pass |
| | `day` outside `d_1577`-`d_1941` | 0 | Pass |
| | `id` format / store-state mismatch | 0 | Pass |
| | `sell_price <= 0` (6,841,121 price rows) | 0 (min 0.01, max 107.32) | Pass |
| Consistency / outliers | IQR rule | reviewed, **retained** | see below |

The table is structurally clean; the only quality issue is the distribution of `sales`.

**Verified in MySQL (2026-11-10)** with `01_schema_and_import.sql`, section 5 (5.2 to 5.5d). Every check below equals the CSV-based figure in the table above.

| Check (query) | MySQL result |
|---|---|
| Blank / NULL in `id`, `item_id`, `dept_id`, `cat_id`, `store_id`, `state_id`, `day`, `sales` (5.2) | 0 in all 8 columns |
| Days whose row count is not 30,490 (5.2b) | 0 |
| Rows without a `calendar` match (5.2c) | 0 |
| Duplicate (`id`, `day`): 11,128,850 rows vs 11,128,850 distinct (5.3) | 0 |
| Negative `sales`, bad `day` format, `day` outside d_1577-d_1941, `id` format mismatch, store/state mismatch (5.4) | 0 each |
| `sell_prices`: 6,841,121 rows, `sell_price <= 0` (5.4) | 0 (min 0.01, max 107.32) |
| Global IQR (5.5): Q1 / Q3 / upper bound | 0 / 1 / 2.5 |
| Before (raw): rows / units / max / mean / SD (5.5b) | 11,128,850 / 14,585,821 / 349 / 1.311 / 3.634 |
| Sensitivity "After" (sales <= 2.5): rows / units / max / mean / SD (5.5b) | 9,543,861 / 3,922,806 / 2 / 0.411 / 0.667 |
| Rows above the bound (5.5c) | 1,584,989 (14.24%) |
| Units above the bound (5.5c) | 10,663,015 (73.11%) |
| Tail sizes > 5 / > 10 / > 20 / > 50 units (5.5d) | 582,827 / 210,710 / 60,231 / 7,602 |

Not covered by these queries: "rows with no price (21,049)" and the structural-zero counts, which come from `02_feature_engineering.sql` (section 3 below).

### Outliers: evidence for keeping them

59.22% of rows are zero, median 0, Q1 = 0, Q3 = 1, p99 = 15, max 349 (about 96 SD above the mean). The old global IQR rule (k = 1.5) gives an upper bound of 2.5, so any day with 3+ units is an "outlier":

| Effect of the global IQR cut | Value |
|---|---|
| Rows flagged | 1,584,989 (14.24%) |
| Units discarded | 10,663,015 (**73.1%** of all units) |
| Mean | 1.311 -> 0.411 (-68.6%) |
| Max | 349 -> 2 |

Tail sizes: > 5 units 582,827 rows (5.24%); > 10 210,710 (1.89%); > 20 60,231 (0.54%); > 50 7,602 (0.07%). This is a long tail of real demand, not a few corrupt records (no negatives, duplicates or format errors). Cutting would bias the forecast low on exactly the high-demand days the stock-out questions depend on, and would change the evaluation target.

Before/After (decision: nothing removed):

| Metric | Raw | After audit |
|---|---|---|
| Rows | 11,128,850 | 11,128,850 |
| Units | 14,585,821 | 14,585,821 |
| Mean / SD / Max | 1.311 / 3.634 / 349 | 1.311 / 3.634 / 349 |

The IQR numbers are a sensitivity result only. The per-series fence reporting is defined in "Outlier policy decision" above.

Modelling implications: OLS is pulled by the tail, so report MAE and WAPE (not RMSE alone) and clip predictions at 0. A log or count model (log1p, Poisson/Tweedie) is an optional comparison. Keep high-demand days in the test weeks.

### Structural zeros: flagged, not removed (p2t8)

| Flag | Rule | Rows |
|---|---|---|
| `store_closed` | store sold 0 units all day | 9,147 (CA_1, CA_4, TX_2 on 2015-12-25) |
| `on_sale = 0` | no price row for store, item, week | 21,049 (all `sales = 0`) |
| Both | overlap | 10 |
| **Structural zeros** | union | **30,186** (0.27% of rows, 0.46% of zeros) |

On 2015-12-25 the chain sold 14 units in total (next lowest day: 23,631 on Thanksgiving). The other 6,560,257 zeros (99.5%) are genuine zero-demand days and stay as they are. No flagged row has `sales > 0`. Flags live in the view `v_sales_features`.

**Verified in MySQL (2026-11-10)** with `02_feature_engineering.sql`, sections 1-3. Every count equals the CSV-based figure above.

| Check (query) | MySQL result |
|---|---|
| Store-days with 0 total sales (1.1) | 3 rows: CA_1, CA_4, TX_2 on 2015-12-25 (d_1792, Christmas) |
| Chain units on 2015-12-25, then the next lowest days (1.2) | 14; then 23,631 (2015-11-26, Thanksgiving), 27,581 (2015-11-27), 29,174 (2015-11-17), 29,964 (2015-12-28) |
| `total_rows` / `zero_rows` (3) | 11,128,850 / 6,590,443 |
| `store_closed_rows` (3) | 9,147 (= 3 stores x 3,049 items) |
| `not_on_sale_rows` (3) | 21,049 |
| `both_flags` (3) | 10 |
| `structural_zero_rows` (3) | 30,186 |
| `true_demand_zero_rows` (3) | 6,560,257 |
| `flagged_but_nonzero` (3), sanity check | 0 |

Section 4 of that script (not-on-sale rows by store and department, an informational list) was stopped after about 9 minutes (the view `v_sales_features` scans 11M rows with two joins) and is **not run**. No decision figure depends on it.

### Conclusions

1. The raw table is complete, unique, valid and fully joinable to `calendar`.
2. Week 1/2 statistics were a 4-day artefact and are replaced by the full-year figures above.
3. High values are genuine demand, so no outlier is removed.
4. Zero-heavy demand (59% zeros) is the main modelling risk; it is handled by model choice and evaluation, not by deleting data.
5. 30,186 structural zeros are flagged so "not on the shelf / store closed" is separated from "no demand".

### Remaining actions

- [ ] Run `01_full_year_stats_and_quality_audit.sql` and `02_structural_zeros.sql` in MySQL and confirm the figures.
- [ ] Replace the Week 1 Before/After table and category shares with this version.
- [ ] Remove `LIMIT 100000` and the Numeric Outliers node from the KNIME workflow.

## Model results: weekly Linear Regression, full run (Phase 3, 2026-11-10)

Workflow `Bigdata_final_weekly` (KNIME 5.12), model name `LinearRegression_weekly_v1`, run on the full weekly table (`v_weekly_model` reading `weekly_features`, 3,710 rows). Scoring is on the 10 held-out test weeks (`week_idx` 43-52).

> **Verification status.** Metrics were recomputed in Python from the 700 predictions that the KNIME DB Writer wrote to `sales_predictions_weekly` (joined to `v_weekly_model` for `lag1`, `roll4`, state and SNAP days). Definitions match the KNIME Numeric Scorer and GroupBy nodes: MAE, RMSE, R2 = 1 - SSE/SST, WAPE = 100 x sum|error| / sum(actual), bias = 100 x (sum forecast - sum actual) / sum actual. The script is `process/knime/collect_run_numbers.py`; every figure below is in `process/numbers_collected.csv` with its source. **Not yet cross-checked against the Numeric Scorer output on screen** (read it in KNIME and compare MAE, RMSE, R2 before quoting).

### Pipeline checks (all pass)

| Check | Result |
|---|---|
| Rows the DB Query Reader returns (`model_ready = 1`) | 3,290 (70 series x 47 weeks) |
| Train / test rows | 2,590 (weeks 6-42) / 700 (weeks 43-52) |
| Leakage margin: MIN(test week) - MAX(train week) | 43 - 42 = 1 week; the two KNIME GroupBy checks show 42 and 43 |
| NULL lags in the rows the model reads | 0 |
| Rows written for `LinearRegression_weekly_v1` / distinct (store, dept, week) keys | 700 / 700 |
| MIN(predicted_sales) written | 101.48 (never negative, so the clip at 0 never fired; clipped and unclipped WAPE are identical) |
| Rows where `actual_sales` differs from `weekly_features.sales` | 0 |
| Learner coefficients | 7 coefficients, no NaN. A refit on the train rows reproduces the written predictions exactly (maximum difference 0.0000 units) |

Not yet shown: the **re-run check** (second Reset all + Execute all keeps the table at 700 rows, roadmap e3e). Run it, then re-run the collection script and compare `N157`.

### Q1: forecast accuracy (target WAPE <= 10%): met

| Predictor | WAPE | MAE | RMSE | R2 |
|---|---:|---:|---:|---:|
| Linear Regression (as written) | **6.80%** | 290.2 | 540.3 | 0.9855 |
| Last week (`lag1`) | 7.65% | 326.6 | 642.7 | 0.9795 |
| Average of the last 4 weeks (`roll4`) | 6.70% | n/a | n/a | n/a |

- The model beats the last-week baseline on every metric, and in 6 of 10 test weeks on WAPE.
- **Caveat:** the 4-week average is a slightly better predictor than the model on total WAPE (6.70% vs 6.80%), although the model wins 8 of 10 weeks against it. The model is mostly a lag blend, so its gain over a simple average is small. Report it as such.
- Weekly WAPE across the test weeks: lowest 4.39% (week 49), highest 12.13% (week 50). One week is above the 10% ceiling; the pooled WAPE is below it.
- Pooled R2 is high because series differ greatly in size; it is not a measure of week-to-week skill.

Learner coefficients (target `sales_s` = `sales` / series mean; features scaled the same way): Intercept 0.3419, `snap_days` 0.0078, `event_days` -0.0220, `closed_days` -0.0798, `lag1_s` 0.4893, `lag2_s` -0.2149, `roll4_s` 0.3801. The lag terms carry the forecast; the SNAP and event terms are small at weekly grain.

### Where the forecast errs

| Slice | Lowest WAPE | Highest WAPE |
|---|---|---|
| Store | CA_3 4.40% | WI_2 10.81% |
| Department | HOUSEHOLD_1 5.36% | HOBBIES_2 13.52% |
| Week | week 49, 4.39% | week 50, 12.13% |

### SQ-B: state bias (act when beyond +/-5% and not caused by one store): not triggered

| State | Bias |
|---|---:|
| CA | -2.50% |
| TX | -2.66% |
| WI | **-4.98%** (just inside the 5% line) |

- All three states under-forecast. Total bias is -3.31%.
- SNAP weeks (`snap_days > 0`, 413 rows) have bias -4.89%; non-SNAP weeks (287 rows) -0.92%. The under-forecast sits in SNAP weeks.
- State correction trial (not a KNIME node): factors fitted on test weeks 43-47 (CA x1.014, TX x1.014, WI x1.047) and applied to weeks 48-52 lower the held-out MAE from 304.3 to 279.8 and the total bias from -4.28% to -2.01%. Both improve, so the accept rule would be met. One trial on 5 weeks is a first look only.

### Workflow structure

28 nodes in 7 annotated sections: Connect 2, Ingest 1, Prepare 4, Split + leakage check 4, Model 3, Evaluate 10, Write-back 4. The deck guide (`required_numbers.md`) expects 8 sections; map them by hand.

### Not yet available

| Item | Why |
|---|---|
| Run time (N066) | The log shows 39 s for the last run, but it was run in stages by hand. Time one clean Reset all + Execute all. |
| Re-run growth (N067, N033) | Needs a second run. |
| Numeric Scorer cross-check (N161) | Needs the values read on screen in KNIME. |
| Capped-outlier sensitivity (N195) | No capped branch in the workflow (outliers are retained by decision). |
| Revenue error (SQ-A) | Done 2026-11-10: `weekly_revenue` and `v_pred_eval` built, see "Dashboard data and answers to the decision questions" below. |

### Remaining actions

- [ ] Compare the Numeric Scorer MAE, RMSE and R2 in KNIME with the figures above.
- [ ] Run the workflow a second time and confirm `sales_predictions_weekly` stays at 700 rows for this model.
- [ ] Add the 4-week-average branch to the workflow (it is the stronger baseline) and re-test the model against it.
- [ ] Investigate week 50 (`week_idx` 50): actual 315,125 vs forecast 277,162 units (bias -12.05%, WAPE 12.13%) is the one week above the 10% ceiling and the main source of the total bias of -3.31%. Weeks 46 (-4.81%) and 52 (-5.41%) also under-forecast. Check what is special in those weeks (SNAP days, events, calendar) before adding features.
- [ ] Update the Q1 and SQ-B "Evidence so far" / "Open" lines above with these figures when the numbers are confirmed.

## Dashboard data and answers to the decision questions (Power BI, 2026-11-10)

### How the data reaches Power BI

- MySQL objects built from `03_kpi_queries.sql`: B.0 (`state_cat_day`, 3,285 rows), C.0 (`weekly_revenue`, 3,710 rows, 30 min run) and C.1 (`v_pred_eval`). `v_pred_eval` returns 700 rows for `LinearRegression_weekly_v1` and 640 for `LinearRegression_weekly_sample`. The dashboard keeps only the main model (parameter `ModelName`); both models together would double every card.
- Power BI Desktop could not use the MySQL connector on this machine ("unable to find a database provider with invariant name 'MySql.Data.MySqlClient'", MySQL Connector/NET missing). The four datasets were exported from MySQL to CSV instead: `dashboard/data/v_pred_eval.csv`, `state_cat_day.csv`, `growth_store_cat.csv` (B.1, reduced to `first28`, `last28`) and `top_items.csv`. The CSV route is a fallback: the course brief asks for a dashboard fed from MySQL, so say in the report that the CSVs are exports of the MySQL views and that the numbers were reconciled (below). Switch back to `MySQL.Database(...)` once the connector is installed.
- Reconciliation, MySQL vs the CSV the dashboard reads (main model): rows 700 / 700, actual units 2,988,549 / 2,988,549, forecast units 2,889,551 / 2,889,551, WAPE 6.80% / 6.80%, RMSE 540.29 / 540.29. The Power BI cards must show the same values.
- Top-20 items were summed store by store (the one-shot `GROUP BY item_id` over 11M rows ran out of memory with `max_heap_table_size` = 16 MB); the total over all items is 14,585,821 units, equal to `sales_history`.

### Answers

| Question | Result | Dashboard visual (page) | Decision for the RIM |
|---|---|---|---|
| **Q1** forecast, WAPE <= 10% | WAPE **6.80%**, RMSE 540.3, bias -3.31%. 51 of 70 store-department series are within 10%; **19 are above**. Worst: HOBBIES_2 (TX_2 19.0%, TX_1 16.0%, TX_3 14.1%, CA_4 14.0%, CA_2 13.7%) and WI_2 FOODS_2 17.6%. By category: FOODS 7.25%, HOBBIES 6.25%, HOUSEHOLD 5.70% | Cards and Actual vs Predicted line (Overview); WAPE by store x department table (Stores and states) | Use the forecast for the weekly reorder of the 51 series inside the target. Review the 19 above 10% by hand, starting with HOBBIES_2 and WI_2 FOODS_2. |
| **Q2** growth, flag if the gap to regional growth (+14.18%) is above the threshold | 10 pp flags 12 of 30 store-categories (too many). **20 pp flags 3**: CA_2 FOODS +46.2, WI_3 FOODS +26.1, WI_2 FOODS +25.4. The slowest, CA_3 FOODS -18.7, TX_3 HOUSEHOLD -17.7 and CA_3 HOBBIES -17.6, stay just inside 20 | Growth gap bar and flag table (Demand drivers) | Set the threshold at 20 pp (team decision, still open). Shift allocation toward CA_2, WI_3 and WI_2 FOODS. CA_3 is the slow-growth store to take stock from, but it does not reach the flag. The cause of the CA_2 FOODS jump was not checked (price, new items, store change). |
| **Q3** uplift > 10% | SNAP uplift by state: **WI +20.0%**, **TX +10.5%**, CA +5.0%. By category only FOODS exceeds 10%: WI FOODS +27.8%, TX FOODS +14.6%, CA FOODS +6.2%; HOBBIES and HOUSEHOLD stay at +1.7% to +3.6%. Weekend (Sat + Sun) +30.5% over weekdays. Event days are **lower** than normal days in every state-category (-0.7% to -12.9%) | SNAP uplift, event uplift and weekday profile (Demand drivers) | Add FOODS stock one week ahead of SNAP days in WI and TX, not in CA. Add stock before weekends. Do not stock up for events. |
| **SQ-A** revenue error, review any store above 20% of total revenue error | Weekly revenue MAE per store: **WI_2 $9,277 (20.6% of total error)**, CA_2 $8,484 (18.8%), WI_3 $4,724 (10.5%), then 5.8% to 9.6% for the other seven. Only WI_2 is flagged | Revenue error table (Stores and states) | Put WI_2 first in the weekly reorder review, CA_2 second. The top three stores are the same in units (WI_2, CA_2, WI_3). CA_2 carries 18.8% of the dollar error but 13.8% of the unit error, which fits a price-mix effect (not tested). |
| **SQ-B** state bias beyond +/-5% | CA -2.50%, TX -2.66%, **WI -4.98%**. Not triggered, but WI is right at the line and all three under-forecast | Bias by state and state-to-store matrix (Stores and states) | No state correction yet. Re-check WI with the next KNIME run (the held-out correction trial above already improves MAE and bias). |

Dollar view of the same test weeks (estimate: predicted units x actual price mix of the week): actual revenue $9,423,437, forecast $9,140,073. Under-forecast revenue (stock-out risk) is **$458,707** against **$175,343** of over-forecast (excess stock), about 2.6 to 1. The error costs more by running short than by over-stocking, which supports a small upward adjustment of the reorder quantities in the SNAP weeks.

### Explanation and limits

- Q1 is judged on pooled WAPE, which is below 10% even though 19 series are above it; a small series can be far off in percent and cost little in units. That is why the per-series table is part of the answer, not only the card.
- The Q2 and Q3 figures come from the daily data over the whole window (EDA), not from the weekly model. Growth compares the same weeks of the year (25 Apr to 22 May 2016 against 24 May to 20 Jun 2015) but one year only, so a seasonal or store-specific one-off cannot be separated from real growth.
- SNAP uplift is a timing effect inside a month (benefit payment days), not a lever Walmart controls.
- Revenue figures use the price mix of the actual week for the forecast side (the weekly model has no SKU detail), so SQ-A ranks stores by dollar error but the dollar amounts are estimates.
- The thresholds (10% WAPE, 10% uplift, 20 pp growth, 20% revenue error share, +/-5% bias) are the team's; only the Q2 growth threshold changed from the provisional 10 pp after counting flags (20 pp gives 3).
