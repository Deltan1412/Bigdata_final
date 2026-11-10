-- ==============================================================================
-- Script Name : 03_kpi_queries.sql
-- Purpose     : Business KPI queries: filtering, aggregation, and forecast accuracy.
-- Database    : bigdataprj   (MySQL 8.0)
-- Needs       : Parts A and B: 01 and 02 (02 section 5.1 builds weekly_features).
--               Part C: also 04_sales_predictions_schema.sql (the table) and the KNIME
--               write-back (the rows). Run order is 01 -> 02 -> 04 -> KNIME -> 03 Part C.
--
-- Built from  : data_manipulating/01_full_year_stats_and_quality_audit.sql
--               (sections 1, 1.1, 1.2: the descriptive statistics)
--
-- The data-quality checks from that script are in 01_schema_and_import.sql, section 5.
-- ==============================================================================

USE `bigdataprj`;

-- ==============================================================================
-- PART A. Descriptive KPIs on the full 365-day window (d_1577-d_1941)
--         These replace the Week 1/2 figures that came from LIMIT 100000 (4 days).
-- ==============================================================================

-- A.1 Full-year statistics
SELECT COUNT(*)                                   AS total_rows,        -- 11,128,850
       COUNT(DISTINCT day)                        AS distinct_days,     -- 365
       SUM(sales)                                 AS total_units,       -- 14,585,821
       MIN(sales)                                 AS min_sales,
       MAX(sales)                                 AS max_sales,         -- 349
       ROUND(AVG(sales), 3)                       AS mean_sales,        -- 1.311
       ROUND(STDDEV_SAMP(sales), 3)               AS sd_sales,          -- 3.634
       SUM(sales = 0)                             AS zero_rows,         -- 6,590,443
       ROUND(100 * SUM(sales = 0) / COUNT(*), 2)  AS zero_pct           -- 59.22
FROM sales_history;

-- A.2 Category shares, full year
--     (Week 1/2 showed FOODS 61.7% / HOBBIES 11.2% / HOUSEHOLD 27.1% of units = 4 days;
--      full year: 65.87% / 9.80% / 24.33%)
SELECT cat_id,
       COUNT(*)                                                 AS row_cnt,
       ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)         AS row_share_pct,
       SUM(sales)                                               AS units,
       ROUND(100 * SUM(sales) / SUM(SUM(sales)) OVER (), 2)     AS unit_share_pct,
       ROUND(AVG(sales), 3)                                     AS mean_sales
FROM sales_history
GROUP BY cat_id
ORDER BY cat_id;

-- A.3 Same by state / store (supports the stock-out and state-bias questions)
SELECT state_id, store_id, COUNT(*) AS row_cnt, SUM(sales) AS units, ROUND(AVG(sales), 3) AS mean_sales
FROM sales_history
GROUP BY state_id, store_id
ORDER BY state_id, store_id;

-- ==============================================================================
-- PART B. Decision-question metrics that need NO predictions (Q2, Q3)
--         STATUS: B.1-B.4 verified in MySQL (decision_results.md, 2026-11-10). B.0 is now a
--         table (re-run it) and B.5-B.6 are new, not yet run. None of them waits for the
--         KNIME run.
--         Thresholds (10 pp, 10%) are the provisional values in decision_results.md.
-- ==============================================================================

-- B.0 State x category x day, with the calendar flags (3,285 rows). One scan of
--     sales_history, stored as a table so Power BI and every query below read 3,285 rows
--     instead of rescanning 11M. `v_state_cat_day` stays as a thin view over the table, so
--     existing queries and the Power BI import keep working. Column `weekday` (name) was
--     added so charts can show Saturday ... Friday; sort it by `wday` (1 = Saturday).
DROP VIEW  IF EXISTS `v_state_cat_day`;
DROP TABLE IF EXISTS `state_cat_day`;
CREATE TABLE `state_cat_day` AS
SELECT t.state_id, t.cat_id, t.day, c.date, c.wday, c.weekday,
       CASE t.state_id WHEN 'CA' THEN c.snap_CA WHEN 'TX' THEN c.snap_TX ELSE c.snap_WI END AS snap,
       CASE WHEN c.event_name_1 IS NOT NULL OR c.event_name_2 IS NOT NULL THEN 1 ELSE 0 END AS is_event,
       t.sales
