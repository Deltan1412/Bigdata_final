# KNIME guide: weekly Linear Regression workflow (store x department x week)

Covers roadmap **p3t4 - p3t12, e3b, e3e**. Do the steps in order. Every step ends with a check, so you know it worked before you move on.

> **Status of the SQL this guide depends on.** `v_weekly_features` (script `02_feature_engineering.sql`, section 5) and `sales_predictions_weekly` (script `04_sales_predictions_schema.sql`, section 3) are written but had **not been run** when this guide was written. Run them first (Step 0). The query in Step 2 is also untested until it has been run once in MySQL.

> **Where the old design stands.** The workflow in `process/knime/Bigdata_final.knwf` is the old item x store x day model (1% sample, `d <= 1868`, R2 0.016). Build the new workflow as a **copy** (`File > Save As`), so the old one stays as evidence for Week 2.

---

## 0. Before you open KNIME

| # | Do | Check |
|---|---|---|
| 0.1 | In MySQL Workbench run `02_feature_engineering.sql`, section 5 (creates `v_weekly_features`) | the five checks at the end of section 5 return: diff = 0; partial weeks only `week_idx` 1 and 53; train 2,870 / test 700 / excluded 140 rows; `ok = 1`; 53 weeks |
| 0.2 | Run `04_sales_predictions_schema.sql`, section 3 (creates `sales_predictions_weekly`) | `DESCRIBE sales_predictions_weekly` lists 10 columns and the key `uk_prediction_weekly` |
| 0.3 | Optional but recommended: materialise the view (`02`, section 5.1, three commented lines) so KNIME does not rescan 11M rows | `SELECT COUNT(*) FROM weekly_features` = 3,710 (70 series x 53 weeks) |
| 0.4 | **Back up before the first write:** `mysqldump -u root -p bigdataprj sales_predictions > sales_predictions_backup.sql` (the old table; the new one is empty) | the file exists and is not empty |
| 0.5 | Have the MySQL JDBC driver in KNIME (`File > Preferences > KNIME > Databases`); KNIME 5.x ships with one | the MySQL Connector node later connects |

---

## 1. Section layout (do this first)

Make the workflow readable before you add nodes: eight **annotation boxes** (right-click the canvas > *New Workflow Annotation*), one colour each, in this order left to right:

`1 Connect` > `2 Ingest` > `3 Check` > `4 Split` > `5 Model` > `6 Evaluate` > `7 Write-back` > `8 Verify`

Put each node inside its box as you add it. Roadmap p3t12 asks for this at the end; doing it as you go is cheaper.

---

## 2. Connect (credentials never inside the file) - roadmap e3b

1. Add **Credentials Configuration**. Parameter name `mysql_cred`, username `root` (or your user). Leave the password empty here: KNIME asks for it when you execute and does not store it in the workflow.
2. Add **MySQL Connector**. Host `localhost`, port `3306`, database `bigdataprj`. Authentication: **Credentials**, select `mysql_cred`.
3. Connect the Credentials Configuration's flow-variable port to the MySQL Connector.

**Check:** execute both nodes; the MySQL Connector turns green. Open the Connector's *Flow Variables* tab: no password is visible.

> Do not choose "Username & password" with the password typed in. That writes it into the exported `.knwf`, which is the Security item graded in component 4.

---

## 3. Ingest: DB Query Reader on the weekly view - roadmap p3t4, p3t6

Remove the old `LIMIT 100000` / `CRC32(...) % 100 = 0` query. Use this one. It builds the lag features in SQL because **KNIME's Lag Column node does not respect series boundaries**: it would give the first week of store B the last week of store A.

