-- ==============================================================================
-- Script Name : 02_feature_engineering.sql
-- Purpose     : Join sales_history to calendar and prices, derive the model features
--               (is_holiday, snap, on_sale, store_closed) and flag structural zeros.
-- Database    : bigdataprj   (MySQL 8.0)
-- Needs       : 01_schema_and_import.sql (sales_history, calendar, sell_prices)
--
-- Built from  : data_manipulating/02_structural_zeros.sql
--
-- A zero in `sales` is not always "no demand". Two cases are structural:
--   store_closed : the whole store sold 0 units that day (Dec 25: 3 stores shut,
--                  the other 7 sold only 14 units chain-wide)
--   on_sale      : the item has a price row for that store and week.
--                  M5 has no price row for weeks before the item is introduced,
--                  so on_sale = 0 means "not on the shelf", not "no demand".
-- Both flags let the model and the stock-out analysis separate real zeros.
-- Flagged, NOT removed (decision_results.md, roadmap p2t8).
-- ==============================================================================

USE `bigdataprj`;

-- ------------------------------------------------------------------------------
-- 1. Store-days with zero total sales (tiny table: 3 rows in this window)
-- ------------------------------------------------------------------------------
DROP TABLE IF EXISTS `store_day_closed`;
CREATE TABLE `store_day_closed` (
    `store_id` VARCHAR(10) NOT NULL,
    `day`      VARCHAR(20) NOT NULL,
    PRIMARY KEY (`store_id`, `day`)
) ENGINE=InnoDB;

INSERT INTO `store_day_closed` (`store_id`, `day`)
SELECT store_id, day
FROM sales_history
GROUP BY store_id, day
HAVING SUM(sales) = 0;

-- 1.1 Which days / stores (expect 2015-12-25: CA_1, CA_4, TX_2)
SELECT c.store_id, c.day, cal.date, cal.event_name_1
FROM store_day_closed c JOIN calendar cal ON cal.d = c.day
ORDER BY cal.date, c.store_id;

-- 1.2 Chain-wide units on Dec 25 (expect 14) and the next lowest day for contrast
SELECT cal.date, s.day, SUM(s.sales) AS chain_units
FROM sales_history s JOIN calendar cal ON cal.d = s.day
GROUP BY cal.date, s.day
ORDER BY chain_units
LIMIT 5;