FROM (SELECT state_id, cat_id, day, SUM(sales) AS sales
      FROM sales_history GROUP BY state_id, cat_id, day) t
JOIN calendar c ON c.d = t.day;
ALTER TABLE `state_cat_day` ADD PRIMARY KEY (`state_id`, `cat_id`, `day`);
CREATE VIEW `v_state_cat_day` AS SELECT * FROM `state_cat_day`;

-- B.1 Q2: growth per store x category, last 28 days (d_1914-d_1941) vs first 28 days
--     (d_1577-d_1604), same season. gap_pp = growth minus the regional growth
--     (all 10 stores, weighted by units). flag = |gap| > 10 pp (provisional: choose the
--     threshold so about 2-4 rows flag; see the second query).
WITH sc AS (
    SELECT store_id, cat_id,
           SUM(CASE WHEN CAST(SUBSTRING(day, 3) AS UNSIGNED) BETWEEN 1577 AND 1604 THEN sales ELSE 0 END) AS first28,
           SUM(CASE WHEN CAST(SUBSTRING(day, 3) AS UNSIGNED) BETWEEN 1914 AND 1941 THEN sales ELSE 0 END) AS last28
    FROM sales_history
    WHERE CAST(SUBSTRING(day, 3) AS UNSIGNED) BETWEEN 1577 AND 1604
       OR CAST(SUBSTRING(day, 3) AS UNSIGNED) BETWEEN 1914 AND 1941
    GROUP BY store_id, cat_id
), g AS (
    SELECT sc.*,
           100 * (last28 / first28 - 1)                                       AS growth_pct,
           100 * (SUM(last28) OVER () / SUM(first28) OVER () - 1)             AS regional_growth_pct
    FROM sc
)
SELECT store_id, cat_id, first28, last28,
       ROUND(growth_pct, 2)                                  AS growth_pct,
       ROUND(regional_growth_pct, 2)                         AS regional_growth_pct,
       ROUND(growth_pct - regional_growth_pct, 2)            AS gap_pp,
       CASE WHEN ABS(growth_pct - regional_growth_pct) > 10 THEN 1 ELSE 0 END AS flag_10pp
FROM g
ORDER BY gap_pp DESC;

-- B.1b Threshold helper: how many store-categories would flag at each threshold
WITH sc AS (
    SELECT store_id, cat_id,
           SUM(CASE WHEN CAST(SUBSTRING(day, 3) AS UNSIGNED) BETWEEN 1577 AND 1604 THEN sales ELSE 0 END) AS first28,
           SUM(CASE WHEN CAST(SUBSTRING(day, 3) AS UNSIGNED) BETWEEN 1914 AND 1941 THEN sales ELSE 0 END) AS last28
    FROM sales_history
    WHERE CAST(SUBSTRING(day, 3) AS UNSIGNED) BETWEEN 1577 AND 1604
       OR CAST(SUBSTRING(day, 3) AS UNSIGNED) BETWEEN 1914 AND 1941
    GROUP BY store_id, cat_id
), g AS (
    SELECT 100 * (last28 / first28 - 1) - 100 * (SUM(last28) OVER () / SUM(first28) OVER () - 1) AS gap_pp
    FROM sc
)
SELECT t.threshold_pp, SUM(ABS(g.gap_pp) > t.threshold_pp) AS n_flagged, COUNT(*) AS n_store_categories
FROM g
CROSS JOIN (SELECT 5 AS threshold_pp UNION ALL SELECT 7.5 UNION ALL SELECT 10
            UNION ALL SELECT 12.5 UNION ALL SELECT 15 UNION ALL SELECT 20) t
GROUP BY t.threshold_pp
ORDER BY t.threshold_pp;

-- B.2 Q3: SNAP uplift per state x category = mean daily units on SNAP days over mean on
--     non-SNAP days, minus 1. Act when uplift > 10% (provisional).
--     Earlier figures to confirm: WI +20.5%, TX +10.1%, CA +6.0% (all categories).
SELECT state_id, cat_id,
       ROUND(AVG(CASE WHEN snap = 1 THEN sales END), 2)                                       AS avg_snap_day,
       ROUND(AVG(CASE WHEN snap = 0 THEN sales END), 2)                                       AS avg_non_snap_day,
       ROUND(100 * (AVG(CASE WHEN snap = 1 THEN sales END) / AVG(CASE WHEN snap = 0 THEN sales END) - 1), 2) AS snap_uplift_pct,
       SUM(snap = 1)                                                                          AS snap_days
