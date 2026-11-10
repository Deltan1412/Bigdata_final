# Power BI guide: the final dashboard on the weekly forecast

This guide is self-contained. You do not need the roadmap to follow it. Roadmap task IDs (p5t2, x1, ...) appear only in the checklist at the end, for the person who keeps the roadmap.

**Contents**

1. What you are building and why
2. Which SQL files feed the dashboard (real file names)
3. Step 0: prepare the database
4. Step 1: connect Power BI to MySQL
5. Step 2: model the data (no double counting, dimension tables)
6. Step 3: DAX measures
7. Step 4: build the three pages
8. Step 5: test against SQL
9. Step 6: save and export
10. Troubleshooting
11. Checklist

---

## 1. What you are building and why

### 1.1 The project in one paragraph

We forecast weekly sales for a Walmart-style chain (M5 dataset, 10 stores in CA, TX and WI, 7 departments each, 53 weeks of data). The decision-maker is a **Regional Inventory Manager (RIM)** who sets weekly reorder quantities a week ahead. The pipeline is:

`CSV files -> MySQL -> KNIME (Linear Regression) -> predictions written back to MySQL -> Power BI -> decisions`

The dashboard is the last step. It **only reads MySQL**; it never reads a CSV and it computes nothing that SQL cannot reproduce. Every number on a card must equal the number you get by running the matching SQL query. That is a graded requirement ("Dashboard, insights and decisions", the largest single rubric item, 2.0 of 10 points).

### 1.2 What the course requires of the dashboard

From `Final/requirement/required_files.md`, section D, the deliverable is `m5_sales_forecasting_final.pbix`, an interactive Power BI file connected live to MySQL, with:

| Required component | Our version |
|---|---|
| Executive KPI cards: Total Sales, Predicted Volume, Overall RMSE, Active Outlets | Cards `Actual Units`, `Forecast Units`, `RMSE`, `WAPE`, `Active Stores`, plus a `Records` check card |
| Slicers: date, department, category, state, holiday/SNAP status | State, store, department, week range, SNAP |
| Historical EDA charts: demand trend, day-of-week seasonality, top SKUs | Page 3: weekday profile, SNAP lift, growth by store, top items |
| **Actual vs Predicted** line chart over the out-of-time test window | Page 1 line chart, the 10 test weeks |
| Screenshots of every view in `dashboard/screenshots/` | Four PNG files (section 9) |

The dashboard must also support the **three decision questions** that the whole project answers (full text in `process/misc/decision_results.md`):

| Question | In plain words | Where it is answered |
|---|---|---|
| **Q1 Forecast** | How many units will each store sell per department next week? Target: forecast error (WAPE) at most 10%. | Page 1 cards and line chart; page 2 WAPE by store x department |
| **Q2 Growth** | Which store-categories grew fastest or slowest (last 28 days vs first 28 days) compared with the regional average? Flag a gap above a threshold (provisionally 10 percentage points). | Page 3 growth-by-store bar |
| **Q3 Demand drivers** | By how many percent do SNAP days, weekdays and events raise demand? Act when uplift is above 10%. | Page 3 SNAP lift and weekday profile |
| SQ-A (extra) | Which stores carry the largest forecast error in dollars? | Page 2 revenue error table |
| SQ-B (extra) | Is the forecast systematically too high or too low in some state? | Page 2 bias bar and state/store matrix |

### 1.3 Terms used in this guide