-- ------------------------------------------------------------------------------
-- 2. Feature view used by KNIME / Python instead of the bare calendar join.
--    Columns: date parts (date, wm_yr_wk, wday, month), is_holiday, snap (the
--    state's own SNAP flag), sell_price, on_sale, store_closed.
--    A view keeps it cheap: nothing is materialised until it is read.
-- ------------------------------------------------------------------------------
CREATE OR REPLACE VIEW `v_sales_features` AS
SELECT s.id, s.item_id, s.dept_id, s.cat_id, s.store_id, s.state_id, s.day, s.sales,
       c.date, c.wm_yr_wk, c.wday, c.month,
       CASE WHEN c.event_name_1 IS NOT NULL OR c.event_name_2 IS NOT NULL THEN 1 ELSE 0 END AS is_holiday,
       CASE s.state_id WHEN 'CA' THEN c.snap_CA WHEN 'TX' THEN c.snap_TX ELSE c.snap_WI END  AS snap,
       p.sell_price,
       CASE WHEN p.sell_price IS NOT NULL THEN 1 ELSE 0 END                                  AS on_sale,
       CASE WHEN d.store_id IS NOT NULL THEN 1 ELSE 0 END                                    AS store_closed,
       CAST(SUBSTRING(s.day, 3) AS UNSIGNED)                                                 AS day_num   -- 'd_1577' -> 1577
FROM sales_history s
JOIN calendar c               ON c.d = s.day
LEFT JOIN sell_prices p       ON p.store_id = s.store_id AND p.item_id = s.item_id AND p.wm_yr_wk = c.wm_yr_wk
LEFT JOIN store_day_closed d  ON d.store_id = s.store_id AND d.day = s.day;

-- ------------------------------------------------------------------------------
-- 3. How many zeros are structural? (run once, scans 11M rows)
--    Expect: structural_zero_rows 30,186 (0.27% of rows); store_closed 9,147;
--    not_on_sale 21,049; both 10; flagged_but_nonzero 0.
-- ------------------------------------------------------------------------------
SELECT COUNT(*)                                                         AS total_rows,
       SUM(sales = 0)                                                   AS zero_rows,
       SUM(store_closed = 1)                                            AS store_closed_rows,
       SUM(on_sale = 0)                                                 AS not_on_sale_rows,
       SUM(store_closed = 1 AND on_sale = 0)                            AS both_flags,
       SUM(sales = 0 AND (store_closed = 1 OR on_sale = 0))             AS structural_zero_rows,
       SUM(sales = 0 AND store_closed = 0 AND on_sale = 1)              AS true_demand_zero_rows,
       SUM(sales > 0 AND (store_closed = 1 OR on_sale = 0))             AS flagged_but_nonzero  -- expect 0 (sanity)
FROM v_sales_features;

-- ------------------------------------------------------------------------------
-- 4. Not-on-sale rows by store and department (shows where items are launched mid-window)
-- ------------------------------------------------------------------------------
SELECT store_id, dept_id, COUNT(*) AS not_on_sale_rows
FROM v_sales_features
WHERE on_sale = 0
GROUP BY store_id, dept_id
ORDER BY not_on_sale_rows DESC
LIMIT 20;

-- ==============================================================================
-- 5. Weekly feature view, store x department x week   (roadmap p2t10, p3t4)
--    STATUS: view verified in MySQL (decision_results.md, 2026-11-10). The table in 5.1 is
--    new: run 5.1, then the checks in 5.2 (they now read the table).
--    Spec: process/misc/decision_results.md, "Split decision".
--      - one row per store x department x Walmart week over d_1577-d_1941
--      - week_idx = DENSE_RANK() OVER (ORDER BY wm_yr_wk)   (wm_yr_wk jumps at year end,
--        so it is not a counter)
--      - n_days < 7 only for week_idx 1 (6 days) and 53 (2 days): kept in the view,
--        excluded from train, test and every KPI
--      - split: train week_idx 2-42, test week_idx 43-52, everything else 'excluded'
--      - calendar features per week: snap_days (own state's SNAP days), weekend_days
--        (Sat + Sun), event_days (any event), holiday_days (National + Religious only)
--    The daily table is collapsed to store x dept x day first (25,550 rows), so the
--    calendar join and the weekly grouping run on a small set.
-- ------------------------------------------------------------------------------
CREATE OR REPLACE VIEW `v_weekly_features` AS
SELECT w.*,
       CASE WHEN w.week_idx BETWEEN  2 AND 42 THEN 'train'
            WHEN w.week_idx BETWEEN 43 AND 52 THEN 'test'
            ELSE 'excluded' END                                       AS split
FROM (
    SELECT t.store_id, t.state_id, t.dept_id, t.cat_id,
           c.wm_yr_wk,
           DENSE_RANK() OVER (ORDER BY c.wm_yr_wk)                    AS week_idx,
           MIN(c.date)                                                AS week_start,
           MAX(c.date)                                                AS week_end,
           MIN(t.day)                                                 AS first_day,   -- 'd_1870' (all ids are d_ + 4 digits, so MIN is the earliest)
           COUNT(*)                                                   AS n_days,
           SUM(t.sales)                                               AS sales,
           -- SNAP: days in the week with SNAP benefits for the row's own state
           SUM(CASE t.state_id WHEN 'CA' THEN c.snap_CA
                               WHEN 'TX' THEN c.snap_TX
                               ELSE c.snap_WI END)                    AS snap_days,
           -- Weekend: Saturday + Sunday (M5 wday: 1 = Saturday, 2 = Sunday)
           SUM(CASE WHEN c.wday IN (1, 2) THEN 1 ELSE 0 END)          AS weekend_days,
           -- Any calendar event (holidays, sporting, cultural)
           SUM(CASE WHEN c.event_name_1 IS NOT NULL
                      OR c.event_name_2 IS NOT NULL THEN 1 ELSE 0 END) AS event_days,
           -- Holidays only: National + Religious events
           SUM(CASE WHEN c.event_type_1 IN ('National', 'Religious')
                      OR c.event_type_2 IN ('National', 'Religious')
                    THEN 1 ELSE 0 END)                                AS holiday_days,
           MONTH(MIN(c.date))                                         AS month_of_week
    FROM (SELECT store_id, state_id, dept_id, cat_id, day, SUM(sales) AS sales
          FROM sales_history
          GROUP BY store_id, state_id, dept_id, cat_id, day) t
    JOIN calendar c ON c.d = t.day
    GROUP BY t.store_id, t.state_id, t.dept_id, t.cat_id, c.wm_yr_wk
) w;

-- 5.1 Materialise the view into a table (3,710 rows). Needed for the FULL run:
--     v_weekly_features rescans sales_history (11M rows), about 5 minutes per read, and
--     v_weekly_model (6.2) now reads this table instead. Building it takes about 5 minutes
--     once. Re-run this block whenever sales_history changes.
--     The sample path (6.1, 6.3) does not need it.
DROP TABLE IF EXISTS `weekly_features`;
CREATE TABLE `weekly_features` AS SELECT * FROM `v_weekly_features`;
ALTER TABLE `weekly_features` ADD PRIMARY KEY (`store_id`, `dept_id`, `wm_yr_wk`);

-- 5.2 Checks (all expected values come from decision_results.md)
-- a) Total units equal sales_history                                  (expect diff = 0)
SELECT (SELECT SUM(sales) FROM v_weekly_features) AS weekly_units,
       (SELECT SUM(sales) FROM sales_history)     AS daily_units,
       (SELECT SUM(sales) FROM v_weekly_features)
     - (SELECT SUM(sales) FROM sales_history)     AS diff;

-- b) Partial weeks are exactly week_idx 1 (6 days) and 53 (2 days)    (expect 2 rows)
SELECT week_idx, wm_yr_wk, MIN(week_start) AS week_start, MAX(week_end) AS week_end,
       MIN(n_days) AS min_days, MAX(n_days) AS max_days, COUNT(*) AS series