FROM v_state_cat_day
GROUP BY state_id, cat_id
ORDER BY state_id, cat_id;

-- B.2b The same for each state over all categories (compare with the figures above)
SELECT state_id,
       ROUND(100 * (AVG(CASE WHEN snap = 1 THEN sales END) / AVG(CASE WHEN snap = 0 THEN sales END) - 1), 2) AS snap_uplift_pct
FROM (SELECT state_id, day, MAX(snap) AS snap, SUM(sales) AS sales FROM v_state_cat_day GROUP BY state_id, day) x
GROUP BY state_id;

-- B.3 Q3: weekday profile per state x category: each weekday (wday 1 = Saturday in M5)
--     against the mean of all days.
SELECT state_id, cat_id, wday,
       ROUND(AVG(sales), 2)                                                         AS avg_units,
       ROUND(100 * (AVG(sales) / AVG(AVG(sales)) OVER (PARTITION BY state_id, cat_id) - 1), 2) AS vs_mean_pct
FROM v_state_cat_day
GROUP BY state_id, cat_id, wday
ORDER BY state_id, cat_id, wday;

-- B.3b Weekend vs weekday (Sat + Sun = wday 1, 2). Earlier figure: +30.5% over all rows.
SELECT ROUND(100 * (AVG(CASE WHEN wday IN (1, 2) THEN sales END) / AVG(CASE WHEN wday NOT IN (1, 2) THEN sales END) - 1), 2) AS weekend_uplift_pct
FROM (SELECT day, MAX(wday) AS wday, SUM(sales) AS sales FROM v_state_cat_day GROUP BY day) x;

-- B.4 Q3: event days vs non-event days per state x category (earlier figure: about -4%)
SELECT state_id, cat_id,
       SUM(is_event = 1)                                                                          AS event_days,
       ROUND(100 * (AVG(CASE WHEN is_event = 1 THEN sales END) / AVG(CASE WHEN is_event = 0 THEN sales END) - 1), 2) AS event_uplift_pct
FROM v_state_cat_day
GROUP BY state_id, cat_id
ORDER BY state_id, cat_id;

-- B.5 Series demand profile: one row per item x store series (30,490 rows), one scan of
--     sales_history. Feeds the top-items and Pareto charts (B.6), the intermittency figure
--     behind Recommendation 3 (roadmap p6t4) and the optional K-Means segmentation (p6t5).
--       nz_days      days with sales > 0
--       zero_share   share of the days with no sale
--       adi          average inter-demand interval = days / nz_days (NULL if never sold)
--       cv2          squared coefficient of variation of the NON-ZERO daily sizes
--       demand_class Syntetos-Boylan classes: adi < 1.32 and cv2 < 0.49 smooth;
--                    adi < 1.32 erratic; cv2 < 0.49 intermittent; otherwise lumpy
DROP TABLE IF EXISTS `series_demand_profile`;
CREATE TABLE `series_demand_profile` AS
SELECT p.*,
       CASE WHEN p.nz_days = 0                      THEN 'no sales'
            WHEN p.adi < 1.32 AND p.cv2 < 0.49      THEN 'smooth'
            WHEN p.adi < 1.32                       THEN 'erratic'
            WHEN p.cv2 < 0.49                       THEN 'intermittent'
            ELSE 'lumpy' END                        AS demand_class
FROM (SELECT s.id, s.item_id, s.dept_id, s.cat_id, s.store_id, s.state_id,
             COUNT(*)                                                AS n_days,
             SUM(s.sales)                                            AS units,
             SUM(s.sales > 0)                                        AS nz_days,
             ROUND(1 - SUM(s.sales > 0) / COUNT(*), 4)               AS zero_share,
             ROUND(AVG(s.sales), 4)                                  AS mean_daily,
             ROUND(COUNT(*) / NULLIF(SUM(s.sales > 0), 0), 3)        AS adi,
             ROUND(POW(STDDEV_POP(CASE WHEN s.sales > 0 THEN s.sales END)
                       / NULLIF(AVG(CASE WHEN s.sales > 0 THEN s.sales END), 0), 2), 3) AS cv2
      FROM sales_history s
      GROUP BY s.id, s.item_id, s.dept_id, s.cat_id, s.store_id, s.state_id) p;