```sql
SELECT f.store_id, f.state_id, f.dept_id, f.cat_id,
       f.wm_yr_wk, f.week_idx, f.first_day, f.n_days, f.split,
       f.sales, f.snap_days, f.event_days, f.month_of_week,
       LAG(f.sales, 1) OVER w                                        AS lag1,
       LAG(f.sales, 2) OVER w                                        AS lag2,
       AVG(f.sales)    OVER (PARTITION BY f.store_id, f.dept_id
                             ORDER BY f.week_idx
                             ROWS BETWEEN 4 PRECEDING AND 1 PRECEDING) AS roll4,
       m.series_mean
FROM v_weekly_features f
JOIN (SELECT store_id, dept_id, AVG(sales) AS series_mean
      FROM v_weekly_features
      WHERE split = 'train'
      GROUP BY store_id, dept_id) m
  ON m.store_id = f.store_id AND m.dept_id = f.dept_id
WINDOW w AS (PARTITION BY f.store_id, f.dept_id ORDER BY f.week_idx)
ORDER BY f.store_id, f.dept_id, f.week_idx;
```

Why it is built this way:

- `series_mean` uses **train weeks only**, so scaling by it leaks nothing from the test weeks.
- The lags only look backwards (`LAG`, `4 PRECEDING AND 1 PRECEDING`), so no test value reaches a train row.
- Week 1 has only 6 days. A lag from it looks like a demand drop. So **train only on `week_idx >= 6`**: from week 6 the rolling mean of 4 weeks sees full weeks only (weeks 2-5). Test weeks (43-52) are unaffected.

**Check:** run the node. Expect 3,710 rows (70 x 53). `lag1` is NULL only for `week_idx` 1; `roll4` is NULL for `week_idx` 1.

---

## 4. Check the data (Missing Value, outliers) - roadmap p3t5

1. **Missing Value** node: strategy for numeric columns *Do nothing* on the columns you keep (the weekly view has no NULLs except `lag1`, `lag2`, `roll4` in the first weeks). Those rows are removed by the Row Filter in Step 5 (`week_idx >= 6`); do not impute them.
2. **Statistics** node (or *Data Explorer*) on the output: min / max / missing per column. Take a screenshot for the report.
3. **Outliers: follow the decision, not the old roadmap line.** `process/misc/decision_results.md` (2026-11-10) decided that outliers are **retained**: nothing is removed or capped in the pipeline. Roadmap item p3t5 still describes "replace with closest permitted value"; that line is outdated. So:
   - do **not** put a Numeric Outliers node in the main path;
   - the per-series fence is a **report** (SQL, see the end of `01_schema_and_import.sql`), not an edit;
   - optional sensitivity run: a second branch with **Numeric Outliers** (IQR 1.5, group by `store_id` + `dept_id`, upper bound only, *Replace by closest permitted value*), fitted on raw vs capped, scored on raw actuals. Report it as a sensitivity, not as the model.

**Check:** row count out of this section = row count in (3,710).

---

## 5. Split and leakage check - roadmap p3t9

1. **Row Filter** (rule-based): keep rows where `week_idx >= 6` and `n_days = 7`. Use the week number, not "lag is not missing": `lag1` and `roll4` are not NULL in weeks 2-5, but they would be built from the 6-day week 1.
2. **Rule-based Row Splitter**, rule:
   ```
   $split$ = "train" => TRUE
   ```
   Top port = train, bottom port = test. Test weeks 43-52 are full weeks, so the Row Filter does not touch them.
3. Leakage check, for each output of the splitter: **GroupBy** with no group column, aggregation *Minimum* and *Maximum* of `week_idx`. Join the two one-row tables with **Column Appender**, then a **Rule Engine**:
   ```
   $Minimum(week_idx)_test$ > $Maximum(week_idx)_train$ => "OK, no leakage"
   TRUE => "LEAKAGE"
   ```
   Show the result in a **Table View** node.

**Check:** train = 70 x 37 = **2,590** rows (weeks 6-42), test = **700** rows (weeks 43-52), result "OK, no leakage".

---

## 6. Model - roadmap p3t2 (kept), p3t6

Scale by the series mean so one linear model can serve a small and a large series. Apply to **both** train and test with the same `series_mean` (already train-only).

1. **Math Formula** (one node per column, replace column off, new column names):
   - `sales_s = $sales$ / $series_mean$`
   - `lag1_s = $lag1$ / $series_mean$`
   - `lag2_s = $lag2$ / $series_mean$`
   - `roll4_s = $roll4$ / $series_mean$`