FROM v_weekly_features
WHERE n_days < 7
GROUP BY week_idx, wm_yr_wk;

-- c) Series and rows per split           (expect 70 series; train 2,870; test 700; excluded 140)
SELECT split, COUNT(*) AS rows_n, COUNT(DISTINCT store_id, dept_id) AS series,
       MIN(week_idx) AS first_week_idx, MAX(week_idx) AS last_week_idx
FROM v_weekly_features
GROUP BY split
ORDER BY first_week_idx;

-- d) Leakage check: every test week is after every train week         (expect ok = 1)
SELECT MIN(CASE WHEN split = 'test'  THEN week_idx END)
     > MAX(CASE WHEN split = 'train' THEN week_idx END) AS ok
FROM v_weekly_features;

-- e) Week range                                  (expect 53 weeks, wm_yr_wk 11517-11617)
SELECT COUNT(DISTINCT week_idx) AS weeks, MIN(wm_yr_wk) AS first_wk, MAX(wm_yr_wk) AS last_wk
FROM v_weekly_features;

-- f) Calendar feature sanity: weekend_days <= n_days, holiday_days <= event_days <= n_days
--    (expect bad_rows = 0; full 7-day weeks have weekend_days = 2)
SELECT SUM(weekend_days > n_days OR event_days > n_days OR holiday_days > event_days) AS bad_rows,
       SUM(n_days = 7 AND weekend_days <> 2)                                          AS full_weeks_wrong_weekend,
       MAX(snap_days) AS max_snap_days, MAX(holiday_days) AS max_holiday_days
FROM v_weekly_features;

-- ==============================================================================
-- 6. KNIME model views: lags, rolling mean, series scale, closed days
--    (roadmap p3t4, p3t6; see process/misc/guide/knime_guide.md, section 3)
--    STATUS: written, NOT YET RUN.
--
--    Two sources, same columns, so the KNIME query only changes the view name:
--      v_weekly_model_sample  1% CRC32 sample (every 100th item-store series). USE FIRST,
--                             to smoke-test the KNIME nodes quickly (reads a small table).
--      v_weekly_model         full data. Switch to this after the pipeline works; all
--                             reported numbers (WAPE, row counts) come from this one.
--    Sample caveats: all weeks are kept, but about 1% of items sit in each store x dept
--    series, so units are about 1% of the real size and a few store x dept series may be
--    missing. Do not quote sample results in the report.
--
--    Columns added on top of v_weekly_features:
--      lag1, lag2   sales 1 and 2 weeks back (per store x dept, ordered by week_idx)
--      roll4        mean of the 4 previous weeks (NULL if fewer than 4 weeks exist)
--      series_mean  mean weekly sales of the series over TRAIN weeks only (scale lags
--                   with it in KNIME; no test value is used)
--      closed_days  days in the week the store sold 0 units all day (Dec 25: CA_1, CA_4,
--                   TX_2), so a closed day is not read as a demand drop
--      model_ready  1 only for week_idx 6-52: full weeks, and roll4 is built from full
--                   weeks 2-5 at the earliest (week 1 has 6 days). KNIME Row Filter:
--                   keep model_ready = 1. Train rows = split = 'train' AND model_ready = 1.
--    Lags are computed over all weeks and only look backwards, so there is no leakage.
--    A test week's lag1 / lag2 / roll4 use the actual sales of the weeks before it, so
--    this is a ONE-STEP-AHEAD (next-week) forecast; say so in the report.
--    Do not use weekend_days or n_days as model inputs: they are constant (2 and 7) in every
--    model_ready row, so the regression learns nothing from them. The weekend effect for
--    Q3 comes from the daily query B.3 in 03_kpi_queries.sql, not from the weekly model.
-- ------------------------------------------------------------------------------