ALTER TABLE `series_demand_profile` ADD PRIMARY KEY (`id`);

-- B.5a Demand-class mix: share of series and of units (expect 30,490 series in total)
SELECT demand_class,
       COUNT(*)                                                     AS series,
       ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)             AS series_pct,
       SUM(units)                                                   AS units,
       ROUND(100 * SUM(units) / SUM(SUM(units)) OVER (), 2)         AS units_pct,
       ROUND(AVG(zero_share), 3)                                    AS avg_zero_share
FROM series_demand_profile
GROUP BY demand_class
ORDER BY series DESC;

-- B.5b Recommendation 3 figure: series that sell on fewer than 10% of days.
--      The roadmap quotes "9% of series sell on <10% of days"; this is its SQL source.
SELECT SUM(nz_days < 0.10 * n_days)                                              AS series_lt10pct_days,
       ROUND(100 * AVG(nz_days < 0.10 * n_days), 2)                              AS pct_of_series,
       ROUND(100 * SUM(CASE WHEN nz_days < 0.10 * n_days THEN units END) / SUM(units), 2) AS pct_of_units
FROM series_demand_profile;

-- B.6 Top 20 items by units over the year (an item is summed over its 10 stores)
SELECT item_id, cat_id, dept_id, SUM(units) AS units,
       ROUND(100 * SUM(units) / SUM(SUM(units)) OVER (), 3) AS unit_share_pct
FROM series_demand_profile
GROUP BY item_id, cat_id, dept_id
ORDER BY units DESC
LIMIT 20;

-- B.6b Pareto: share of all units sold by the top 1% / 10% / 20% of items (roadmap p2t12)
WITH it AS (
    SELECT item_id, SUM(units) AS units FROM series_demand_profile GROUP BY item_id
), r AS (
    SELECT units, ROW_NUMBER() OVER (ORDER BY units DESC, item_id) AS rn, COUNT(*) OVER () AS n
    FROM it
)
SELECT MAX(n)                                                                    AS items,
       ROUND(100 * SUM(CASE WHEN rn <= 0.01 * n THEN units END) / SUM(units), 2) AS top1pct_unit_share,
       ROUND(100 * SUM(CASE WHEN rn <= 0.10 * n THEN units END) / SUM(units), 2) AS top10pct_unit_share,
       ROUND(100 * SUM(CASE WHEN rn <= 0.20 * n THEN units END) / SUM(units), 2) AS top20pct_unit_share
FROM r;

-- ==============================================================================
-- PART C. Forecast-accuracy KPIs (from sales_predictions_weekly, 04 section 3)
--         STATUS: written, NOT YET RUN. Needs the weekly KNIME run to fill the table.
--         Test weeks only, complete 7-day weeks only (n_days = 7).
-- ==============================================================================

-- C.0 Weekly revenue per store x department = SUM(units x price) at SKU-store-day.
--     Built once (scans 11M rows, a few minutes). Rows without a price have sales = 0.
DROP TABLE IF EXISTS `weekly_revenue`;
CREATE TABLE `weekly_revenue` AS
SELECT s.store_id, s.dept_id, c.wm_yr_wk,
       SUM(s.sales * COALESCE(p.sell_price, 0)) AS revenue
FROM sales_history s
JOIN calendar c            ON c.d = s.day
LEFT JOIN sell_prices p    ON p.store_id = s.store_id AND p.item_id = s.item_id AND p.wm_yr_wk = c.wm_yr_wk
GROUP BY s.store_id, s.dept_id, c.wm_yr_wk;
ALTER TABLE `weekly_revenue` ADD PRIMARY KEY (`store_id`, `dept_id`, `wm_yr_wk`);