2. **Linear Regression Learner** (train branch):
   - Target: `sales_s`
   - Include: `lag1_s`, `lag2_s`, `roll4_s`, `snap_days`, `event_days`, `month_of_week`, `dept_id` (nominal, dummy-coded by the Learner)
   - Do **not** include `item_id` (none here), `store_id`, `wm_yr_wk`, `week_idx`, `series_mean`, `sales`.
3. **Regression Predictor** (model port from the Learner, test table into the data port).
4. **Math Formula**: `predicted_unclipped = $Prediction (sales_s)$ * $series_mean$`
5. **Math Formula**: `predicted_sales = max(0, $predicted_unclipped$)`

Write the final feature list in the report (lags, SNAP, event, weekday/month). The weekly model has no weekday feature because a week contains every weekday once; the weekday effect is measured at day level (Q3, `03_kpi_queries.sql`, part B).

**Check:** open the Learner's *Coefficients and Statistics* view; no coefficient is NaN. `Prediction` has no missing values.

---

## 7. Evaluate - roadmap p3t7, p3t8, p3t11

The **Numeric Scorer** returned NaN before. Do not use it. Compute the metrics with Math Formula + GroupBy on the **unclipped** column, then repeat on the clipped one and report both.

1. **Math Formula** nodes on the test table:
   - `err = $predicted_unclipped$ - $sales$`
   - `abs_err = abs($err$)`
   - `sq_err = $err$ * $err$`
   - `err_c = $predicted_sales$ - $sales$`, `abs_err_c`, `sq_err_c` (clipped version)
2. **GroupBy** (no group column): *Mean* of `abs_err` = **MAE**; *Mean* of `sq_err` then **Math Formula** `sqrt(...)` = **RMSE**; *Sum* of `abs_err`, *Sum* of `sales`, *Sum* of `err`, *Sum* of `sq_err`, *Mean* of `sales`.
3. **Math Formula** on that one-row table:
   - `WAPE = 100 * $Sum(abs_err)$ / $Sum(sales)$`
   - `Bias = 100 * $Sum(err)$ / $Sum(sales)$`
   - `R2 = 1 - $Sum(sq_err)$ / SST`, where SST = sum over test rows of `(sales - mean(sales))^2`. Get it with one more Math Formula on the test table (`($sales$ - <mean>)^2`, using the mean as a flow variable from the GroupBy) and a GroupBy Sum.
4. **Baselines** on the same test rows:
   - last week: `abs(($sales$) - $lag1$)` in the same GroupBy pattern. WAPE = 100 * Sum / Sum(sales)
   - predict 0: WAPE = 100 by construction
   The model must beat both. (The SQL equivalent is `03_kpi_queries.sql`, C.4.)
5. **Residuals by store, department, SNAP week**: **GroupBy** on `store_id`, `dept_id`, and on `snap_days > 0`, aggregating *Sum* of `err` and `abs_err`. Also **GroupBy** on `state_id` for state bias (feeds SQ-B).

**Check:** MAE, RMSE, WAPE, Bias, R2 are all numbers. Compare with the SQL version after the write-back: `03_kpi_queries.sql`, C.3 must agree to the third decimal. Q1 target: WAPE <= 10%.

---

## 8. Write-back without duplicates - roadmap p3t10

1. **Column Filter / Rename / Constant Value Column** to match `sales_predictions_weekly` exactly:

   | Table column | From |
   |---|---|
   | `store_id`, `dept_id`, `wm_yr_wk`, `week_idx` | same names |
   | `forecast_day` | `first_day` (rename) |
   | `predicted_sales` | `predicted_sales` (clipped, >= 0) |
   | `actual_sales` | `sales` (rename) |
   | `model_name` | Constant Value Column, string `LinearRegression_weekly_v1` |
   | `id`, `prediction_date` | leave out (auto-filled by MySQL) |