| Term | Meaning |
|---|---|
| **Store x department x week** | The grain of the forecast: one row = one department of one store in one week. 10 stores x 7 departments = 70 series. |
| **Test weeks** | The 10 most recent full weeks (`week_idx` 43 to 52). The model never saw them in training. All accuracy numbers come from these weeks. 70 series x 10 weeks = **700 rows**. |
| **WAPE** | Weighted absolute percentage error = total absolute error / total actual units. Lower is better; target at most 10%. |
| **Bias** | (total forecast - total actual) / total actual. Positive = over-forecast, negative = under-forecast. |
| **MAE / RMSE** | Mean absolute error / root mean squared error, in units. |
| **SNAP** | US food-benefit payment days. Calendar flags per state (`snap_CA`, `snap_TX`, `snap_WI`). Demand rises on those days, mostly for FOODS. |
| **`week_idx`** | Week counter 1 to 53 over the data window (not the same as Walmart's `wm_yr_wk`, which jumps at year end). Weeks 1 and 53 are partial and are excluded from every KPI. |

---

## 2. Which SQL files feed the dashboard

All SQL lives in `Final/process/sql/`. Only the **`result/`** folder is the final, ordered set. The other folders are earlier working material.

```
Final/process/sql/
|-- result/                     <- USE THESE (final, numbered, re-runnable)
|   |-- 01_schema_and_import.sql
|   |-- 02_feature_engineering.sql
|   |-- 03_kpi_queries.sql
|   `-- 04_sales_predictions_schema.sql
|-- data_importing/             old split of 01 (import_calendar / import_sales_history / import_sell_prices). Do not run.
|-- data_manipulating/          old drafts of 01 and 02 and dedupe_sales_predictions.sql. Do not run.
|-- data_exploring/             scratch queries (row_count.sql, test.sql). Ignore.
`-- dump/                       full database backups (bigdataprj_backup_20261109.sql, m5_dump.sql). Restore only to rebuild; not part of the dashboard.
```

### 2.1 What each `result/` file contributes

| File | Section | Creates | Used by Power BI? |
|---|---|---|---|
| `01_schema_and_import.sql` | 1 | table `calendar` (1,969 rows: date, weekday, events, SNAP flags) | **Yes, imported** |
| | 2 | table `sales_history` (11,128,850 rows, daily units per item per store) | **No, never load it whole.** Only the "top items" query reads it. |
| | 3 | table `sell_prices` (6,841,121 rows) | No (feeds `weekly_revenue`) |
| `02_feature_engineering.sql` | 5 | view `v_weekly_features` (store x dept x week, 3,710 rows, with `week_idx`, `week_start`, `snap_days`, `event_days`, `split`) | **Yes, imported** |
| | 1, 2 | `store_day_closed`, view `v_sales_features` (daily features) | No |
| | 6 | views `v_weekly_model`, `v_weekly_model_sample` (lags, for KNIME) | No (KNIME only) |
| `04_sales_predictions_schema.sql` | **3** | table `sales_predictions_weekly` (one row per store x dept x test week x model). **KNIME writes the forecasts here.** | Indirectly, through `v_pred_eval` |
| | 1 | old table `sales_predictions` (item x store x day design, Week 2) | **No. Superseded.** This is the source of the old double counting. |
| `03_kpi_queries.sql` | **B.0** | view `v_state_cat_day` (state x category x day, 3,285 rows) | **Yes, imported** |
| | **C.0** | table `weekly_revenue` (units x price per store x dept x week) | No directly; needed by `v_pred_eval` |
| | **C.1** | view **`v_pred_eval`** (700 rows: actual vs predicted, error, revenue) | **Yes, imported. This is the main table of the dashboard.** |
| | B.1, B.2b, B.3 | growth, SNAP uplift, weekday profile queries | **Yes, pasted as custom SQL on page 3** (section 7.3) |
| | C.2, C.3, C.7 | verification queries | **No. You run them in MySQL to get the numbers the cards must match.** |

Also useful for context (not imported): `Final/process/misc/decision_results.md` (the decision questions and the verified numbers), `Final/process/misc/guide/knime_guide.md` (how the forecasts get into MySQL), `Final/process/misc/guide/required_numbers.md` (every number the slides need, including the Power BI ones).

### 2.2 The five objects Power BI loads

| Power BI table | Comes from | Rows | Used for |
|---|---|---|---|
| `v_pred_eval` | `03_kpi_queries.sql` C.1 | 700 | actual vs predicted, errors, revenue (pages 1 and 2) |
| `v_weekly_features` | `02_feature_engineering.sql` section 5 | 3,710 | SNAP and event days per week (SNAP slicer) |
| `v_state_cat_day` | `03_kpi_queries.sql` B.0 | 3,285 | weekday profile, SNAP lift (page 3) |
| `calendar` | `01_schema_and_import.sql` section 1 | 1,969 | date table |
| custom SQL queries | `03_kpi_queries.sql` B.1, B.2b, B.3 and one top-items query | small | page 3 |

### 2.3 Dependency chain (this is the order that matters)

The headers of the files say "run 01 -> 02 -> 03 -> 04". That is the **file number order**, but the dashboard needs a different **run order**, because `v_pred_eval` reads the predictions table that KNIME fills:

```
01_schema_and_import.sql          calendar, sales_history, sell_prices
        |
02_feature_engineering.sql        v_weekly_features (section 5), KNIME views (section 6)
        |
04_sales_predictions_schema.sql   section 3: empty sales_predictions_weekly
        |
KNIME workflow (knime_guide.md)   fills sales_predictions_weekly with 700 rows
        |
03_kpi_queries.sql                B.0 (v_state_cat_day), C.0 (weekly_revenue), C.1 (v_pred_eval)
        |
Power BI                          reads v_pred_eval, v_weekly_features, v_state_cat_day, calendar
```

If `v_pred_eval` returns 0 rows, the KNIME write-back has not run yet (or `weekly_revenue` is missing).

---

## 3. Step 0: prepare the database

> **Status when this guide was written.** According to `decision_results.md` (2026-11-10), `01_schema_and_import.sql` and parts A and B of `03_kpi_queries.sql` have been run and verified in MySQL (so `calendar`, `sales_history`, `sell_prices` and `v_state_cat_day` exist). `v_weekly_features`, `weekly_revenue`, `sales_predictions_weekly` and `v_pred_eval` were **written but not yet run**, and the weekly KNIME run had not yet filled `sales_predictions_weekly`. Run them first.

| # | Do | Check |
|---|---|---|
| 0.1 | In MySQL Workbench run `02_feature_engineering.sql` section 5 (the `CREATE OR REPLACE VIEW v_weekly_features` statement) | `SELECT COUNT(*) FROM v_weekly_features` = 3710 |
| 0.2 | Run `04_sales_predictions_schema.sql` section 3 (`CREATE TABLE IF NOT EXISTS sales_predictions_weekly`) | table exists |
| 0.3 | Run the KNIME workflow as described in `knime_guide.md`. | `SELECT COUNT(*) FROM sales_predictions_weekly` = 700 |
| 0.4 | Run `03_kpi_queries.sql` **B.0** (`v_state_cat_day`), **C.0** (`weekly_revenue`, scans 11M rows, a few minutes) and **C.1** (`v_pred_eval`) | `SELECT COUNT(*) FROM v_pred_eval` = 700 |
| 0.5 | Run the verification queries **C.2** (expect 0), **C.3**, **C.7** and write the results down | These are the numbers the cards must match |
| 0.6 | Install **MySQL Connector/NET 8.0** if Power BI's MySQL option complains | the connector dialog opens |
| 0.7 | Report theme (View > Themes > Customize current theme): dark teal `#0F2E33`, teal `#1F6F78`, amber `#F2A541`, background `#F3F6F5`. One colour per series, same colours on every visual. | matches the slides |

Do not run the whole of `03_kpi_queries.sql` blindly just to prepare the dashboard. Parts A and B are heavy (minutes each) and only B.0, C.0 and C.1 create objects.

> **Old file.** `Final/process/misc/big-data-analytics-project/m5_dashboard_week2.pbix` is the Week 2 draft. It reads the old item-day table `sales_predictions`, which held every row twice (the "Actual 17.47K = 2 x 8,734" bug). Do not edit it. Build the final file as a **new** `.pbix` and keep the old one as Week 2 evidence.

---

## 4. Step 1: connect Power BI to MySQL

1. `Home > Get data > MySQL database`. Server `localhost:3306`, database `bigdataprj`. Data connectivity mode: **Import** (small tables and fast visuals; use *Refresh* to update). DirectQuery works but is much slower, because the views behind it scan 11M rows.
2. Credentials tab **Database**, your MySQL user and password. Power BI keeps them in its own credential store, not in the `.pbix`. Never type the real password in a document or in the repository.
3. In the Navigator tick **only** these four objects: `v_pred_eval`, `v_weekly_features`, `v_state_cat_day`, `calendar`. **Do not tick `sales_history`** (11M rows).
4. `Transform data` (Power Query) and set types: `week_start` as Date; `wm_yr_wk` and `week_idx` as Whole number. Then, in the Modeling tab, set *Summarization > Don't summarize* on `week_idx` and `wm_yr_wk` so they never become a sum on a visual.

**Check:** the Power Query preview of `v_pred_eval` shows 700 rows.

---

## 5. Step 2: model the data

### 5.1 No double counting

The old card showed 17.47K because the old predictions table held every row twice (KNIME's writer was in APPEND mode). The new table has a UNIQUE key (`store_id, dept_id, wm_yr_wk, model_name`) and holds one model.

1. Add a card **Records** = `COUNTROWS(v_pred_eval)`. It must read **700**.
2. If a second `model_name` is ever written, filter the page to one model (slicer or page filter on `model_name`), otherwise every actual is counted once per model.

**Check:** Records = 700, and the `Actual Units` card equals `SELECT SUM(actual_sales) FROM v_pred_eval` (not double).

### 5.2 Small dimension tables

In Power Query: right-click `v_pred_eval` > *Reference*, keep the columns below, then *Remove duplicates*. Use these tables for slicers and axes, never the fact columns.

| New table | Columns | Relationship (many to one, single direction) |
|---|---|---|
| `Dim_Store` | `store_id`, `state_id` | `v_pred_eval[store_id]` to `Dim_Store[store_id]` |
| `Dim_Dept` | `dept_id`, `cat_id` | `v_pred_eval[dept_id]` to `Dim_Dept[dept_id]` |
| `Dim_Week` | `week_idx`, `week_start` | `v_pred_eval[week_idx]` to `Dim_Week[week_idx]` |

Sort `Dim_Week[week_start]` ascending.

### 5.3 SNAP flag on the fact table

SNAP is per state and per week, so do not relate `v_weekly_features` to a dimension on `week_idx` (that would be many-to-many). Instead bring the columns into the fact table:

1. In Power Query select `v_pred_eval` > *Merge Queries* with `v_weekly_features`, matching on `store_id`, `dept_id` and `wm_yr_wk` (all three), join kind *Left outer*.
2. Expand `snap_days` and `event_days`.
3. Add a column: `snap_week = if [snap_days] > 0 then "SNAP days" else "No SNAP"`.

Use `snap_week` as the SNAP slicer.

---

## 6. Step 3: DAX measures

`Modeling > New measure`. Paste one at a time.

```DAX
Records          = COUNTROWS ( v_pred_eval )
Actual Units     = SUM ( v_pred_eval[actual_sales] )
Forecast Units   = SUM ( v_pred_eval[predicted_sales] )
Error Units      = [Forecast Units] - [Actual Units]
Abs Error Units  = SUMX ( v_pred_eval, ABS ( v_pred_eval[predicted_sales] - v_pred_eval[actual_sales] ) )
MAE              = AVERAGEX ( v_pred_eval, ABS ( v_pred_eval[predicted_sales] - v_pred_eval[actual_sales] ) )
RMSE             = SQRT ( AVERAGEX ( v_pred_eval, ( v_pred_eval[predicted_sales] - v_pred_eval[actual_sales] ) ^ 2 ) )
WAPE             = DIVIDE ( [Abs Error Units], [Actual Units] )
Bias %           = DIVIDE ( [Error Units], [Actual Units] )
Active Stores    = DISTINCTCOUNT ( v_pred_eval[store_id] )

Actual Revenue   = SUM ( v_pred_eval[actual_rev] )
Forecast Revenue = SUM ( v_pred_eval[pred_rev] )
Revenue MAE      =
    AVERAGEX (
        SUMMARIZE ( v_pred_eval, v_pred_eval[store_id], v_pred_eval[week_idx],
                    "p", SUM ( v_pred_eval[pred_rev] ), "a", SUM ( v_pred_eval[actual_rev] ) ),
        ABS ( [p] - [a] )
    )
```

Format `WAPE` and `Bias %` as percentage (1 decimal) and the revenue measures as currency. `Revenue MAE` is computed at store-week level, the same as query C.6 in `03_kpi_queries.sql`.

Note that `pred_rev` is an estimate: predicted units x (actual revenue / actual units) of that week, because the weekly model has no item detail. State this on the revenue visuals.

**Check:** with no slicer selected, `WAPE`, `RMSE`, `MAE` equal the SQL result of query C.3 (SQL shows WAPE as a percent, e.g. 7.1; Power BI shows the same value as 7.1%).

---

## 7. Step 4: build the three pages

Same title position, font and size on every page. Page names: **Overview**, **Stores and states**, **Demand drivers**.

### 7.1 Page 1: Overview (answers Q1)

1. **KPI cards**, top row: `Actual Units`, `Forecast Units`, `WAPE`, `RMSE`, `Active Stores`. A small `Records` card shows the 700 check.
2. **Line chart**: X axis `Dim_Week[week_start]`; values `Actual Units` and `Forecast Units`, both on the **same axis** (no secondary axis). Smoothing off (`Format > Lines > Smooth` off), legend on, Y axis starts at 0. The chart covers the 10 test weeks only.
3. **Slicers**: `Dim_Store[state_id]`, `Dim_Store[store_id]`, `Dim_Dept[dept_id]`, a *Between* slicer on `week_start`, and the SNAP slicer `snap_week` (section 5.3).

### 7.2 Page 2: Stores and states (answers SQ-A and SQ-B, and shows where Q1 fails)

1. **Bar chart, bias by state**: axis `Dim_Store[state_id]`, value `Bias %`. Bars start at zero; do not set a custom axis minimum.
2. **Matrix, state to store reconciliation**: rows `state_id` > `store_id`; values `Forecast Units`, `Actual Units`, `Bias %`, `WAPE`. Expand a state to show a state that looks fine while its stores cancel each other out.
3. **Table or bar, weekly revenue error per store**: `store_id`, `Revenue MAE`, `Actual Revenue`, `Forecast Revenue`.
4. **Bar, WAPE by store x department**, conditional colour: amber above 10% (the Q1 target).

### 7.3 Page 3: Demand drivers (answers Q2 and Q3, historical charts)

These visuals need data that is not in the prediction view. For each: `Home > Get data > MySQL database > Advanced options > SQL statement`, paste the query. Keep each as its own query so `sales_history` is never loaded whole.

| Visual | Query to paste |
|---|---|
| Weekday profile (line or column; wday 1 = Saturday, 2 = Sunday ... 7 = Friday) | `SELECT state_id, cat_id, wday, ROUND(AVG(sales), 2) AS avg_units FROM v_state_cat_day GROUP BY state_id, cat_id, wday` |
| SNAP lift by state (bar), threshold line at 10% | `03_kpi_queries.sql` **B.2b** (uplift per state) or **B.2** (per state and category) |
| Growth by store (bar), threshold line | `03_kpi_queries.sql` **B.1** (per store x category, with `gap_pp` = gap to the regional average) |
| Top items (bar) | `SELECT item_id, SUM(sales) AS units FROM sales_history GROUP BY item_id ORDER BY units DESC LIMIT 20` (scans 11M rows once, takes a few seconds to a minute) |

Notes:

- For growth, show the gap in **percentage points** and add a constant line at the chosen threshold. The threshold is still a team decision: the provisional 10 pp flags 12 of 30 store-categories, only 20 pp gives about 3 (see `decision_results.md`, Q2). Use the value the team agreed.
- B.1 and B.2b contain `WITH` / subqueries. If Power BI rejects the pasted statement, paste only the SELECT part, or run the query in MySQL and save it as a view first.
- `v_state_cat_day` is a view over `sales_history`, so each refresh re-scans 11M rows (minutes). See Troubleshooting for the faster option.

---

## 8. Step 5: test against SQL

Every card must equal the same number computed by SQL.

1. Close and reopen the file. `Home > Refresh`. All visuals still show data.
2. Clear all filters. Compare with MySQL:

| Card | SQL to run |
|---|---|
| `Records` = 700 | `SELECT COUNT(*) FROM v_pred_eval` |
| `Actual Units` | `SELECT SUM(actual_sales) FROM v_pred_eval` |
| `Forecast Units` | `SELECT SUM(predicted_sales) FROM v_pred_eval` |
| `WAPE`, `RMSE`, `MAE`, `Bias %` | `03_kpi_queries.sql` **C.3** (`wape_pct`, `rmse`, `mae`, `bias_pct`) |
| bias by state | **C.7**, first query |
| revenue MAE per store | **C.6** |

3. Filter `state_id = CA`, then `store_id = CA_3`. Run the same SQL with `WHERE store_id = 'CA_3'` on `v_pred_eval` and compare.
4. Write each SQL result and the matching card value into `numbers_verified.md` (the team's verified-numbers log) or, if that file does not exist yet, next to the figures in `decision_results.md`.

**Check:** every card equals its SQL number; none is doubled.

---

## 9. Step 6: save and export

1. Save as `dashboard/m5_sales_forecasting_final.pbix` in the repository (`Final/process/misc/big-data-analytics-project/dashboard/`). The file is about 20 MB; do not commit versions you do not need. Never commit the MySQL password.
2. Screenshots into `dashboard/screenshots/` (Windows: `Win + Shift + S`, or `File > Export > Export to PDF` and crop):
   - `kpi_overview.png` : cards plus filters
   - `actual_vs_predicted.png` : the weekly line chart
   - `state_bias.png` : bias bar and reconciliation matrix
   - `store_error.png` : store revenue error and WAPE by store x department
3. The same images feed slide 18 (interactive dashboard) and slide 19 (live demo fallback) of `Final_Project_Presentation_LAYOUT.pptx`. The numbers shown there are listed in `required_numbers.md` (slide 18 fields N162 to N168).

---

## 10. Troubleshooting

| Symptom | Cause and fix |
|---|---|
| A card shows twice the SQL value | Two models or duplicate rows. Run `SELECT model_name, COUNT(*) FROM sales_predictions_weekly GROUP BY model_name` (expect 700 per model) and filter the page to one model. Make sure the report does not read the old `sales_predictions` table. |
| `v_pred_eval` is empty (0 rows) | KNIME has not written `sales_predictions_weekly`, or `weekly_revenue` was not built (`03_kpi_queries.sql` C.0). Follow the chain in section 2.3. |
| `week_idx` appears as a sum on a chart | Set *Summarization > Don't summarize* on `week_idx` and `wm_yr_wk`. |
| "Unable to connect" to MySQL | Install MySQL Connector/NET 8.0, check the MySQL service is running, and use the *Database* tab for credentials (not *Windows*). |
| Refresh takes minutes | `v_pred_eval` reads `v_weekly_features`, and `v_state_cat_day` reads `sales_history`; both are views that re-scan 11M rows. Faster: materialise them once in MySQL, then point Power BI at the tables. `02_feature_engineering.sql` section 5.1 has the commented statement for `weekly_features`; for the other, `CREATE TABLE state_cat_day AS SELECT * FROM v_state_cat_day;`. The top-items query is the only other heavy one. |
| Line chart looks rounded or smoothed | `Format > Lines > Smooth` off; do not add a trend line or the forecast feature. |
| WAPE shows 0.07, not 7% | Format the measure as a percentage. |
| Pasted SQL fails in the custom query box | Remove the leading comments and trailing `;`, or create a view in MySQL and import the view. |

---

## 11. Checklist (copy into the roadmap when done)

Plain wording first; roadmap ID in brackets for the person who tracks the roadmap.

- [ ] Records card = 700, nothing doubled (p5t2)
- [ ] Weekly Actual vs Predicted line chart, one axis, no smoothing (p5t3)
- [ ] KPI cards: total sales, forecast, WAPE/RMSE, active stores (p5t4)
- [ ] Slicers: store, department, state, SNAP, date range (p5t5)
- [ ] Page 3: weekday profile, SNAP lift, growth by store, top items (p5t6)
- [ ] Revenue KPIs and revenue error per store (p5t7, x1)
- [ ] Bias by state with a zero baseline, and the state vs store matrix (x2, x3)
- [ ] Refresh from MySQL works; filter CA > CA_3; cards equal the SQL numbers (p5t8)
- [ ] Four screenshots exported and the final `.pbix` saved (p5t9)