-- C.1 Evaluation view: one row per store x dept x test week x model.
--     The forecast revenue assumes the actual price mix of that week:
--         forecast revenue = predicted units x (actual revenue / actual units)
--     because the weekly model has no SKU detail. Say this in the report (SQ-A).
CREATE OR REPLACE VIEW `v_pred_eval` AS
SELECT p.model_name, p.store_id, f.state_id, p.dept_id, f.cat_id, p.wm_yr_wk, p.week_idx, f.week_start,
       p.predicted_sales, p.actual_sales,
       p.predicted_sales - p.actual_sales               AS err,
       ABS(p.predicted_sales - p.actual_sales)          AS abs_err,
       r.revenue                                        AS actual_rev,
       p.predicted_sales * r.revenue / NULLIF(p.actual_sales, 0) AS pred_rev,
       -- Dollar trade-off per row (store x dept x week): under-forecast = revenue at stock-out
       -- risk, over-forecast = value of excess stock. Same price-mix assumption as pred_rev.
       GREATEST(r.revenue - p.predicted_sales * r.revenue / NULLIF(p.actual_sales, 0), 0) AS under_rev,
       GREATEST(p.predicted_sales * r.revenue / NULLIF(p.actual_sales, 0) - r.revenue, 0) AS over_rev,
       -- Calendar flags of the forecast week, so Power BI needs no merge with weekly_features
       f.snap_days, f.event_days, f.holiday_days
FROM sales_predictions_weekly p
JOIN weekly_features f ON f.store_id = p.store_id AND f.dept_id = p.dept_id AND f.wm_yr_wk = p.wm_yr_wk
JOIN weekly_revenue r    ON r.store_id = p.store_id AND r.dept_id = p.dept_id AND r.wm_yr_wk = p.wm_yr_wk
WHERE f.n_days = 7 AND f.split = 'test';

-- C.2 Sanity: stored actuals equal the view's actuals                (expect 0)
SELECT COUNT(*) AS mismatched_actuals
FROM sales_predictions_weekly p
JOIN weekly_features f ON f.store_id = p.store_id AND f.dept_id = p.dept_id AND f.wm_yr_wk = p.wm_yr_wk
WHERE ABS(p.actual_sales - f.sales) > 0.0001;

-- C.3 Headline metrics per model (units): MAE, RMSE, WAPE, bias, R2 on the test weeks.
SELECT e.model_name, COUNT(*) AS n_rows,
       ROUND(AVG(e.abs_err), 3)                                       AS mae,
       ROUND(SQRT(AVG(e.err * e.err)), 3)                             AS rmse,
       ROUND(100 * SUM(e.abs_err) / SUM(e.actual_sales), 2)           AS wape_pct,     -- Q1 target <= 10
       ROUND(100 * AVG(e.abs_err / NULLIF(e.actual_sales, 0)), 2)     AS mape_pct,
       ROUND(100 * SUM(e.err) / SUM(e.actual_sales), 2)               AS bias_pct,
       ROUND(1 - SUM(e.err * e.err) / SUM(POW(e.actual_sales - m.mean_actual, 2)), 4) AS r2
FROM v_pred_eval e
JOIN (SELECT model_name, AVG(actual_sales) AS mean_actual FROM v_pred_eval GROUP BY model_name) m
  ON m.model_name = e.model_name
GROUP BY e.model_name;

-- C.4 Baselines on the same test rows (roadmap p3t8): predict 0, and predict last week.
--     A model is worth keeping only if its WAPE in C.3 is below both.
WITH lagged AS (
    SELECT store_id, dept_id, week_idx, split, n_days, sales,
           LAG(sales) OVER (PARTITION BY store_id, dept_id ORDER BY week_idx) AS prev_week
    FROM weekly_features
)
SELECT 'last week' AS baseline, COUNT(*) AS n_rows,
       ROUND(AVG(ABS(sales - prev_week)), 3)                        AS mae,
       ROUND(SQRT(AVG(POW(sales - prev_week, 2))), 3)               AS rmse,
       ROUND(100 * SUM(ABS(sales - prev_week)) / SUM(sales), 2)     AS wape_pct,
       ROUND(100 * AVG(ABS(sales - prev_week) / NULLIF(sales, 0)), 2) AS mape_pct
FROM lagged WHERE split = 'test' AND n_days = 7
UNION ALL
SELECT 'predict 0', COUNT(*), ROUND(AVG(sales), 3), ROUND(SQRT(AVG(POW(sales, 2))), 3), 100.00, 100.00
FROM lagged WHERE split = 'test' AND n_days = 7;

-- C.5 Q1: WAPE per store x department (flag above the 10% target)
SELECT store_id, dept_id,
       ROUND(100 * SUM(abs_err) / SUM(actual_sales), 2)               AS wape_pct,
       CASE WHEN 100 * SUM(abs_err) / SUM(actual_sales) > 10 THEN 1 ELSE 0 END AS above_target