-- 6.1 Sample table: the same weekly aggregation as v_weekly_features, on 1% of series.
--     One scan of sales_history (minutes), then everything reads a small table.
DROP TABLE IF EXISTS `weekly_features_sample`;
CREATE TABLE `weekly_features_sample` AS
SELECT w.*,
       CASE WHEN w.week_idx BETWEEN  2 AND 42 THEN 'train'
            WHEN w.week_idx BETWEEN 43 AND 52 THEN 'test'
            ELSE 'excluded' END                                       AS split
FROM (
    SELECT t.store_id, t.state_id, t.dept_id, t.cat_id,
           c.wm_yr_wk,
           DENSE_RANK() OVER (ORDER BY c.wm_yr_wk)                    AS week_idx,
           MIN(c.date)                                                AS week_start,
           MAX(c.date)                                                AS week_end,
           MIN(t.day)                                                 AS first_day,
           COUNT(*)                                                   AS n_days,
           SUM(t.sales)                                               AS sales,
           SUM(CASE t.state_id WHEN 'CA' THEN c.snap_CA
                               WHEN 'TX' THEN c.snap_TX
                               ELSE c.snap_WI END)                    AS snap_days,
           SUM(CASE WHEN c.wday IN (1, 2) THEN 1 ELSE 0 END)          AS weekend_days,
           SUM(CASE WHEN c.event_name_1 IS NOT NULL
                      OR c.event_name_2 IS NOT NULL THEN 1 ELSE 0 END) AS event_days,
           SUM(CASE WHEN c.event_type_1 IN ('National', 'Religious')
                      OR c.event_type_2 IN ('National', 'Religious')
                    THEN 1 ELSE 0 END)                                AS holiday_days,
           MONTH(MIN(c.date))                                         AS month_of_week
    FROM (SELECT store_id, state_id, dept_id, cat_id, day, SUM(sales) AS sales
          FROM sales_history
          WHERE CRC32(id) % 100 = 0                                   -- the 1% sample
          GROUP BY store_id, state_id, dept_id, cat_id, day) t
    JOIN calendar c ON c.d = t.day
    GROUP BY t.store_id, t.state_id, t.dept_id, t.cat_id, c.wm_yr_wk
) w;
ALTER TABLE `weekly_features_sample` ADD PRIMARY KEY (`store_id`, `dept_id`, `wm_yr_wk`);

-- 6.2 Full-data model view (reads the table weekly_features built in 5.1, so a read is
--     instant; run 5.1 first or this view fails).
CREATE OR REPLACE VIEW `v_weekly_model` AS
SELECT f.store_id, f.state_id, f.dept_id, f.cat_id,
       f.wm_yr_wk, f.week_idx, f.week_start, f.first_day, f.n_days, f.split,
       f.sales, f.snap_days, f.weekend_days, f.event_days, f.holiday_days, f.month_of_week,
       COALESCE(cl.closed_days, 0)                                    AS closed_days,
       LAG(f.sales, 1) OVER w                                         AS lag1,
       LAG(f.sales, 2) OVER w                                         AS lag2,
       CASE WHEN COUNT(f.sales) OVER (w ROWS BETWEEN 4 PRECEDING AND 1 PRECEDING) = 4
            THEN AVG(f.sales)   OVER (w ROWS BETWEEN 4 PRECEDING AND 1 PRECEDING)
       END                                                            AS roll4,
       m.series_mean,
       CASE WHEN f.week_idx BETWEEN 6 AND 52 THEN 1 ELSE 0 END        AS model_ready