2. **DB SQL Executor** (connected to the MySQL Connector): 
   ```sql
   TRUNCATE TABLE sales_predictions_weekly;
   ```
   Run it only after the backup in Step 0.4. TRUNCATE is irreversible; the table holds nothing you cannot recreate, but make sure you are on `sales_predictions_weekly`, not the old `sales_predictions`.
3. **DB Writer**: connection from the SQL Executor's output port (this forces TRUNCATE to run first), table `sales_predictions_weekly`, *Append* mode, table structure *Do not change*.
4. **DB Query Reader** after the writer (connect the Writer's connection port to it):
   ```sql
   SELECT model_name, COUNT(*) AS rows_n, MIN(predicted_sales) AS min_pred,
          COUNT(DISTINCT store_id, dept_id, wm_yr_wk) AS distinct_keys
   FROM sales_predictions_weekly GROUP BY model_name;
   ```

**Check:** one row: `rows_n = 700`, `distinct_keys = 700`, `min_pred >= 0`.

---

## 9. Gate: run it twice - roadmap e3e

1. `Reset all` (right-click the workflow), then `Execute all`. Note `rows_n`.
2. Execute everything a second time (reset, execute). `rows_n` must still be **700**. If the DB Writer fails with a duplicate-key error, the TRUNCATE did not run first: check the connection from the SQL Executor to the Writer.
3. Run `03_kpi_queries.sql`, C.2 and C.3 in MySQL: `mismatched_actuals = 0`, and the SQL metrics equal the KNIME metrics.

---

## 10. Clean up and export - roadmap p3t12

1. Delete unused nodes and the old branches (Numeric Outliers on the main path, the CRC32 query).
2. Make sure every node sits in its annotation box and has a one-line label (right-click > *Edit node label*).
3. Export **one** workflow in its executed state (roadmap e3e asks for it): `File > Export KNIME Workflow`, and leave **Reset workflow(s) before export** unticked. Keep the file under about 50 MB (the weekly tables are small). Save as `knime/Bigdata_final.knwf` in the repository.
4. Delete or move away the old copies: the repository root and `process/knime/` each hold a different `.knwf`; only one may remain in the repo.
5. Architecture image: right-click the empty canvas > *Export as Image* (PNG), save as `knime/knime_pipeline_architecture.png`.
6. Open the exported `.knwf` in a text editor (it is a zip: unzip it) and search for your password. It must not be there.

---

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| Numeric Scorer returns NaN / a warning | Missing or non-finite values in the predicted column. Use the Math Formula metrics in Step 7. |
| `Duplicate entry ... for key 'uk_prediction_weekly'` | The table was not emptied. The SQL Executor with TRUNCATE must run before the Writer (Step 8.2-8.3). |
| `rows_n` is 1,400 after a second run | Same as above: APPEND mode doubles the table without the TRUNCATE. |
| Learner says "too many nominal values" | `store_id` or `item_id` was left in the include list. Only `dept_id` (7 values) is nominal. |
| Predictions look 100x too small or large | The predicted column is still scaled. Multiply by `series_mean` (Step 6.4) before clipping and writing. |
| DB Query Reader is very slow | Query the materialised `weekly_features` table (Step 0.3) instead of the view. |
| R2 looks high but the model is weak | Pooled R2 is inflated by the series level (a big store-department vs a small one). Report WAPE and the baselines next to it. |

---

## Checklist (copy into the roadmap when done)

- [ ] 0.1-0.4 SQL objects exist and are checked
- [ ] e3b credentials not saved in the file
- [ ] p3t4 weekly query, no sample, no `LIMIT`
- [ ] p3t5 outlier policy follows decision_results.md (report, not edit)
- [ ] p3t6 lags and rolling mean in the feature list
- [ ] p3t7 MAE, RMSE, R2, WAPE, clipped and unclipped
- [ ] p3t8 baselines beaten
- [ ] p3t9 leakage check shows "OK"
- [ ] p3t10 truncate, then write, 700 rows, `min_pred >= 0`
- [ ] p3t11 residuals by store, department, SNAP week, state
- [ ] p3t12 annotations, clean canvas, one `.knwf`, architecture PNG
- [ ] e3e run twice, still 700 rows