FROM v_pred_eval
GROUP BY store_id, dept_id
ORDER BY wape_pct DESC;

-- C.5b Per week (for the Actual vs Predicted chart; complete weeks only)
SELECT week_idx, MIN(week_start) AS week_start,
       ROUND(SUM(actual_sales), 0)                                    AS actual_units,
       ROUND(SUM(predicted_sales), 0)                                 AS predicted_units,
       ROUND(AVG(abs_err), 3)                                         AS mae,
       ROUND(100 * AVG(abs_err / NULLIF(actual_sales, 0)), 2)         AS mape_pct,
       ROUND(100 * SUM(abs_err) / SUM(actual_sales), 2)               AS wape_pct,
       ROUND(100 * SUM(err) / SUM(actual_sales), 2)                   AS bias_pct
FROM v_pred_eval
GROUP BY week_idx
ORDER BY week_idx;

-- C.5c MAE / MAPE / WAPE / bias per store (roadmap e5d). model_name is in the GROUP BY so a
--      second model (for example a baseline written to the same table) is never mixed in.
SELECT model_name, state_id, store_id, COUNT(*)                       AS n_rows,
       ROUND(AVG(abs_err), 3)                                         AS mae,
       ROUND(100 * AVG(abs_err / NULLIF(actual_sales, 0)), 2)         AS mape_pct,
       ROUND(100 * SUM(abs_err) / SUM(actual_sales), 2)               AS wape_pct,
       ROUND(100 * SUM(err) / SUM(actual_sales), 2)                   AS bias_pct
FROM v_pred_eval
GROUP BY model_name, state_id, store_id
ORDER BY model_name, wape_pct DESC;

-- C.5d The same per department
SELECT model_name, cat_id, dept_id, COUNT(*)                          AS n_rows,
       ROUND(AVG(abs_err), 3)                                         AS mae,
       ROUND(100 * AVG(abs_err / NULLIF(actual_sales, 0)), 2)         AS mape_pct,
       ROUND(100 * SUM(abs_err) / SUM(actual_sales), 2)               AS wape_pct,
       ROUND(100 * SUM(err) / SUM(actual_sales), 2)                   AS bias_pct
FROM v_pred_eval
GROUP BY model_name, cat_id, dept_id
ORDER BY model_name, wape_pct DESC;

-- C.6 SQ-A: weekly revenue error per store. Aggregate to store-week first, then
--     MAE (USD), the store's share of the total absolute revenue error, and the rank
--     compared with the unit-error rank. Flag a store above 20% (provisional).
WITH sw AS (
    SELECT store_id, week_idx,
           SUM(pred_rev) AS pred_rev, SUM(actual_rev) AS actual_rev,
           SUM(predicted_sales) AS pred_u, SUM(actual_sales) AS actual_u
    FROM v_pred_eval
    GROUP BY store_id, week_idx
), s AS (
    SELECT store_id,
           AVG(ABS(pred_rev - actual_rev))                       AS rev_mae_usd,
           SUM(ABS(pred_rev - actual_rev))                       AS abs_rev_err,
           AVG(ABS(pred_u - actual_u))                           AS unit_mae
    FROM sw
    GROUP BY store_id
)
SELECT store_id,
       ROUND(rev_mae_usd, 2)                                     AS rev_mae_usd,
       ROUND(100 * abs_rev_err / SUM(abs_rev_err) OVER (), 2)    AS share_of_rev_error_pct,
       RANK() OVER (ORDER BY rev_mae_usd DESC)                   AS rank_usd,
       ROUND(unit_mae, 2)                                        AS unit_mae,
       RANK() OVER (ORDER BY unit_mae DESC)                      AS rank_units,
       CASE WHEN 100 * abs_rev_err / SUM(abs_rev_err) OVER () > 20 THEN 1 ELSE 0 END AS flag_20pct
FROM s
ORDER BY rev_mae_usd DESC;

-- C.7 SQ-B: bias per state, then per store inside the state, over the test weeks.
--     bias = (sum forecast - sum actual) / sum actual. Act when |bias| > 5% and no single
--     store explains it (look at each store's share of the state's net error).
SELECT state_id, ROUND(SUM(predicted_sales), 0) AS forecast_units, ROUND(SUM(actual_sales), 0) AS actual_units,
       ROUND(100 * SUM(err) / SUM(actual_sales), 2)                    AS bias_pct,
       ROUND(100 * SUM(abs_err) / SUM(actual_sales), 2)                AS wape_pct