FROM weekly_features f
JOIN (SELECT store_id, dept_id, AVG(sales) AS series_mean
      FROM weekly_features
      WHERE split = 'train'
      GROUP BY store_id, dept_id) m
  ON m.store_id = f.store_id AND m.dept_id = f.dept_id
LEFT JOIN (SELECT d.store_id, c.wm_yr_wk, COUNT(*) AS closed_days
           FROM store_day_closed d
           JOIN calendar c ON c.d = d.day
           GROUP BY d.store_id, c.wm_yr_wk) cl
  ON cl.store_id = f.store_id AND cl.wm_yr_wk = f.wm_yr_wk
WINDOW w AS (PARTITION BY f.store_id, f.dept_id ORDER BY f.week_idx);

-- 6.3 Sample model view: identical, reads the small sample table. Start with this one.
CREATE OR REPLACE VIEW `v_weekly_model_sample` AS
SELECT f.store_id, f.state_id, f.dept_id, f.cat_id,
       f.wm_yr_wk, f.week_idx, f.week_start, f.first_day, f.n_days, f.split,
       f.sales, f.snap_days, f.weekend_days, f.event_days, f.holiday_days, f.month_of_week,
       COALESCE(cl.closed_days, 0)                                    AS closed_days,
       LAG(f.sales, 1) OVER w                                         AS lag1,
       LAG(f.sales, 2) OVER w                                         AS lag2,
       CASE WHEN COUNT(f.sales) OVER (w ROWS BETWEEN 4 PRECEDING AND 1 PRECEDING) = 4
            THEN AVG(f.sales)   OVER (w ROWS BETWEEN 4 PRECEDING AND 1 PRECEDING)
       END                                                            AS roll4,
       m.series_mean,
       CASE WHEN f.week_idx BETWEEN 6 AND 52 THEN 1 ELSE 0 END        AS model_ready
FROM weekly_features_sample f
JOIN (SELECT store_id, dept_id, AVG(sales) AS series_mean
      FROM weekly_features_sample
      WHERE split = 'train'
      GROUP BY store_id, dept_id) m
  ON m.store_id = f.store_id AND m.dept_id = f.dept_id
LEFT JOIN (SELECT d.store_id, c.wm_yr_wk, COUNT(*) AS closed_days
           FROM store_day_closed d
           JOIN calendar c ON c.d = d.day
           GROUP BY d.store_id, c.wm_yr_wk) cl
  ON cl.store_id = f.store_id AND cl.wm_yr_wk = f.wm_yr_wk
WINDOW w AS (PARTITION BY f.store_id, f.dept_id ORDER BY f.week_idx);

-- 6.4 Checks (run on the sample first; the expected values below are for the FULL view)
-- a) Rows and series                          (full: 3,710 rows = 70 x 53; 70 series)
SELECT COUNT(*) AS rows_n, COUNT(DISTINCT store_id, dept_id) AS series FROM v_weekly_model_sample;

-- b) Usable rows per split      (full: train 70 x 37 = 2,590; test 700; model_ready = 0: 420)
SELECT split, model_ready, COUNT(*) AS rows_n, MIN(week_idx) AS first_wk, MAX(week_idx) AS last_wk
FROM v_weekly_model_sample
GROUP BY split, model_ready
ORDER BY first_wk;

-- c) No NULL lags in the usable rows                                   (expect 0)
SELECT SUM(lag1 IS NULL OR lag2 IS NULL OR roll4 IS NULL) AS null_lags_in_model_rows
FROM v_weekly_model_sample
WHERE model_ready = 1;

-- d) Lags do not cross series: first week of every series has lag1 = NULL
--    (expect rows_with_lag1_null = series count)
SELECT SUM(lag1 IS NULL AND week_idx = 1) AS rows_with_lag1_null_wk1,
       SUM(lag1 IS NULL AND week_idx > 1) AS unexpected_nulls
FROM v_weekly_model_sample;

-- e) Closed days: Dec 25 week (wm_yr_wk 11547) for CA_1, CA_4, TX_2 only  (expect 1 each)
SELECT store_id, wm_yr_wk, closed_days
FROM v_weekly_model_sample
WHERE closed_days > 0
GROUP BY store_id, wm_yr_wk, closed_days;

-- ==============================================================================
-- NOTES
-- ==============================================================================
-- [x] Per-series outlier fence report: not needed, outliers are retained (see the note at
--     the end of 01_schema_and_import.sql and decision_results.md).