FROM v_pred_eval
GROUP BY state_id
ORDER BY state_id;

SELECT state_id, store_id,
       ROUND(100 * SUM(err) / SUM(actual_sales), 2)                    AS store_bias_pct,
       ROUND(100 * SUM(err) / NULLIF(SUM(SUM(err)) OVER (PARTITION BY state_id), 0), 2) AS share_of_state_net_error_pct
FROM v_pred_eval
GROUP BY state_id, store_id
ORDER BY state_id, store_id;

-- C.8 Row funnel for numbers_verified.md: raw rows -> deduplicated rows -> weekly rows
SELECT (SELECT COUNT(*) FROM sales_history)                                                  AS raw_daily_rows,
       (SELECT COUNT(*) FROM weekly_features)                                              AS store_dept_week_rows,
       (SELECT COUNT(*) FROM weekly_features WHERE split = 'test' AND n_days = 7)          AS test_rows_expected,   -- 700
       (SELECT COUNT(*) FROM sales_predictions_weekly)                                       AS predictions_rows,
       (SELECT COUNT(*) FROM v_pred_eval)                                                    AS evaluated_rows;

-- C.9 Residuals by SNAP days in the forecast week (roadmap p3t11). snap_days = days of that
--     week with SNAP benefits in the row's own state (0-7). A bias that grows with snap_days
--     means the model under-uses the SNAP feature.
SELECT model_name, state_id, snap_days, COUNT(*)                      AS n_rows,
       ROUND(AVG(err), 3)                                             AS mean_err,
       ROUND(100 * SUM(err) / SUM(actual_sales), 2)                   AS bias_pct,
       ROUND(100 * SUM(abs_err) / SUM(actual_sales), 2)               AS wape_pct
FROM v_pred_eval
GROUP BY model_name, state_id, snap_days
ORDER BY model_name, state_id, snap_days;

-- C.9b Same for event weeks (any event day in the week) against weeks without one
SELECT model_name, event_days > 0                                     AS event_week, COUNT(*) AS n_rows,
       ROUND(100 * SUM(err) / SUM(actual_sales), 2)                   AS bias_pct,
       ROUND(100 * SUM(abs_err) / SUM(actual_sales), 2)               AS wape_pct
FROM v_pred_eval
GROUP BY model_name, event_days > 0
ORDER BY model_name, event_week;

-- C.10 Dollar trade-off of the forecast error per store (evidence for the recommendations'
--      "expected benefit / trade-off"). under = revenue at stock-out risk (forecast below
--      actual), over = value of excess stock (forecast above actual). Computed per
--      store x dept x week, so errors do not cancel inside a store. pred_rev assumes the
--      actual price mix of the week (see C.1); say so in the report.
SELECT model_name, state_id, store_id,
       ROUND(SUM(actual_rev), 0)                                      AS actual_rev_usd,
       ROUND(SUM(under_rev), 0)                                       AS under_forecast_usd,
       ROUND(SUM(over_rev), 0)                                        AS over_forecast_usd,
       ROUND(100 * SUM(under_rev) / SUM(actual_rev), 2)               AS under_pct_of_rev,
       ROUND(100 * SUM(over_rev) / SUM(actual_rev), 2)                AS over_pct_of_rev
FROM v_pred_eval
GROUP BY model_name, state_id, store_id
ORDER BY model_name, state_id, store_id;

-- ==============================================================================
-- STILL TO DO
-- ==============================================================================
-- [x] Per-series outlier fence report: not needed, outliers are retained (decision_results.md).
-- [ ] Q2 threshold: B.1 still hardcodes 10 pp (flag_10pp) but flags 12 of 30 store-categories;
--     the team must pick the final value (20 pp flags 3) and update B.1 and the Power BI line.
-- [ ] Run Parts B and C and write every headline figure with its SQL into
--     process/numbers_verified.md (roadmap e5f).
-- [ ] A per-state correction factor (SQ-B accept rule): keep it only if bias AND MAE both
--     improve on held-out weeks. Needs a train/validation split of the test weeks.
