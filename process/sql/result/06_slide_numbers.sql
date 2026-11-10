-- ==============================================================================
-- Script Name : 06_slide_numbers.sql
-- Purpose     : SQL for the 25 deck fields that are still open (required_numbers.md):
--                 Slide 7   N040, N048
--                 Slide 9   N078, N079, N083, N084
--                 Slide 10  N090, N091, N092
--                 Slide 20  T01-T03, N174-N179, N181
--                 Slide 21  N188-N193
-- Database    : bigdataprj   (MySQL 8.4)
-- STATUS      : written, NOT YET RUN. Run times below are estimates, not measurements.
--
-- Needs (run order)
--   01, 02, 04, KNIME run (700 rows in sales_predictions_weekly), then 03 IN FULL:
--     03 builds state_cat_day (B.0), weekly_revenue (C.0, the sell_prices join) and the
--     view v_pred_eval (C.1), which sections 4 and 5 read. Running 03 in full is also how
--     N048 is counted (section 2), so it is not extra work.
--
-- RUN TIME BY DATA SHAPE
--   Anchors from your own notes: one scan of sales_history (11.1M rows) + calendar join +
--   GROUP BY took about 5 min (v_weekly_features); the same scan with a second join to
--   sell_prices (v_sales_features) was stopped at 9 min. Everything on the weekly tables
--   (3,710 rows) or the 700 prediction rows is instant.
--
--   Step                       Reads (shape)                              Estimate
--   -------------------------  -----------------------------------------  ------------
--   1  N040                    calendar, 1,969 rows                       < 0.1 s
--   2  N048  = run 03 in full  11.1M-row scans (A, B.0, B.1, B.5, C.0)    25-55 min
--        of which C.0          11.1M rows x calendar x sell_prices        10-20 min
--   3.1 train_days             calendar + weekly_features (small)         < 0.1 s
--   3.2 train_pos              one PK scan of 11.1M rows -> ~3.5M rows     2-5 min
--   3.3 series_fence           window over ~3.5M rows, 30,490 partitions   1-3 min
--   3.4 fence report           3.5M rows x 30,490-row table                10-40 s
--   3.5 N090 p99               one scan of 11.1M rows, <= 350 groups       1.5-4 min
--   3.6 checks                 3.5M-row SUM, small tables                  < 10 s
--   4   slide 20               v_pred_eval, 700 rows                       < 1 s
--   5.1 Rec 1, 5.3 Rec 3       700 rows / 3,285 rows                       < 1 s each
--   5.2 Rec 2                  scan of sales_history (B.1 predicate)       2-5 min
--   This script alone: about 7-18 min. 03 + this script: about 35-70 min.
--   Raise the client read timeout first (Workbench: Preferences > SQL Editor > DBMS
--   connection read timeout = 0) or run it from the mysql command line.
--
-- DEFINITIONS (decide / confirm before the numbers go on a slide)
--   Fence       : per series (item x store), train days d_1583-d_1869 only, POSITIVE-sales days
--                 only, nearest-rank quartiles (same convention as 01 section 5.5),
--                 fence = Q3 + 1.5 x (Q3 - Q1), upper side only. A day is above the fence when
--                 sales > fence. Series with fewer than @min_pos positive train days get no fence.
--                 Checked outside MySQL on HOBBIES_1_004_CA_1: reproduces fence 6, 11 of 292
--                 days, 39 of 555 units, 10 of 11 flagged days on Sat/Sun
--                 (decision_results.md, outlier policy decision).
--   Units above the fence = SUM(sales - fence) over flagged days (the "39 of 555" in the
--                 decision notes). The units sold on flagged days are also returned, as context.
--   Dollars     : revenue = units x sell_price at SKU-store-day (weekly_revenue). Forecast
--                 dollars assume the actual price mix of the week (v_pred_eval, C.1).
--   Holding cost: ASSUMPTION, not in the data: 25% of stock value per year (a common retail
--                 carrying-cost range is 20-30%), charged for one week = 25% / 52. Stock is valued
--                 at the retail sell_price (no cost data in M5), so this slightly overstates cost.
--                 State "25% per year, one week of holding" on slide 21.
--   Benefit     : revenue, not profit (no margin data).
-- ==============================================================================

USE `bigdataprj`;

-- Parameters (session variables: run the whole script in ONE session) ---------------
SET @model        := 'LinearRegression_weekly_v1';
SET @min_pos      := 8;          -- positive train days needed for a fence ("about 8")
SET @hold_annual  := 0.25;       -- ASSUMPTION: annual holding cost, share of stock value
SET @hold_week    := @hold_annual / 52;
SET @sqa_threshold := 20;        -- N180: store share of total revenue error, %
SET @q2_threshold  := 20;        -- N017: growth gap, percentage points (upside only here)
SET @q3_threshold  := 10;        -- N019: SNAP uplift, %

-- ==============================================================================
-- 1. Slide 7: N040  rows in calendar                 (expect 1,969)
-- ==============================================================================
SELECT COUNT(*) AS n040_calendar_rows FROM calendar;

-- ==============================================================================
-- 2. Slide 7: N048  KPI queries run without error
--    Not a SELECT: it is a tally from running 03_kpi_queries.sql end to end.
--    03 has 31 labelled blocks = 27 report queries + 4 build blocks (B.0, B.5, C.0, C.1).
--    From the mysql command line (--force keeps going after an error, the log lists each one):
--        mysql --local-infile=1 --force --verbose -u <user> -p < 03_kpi_queries.sql > 03_out.txt 2> 03_err.txt
--    N048 = 31 - (number of distinct blocks named in 03_err.txt). In Workbench: count the green
--    ticks in the Action Output pane. Write on the slide whether 31 or 27 is counted.
--    Expected 31 / 31 now: sales_predictions_weekly has its 700 rows, so Part C can run.
-- ==============================================================================

-- ==============================================================================
-- 3. Slides 9-10: per-series IQR fence report on the TRAIN days
-- ==============================================================================

-- 3.1 Train days = the days of the train weeks (split = 'train' in weekly_features)
--     Expect 287 rows (41 weeks x 7 days, d_1583-d_1869).
DROP TABLE IF EXISTS `train_days`;
CREATE TABLE `train_days` (
    `d`    VARCHAR(20)      NOT NULL,
    `wday` TINYINT UNSIGNED NOT NULL,          -- M5: 1 = Saturday, 2 = Sunday
    PRIMARY KEY (`d`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO `train_days` (`d`, `wday`)
SELECT c.d, c.wday
FROM calendar c
WHERE c.wm_yr_wk IN (SELECT DISTINCT wm_yr_wk FROM weekly_features WHERE split = 'train');

SELECT COUNT(*) AS train_days, MIN(d) AS first_d, MAX(d) AS last_d FROM train_days;   -- 287

-- 3.2 Positive-sales train rows (the only rows the fence is computed on).
--     STRAIGHT_JOIN keeps sales_history as the driving table, so it is read in primary-key
--     order (id, day) and inserted in the same order: no random inserts.
--     Zero-sales rows add nothing to units, so train units are still complete.
DROP TABLE IF EXISTS `train_pos`;
CREATE TABLE `train_pos` (
    `id`    VARCHAR(100)     NOT NULL,
    `day`   VARCHAR(20)      NOT NULL,
    `wday`  TINYINT UNSIGNED NOT NULL,
    `sales` INT              NOT NULL,
    PRIMARY KEY (`id`, `day`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO `train_pos` (`id`, `day`, `wday`, `sales`)
SELECT STRAIGHT_JOIN s.id, s.day, t.wday, s.sales
FROM sales_history s
JOIN train_days t ON t.d = s.day
WHERE s.sales > 0;

-- 3.3 One row per series: positive-day count, Q1, Q3 (nearest rank: the smallest value whose
--     CUME_DIST reaches 0.25 / 0.75) and the fence. fence is NULL below @min_pos positive days.
--     Series with no positive train day are absent here (counted in 3.4 as "never sold").
DROP TABLE IF EXISTS `series_fence`;
CREATE TABLE `series_fence` (
    `id`    VARCHAR(100) NOT NULL,
    `n_pos` INT          NOT NULL,
    `q1`    INT          NOT NULL,
    `q3`    INT          NOT NULL,
    `fence` DECIMAL(8,2) NULL,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO `series_fence` (`id`, `n_pos`, `q1`, `q3`, `fence`)
SELECT x.id, x.n_pos, x.q1, x.q3,
       CASE WHEN x.n_pos >= @min_pos THEN x.q3 + 1.5 * (x.q3 - x.q1) END
FROM (SELECT r.id,
             COUNT(*)                                     AS n_pos,
             MIN(CASE WHEN r.cd >= 0.25 THEN r.sales END) AS q1,
             MIN(CASE WHEN r.cd >= 0.75 THEN r.sales END) AS q3
      FROM (SELECT id, sales,
                   CUME_DIST() OVER (PARTITION BY id ORDER BY sales) AS cd
            FROM train_pos) r
      GROUP BY r.id) x;

-- 3.4 The report. Denominators come from the grid, not from a scan: every day holds exactly
--     30,490 series (01 check 5.2b), so train rows = 30,490 x 287 = 8,750,630.
SET @n_series    := (SELECT COUNT(*) FROM sales_history WHERE day = 'd_1870');   -- 30,490 (index lookup)
SET @train_rows  := @n_series * (SELECT COUNT(*) FROM train_days);                -- 8,750,630
SET @train_units := (SELECT SUM(sales) FROM train_pos);                           -- all train units

-- N078, N079, N083, N084, N092 (+ context columns)
SELECT SUM(p.sales > f.fence)                                                          AS n078_rows_above_fence,
       ROUND(100 * SUM(p.sales > f.fence) / @train_rows, 3)                            AS n079_pct_of_train_rows,
       ROUND(SUM(CASE WHEN p.sales > f.fence THEN p.sales - f.fence END), 0)           AS n084_units_over_fence,
       ROUND(100 * SUM(CASE WHEN p.sales > f.fence THEN p.sales - f.fence END)
                 / @train_units, 3)                                                    AS n083_pct_of_train_units,
       SUM(CASE WHEN p.sales > f.fence THEN p.sales END)                               AS context_units_sold_on_flagged_days,
       ROUND(100 * SUM(CASE WHEN p.sales > f.fence THEN p.sales END) / @train_units, 3) AS context_pct_of_train_units,
       ROUND(100 * SUM(p.sales > f.fence AND p.wday IN (1, 2)) / SUM(p.sales > f.fence), 2) AS n092_pct_flagged_on_sat_sun,
       (SELECT ROUND(100 * SUM(wday IN (1, 2)) / COUNT(*), 2) FROM train_days)         AS context_pct_sat_sun_of_all_days,   -- 28.57
       @train_rows                                                                     AS context_train_rows,
       @train_units                                                                    AS context_train_units
FROM train_pos p
JOIN series_fence f ON f.id = p.id
WHERE f.fence IS NOT NULL;

-- N091 series without a fence (and why)
SELECT @n_series                                  AS series_total,
       SUM(fence IS NOT NULL)                     AS series_with_fence,
       @n_series - SUM(fence IS NOT NULL)         AS n091_series_without_fence,
       @n_series - COUNT(*)                       AS of_which_no_positive_train_day,
       SUM(n_pos < @min_pos)                      AS of_which_fewer_than_min_pos_days
FROM series_fence;

-- 3.5 N090  99th percentile of daily sales, all 365 days, nearest rank on the value histogram
--     (same method as 01 section 5.5). CSV-based draft value: 15.
SELECT MIN(h.sales) AS n090_p99_daily_sales
FROM (SELECT sales,
             SUM(COUNT(*)) OVER (ORDER BY sales) AS cum,
             SUM(COUNT(*)) OVER ()               AS total
      FROM sales_history
      GROUP BY sales) h
WHERE h.cum >= 0.99 * h.total;

-- 3.6 Checks (all cheap)
--     a) train units from the weekly table equal the units in train_pos      (expect diff = 0)
--     b) series_fence rows never exceed the series count (30,490)
SELECT (SELECT SUM(sales) FROM weekly_features WHERE split = 'train')  AS weekly_train_units,
       @train_units                                                    AS train_pos_units,
       (SELECT SUM(sales) FROM weekly_features WHERE split = 'train') - @train_units AS diff,
       (SELECT COUNT(*) FROM train_pos)                                AS train_pos_rows,
       (SELECT COUNT(*) FROM series_fence)                             AS series_fence_rows;

-- ==============================================================================
-- 4. Slide 20: weekly revenue error by store (SQ-A)      one row, field ids as column names
--    Same logic as 03 C.6, restricted to the model, shaped as the slide fields.
--    Needs v_pred_eval (03 C.1) and weekly_revenue (03 C.0).
--    Check first:  SELECT COUNT(*) FROM v_pred_eval WHERE model_name = @model;   -- expect 700
-- ==============================================================================
WITH sw AS (
    SELECT store_id, week_idx,
           SUM(pred_rev) AS pred_rev, SUM(actual_rev) AS actual_rev
    FROM v_pred_eval
    WHERE model_name = @model
    GROUP BY store_id, week_idx
), s AS (
    SELECT store_id,
           AVG(ABS(pred_rev - actual_rev)) AS rev_mae_usd,
           SUM(ABS(pred_rev - actual_rev)) AS abs_rev_err
    FROM sw
    GROUP BY store_id
), r AS (
    SELECT store_id, rev_mae_usd,
           100 * abs_rev_err / SUM(abs_rev_err) OVER ()    AS share_pct,
           ROW_NUMBER() OVER (ORDER BY rev_mae_usd DESC)   AS rk
    FROM s
)
SELECT MAX(CASE WHEN rk = 1 THEN store_id END)                 AS t01,
       ROUND(MAX(CASE WHEN rk = 1 THEN rev_mae_usd END), 2)    AS n174_usd,
       ROUND(MAX(CASE WHEN rk = 1 THEN share_pct END), 2)      AS n175_pct,
       MAX(CASE WHEN rk = 2 THEN store_id END)                 AS t02,
       ROUND(MAX(CASE WHEN rk = 2 THEN rev_mae_usd END), 2)    AS n176_usd,
       ROUND(MAX(CASE WHEN rk = 2 THEN share_pct END), 2)      AS n177_pct,
       MAX(CASE WHEN rk = 3 THEN store_id END)                 AS t03,
       ROUND(MAX(CASE WHEN rk = 3 THEN rev_mae_usd END), 2)    AS n178_usd,
       ROUND(MAX(CASE WHEN rk = 3 THEN share_pct END), 2)      AS n179_pct,
       SUM(share_pct > @sqa_threshold)                         AS n181_stores_above_threshold,
       @sqa_threshold                                          AS n180_threshold_pct,
       COUNT(*)                                                AS stores
FROM r;
-- Re-check N180 against the real shares: with 10 stores the average share is 10%, so 20% may
-- flag 0-1 stores. The decision note wants about 1-3 flagged. Full list: 03 C.6.

-- ==============================================================================
-- 5. Slide 21: dollars per week for the three recommendations
--    All figures are per average week. Benefit = revenue; cost = holding cost of the extra
--    stock for one week at @hold_week (25% per year / 52). Both come from weekly_revenue,
--    i.e. units x sell_price.
-- ==============================================================================
SET @n_test_weeks := (SELECT COUNT(DISTINCT week_idx) FROM v_pred_eval WHERE model_name = @model);   -- 10

-- 5.1 Rec 1  Reorder from the forecast.   N188 (benefit), N189 (cost)
--     Benefit: dollar forecast error avoided versus reordering last week's units (lag1),
--              both valued at the week's price mix:  sum |lag1 - actual| x price
--                                                  - sum |forecast - actual| x price.
--     Cost   : the forecast's over-stock (units above actual demand x price, per store x dept
--              x week, so errors do not cancel) held for one week.
SELECT ROUND(SUM(x.base_abs_usd - x.model_abs_usd) / @n_test_weeks, 2)   AS n188_benefit_usd_per_week,
       ROUND(SUM(x.over_usd) * @hold_week / @n_test_weeks, 2)            AS n189_cost_usd_per_week,
       ROUND(SUM(x.base_abs_usd) / @n_test_weeks, 2)                     AS context_last_week_usd_error_per_week,
       ROUND(SUM(x.model_abs_usd) / @n_test_weeks, 2)                    AS context_model_usd_error_per_week,
       ROUND(SUM(x.over_usd) / @n_test_weeks, 2)                         AS context_over_stock_usd_per_week,
       @hold_annual                                                      AS holding_rate_per_year
FROM (SELECT e.week_idx,
             ABS(m.lag1 - e.actual_sales) * e.actual_rev / NULLIF(e.actual_sales, 0) AS base_abs_usd,
             ABS(e.pred_rev - e.actual_rev)                                          AS model_abs_usd,
             e.over_rev                                                              AS over_usd
      FROM v_pred_eval e
      JOIN v_weekly_model m ON m.store_id = e.store_id AND m.dept_id = e.dept_id AND m.wm_yr_wk = e.wm_yr_wk
      WHERE e.model_name = @model) x;

-- 5.2 Rec 2  Shift stock to fast-growing store-categories.   N190 (benefit), N191 (cost)
--     Scope  : store-categories whose growth beats the regional growth by more than
--              @q2_threshold pp (upside only; B.1 gives CA_2, WI_3, WI_2 FOODS at 20 pp).
--     Units  : demand above the regional-growth plan = last28 - first28 x (1 + regional growth),
--              spread over the 4 weeks of the last-28-day window.
--     Benefit: those units x the store-category's unit price (test-week revenue / units).
--     Cost   : the same units held for one week.
--     The sc/g blocks are the B.1 query (same numbers as decision_results.md B.1).
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
           100 * (last28 / first28 - 1)                                  AS growth_pct,
           100 * (SUM(last28) OVER () / SUM(first28) OVER () - 1)        AS regional_growth_pct
    FROM sc
), up AS (
    SELECT store_id, cat_id, growth_pct - regional_growth_pct            AS gap_pp,
           (last28 - first28 * (1 + regional_growth_pct / 100)) / 4      AS excess_units_wk
    FROM g
), px AS (
    SELECT f.store_id, f.cat_id, SUM(r.revenue) / SUM(f.sales)           AS price
    FROM weekly_features f
    JOIN weekly_revenue r ON r.store_id = f.store_id AND r.dept_id = f.dept_id AND r.wm_yr_wk = f.wm_yr_wk
    WHERE f.split = 'test' AND f.n_days = 7
    GROUP BY f.store_id, f.cat_id
)
SELECT IFNULL(y.label, 'TOTAL  (N190 / N191)')                AS scope,
       ROUND(SUM(y.excess_units_wk), 0)                       AS extra_units_per_week,
       ROUND(SUM(y.excess_units_wk * y.price), 2)             AS benefit_usd_per_week,
       ROUND(SUM(y.excess_units_wk * y.price) * @hold_week, 2) AS cost_usd_per_week
FROM (SELECT CONCAT(u.store_id, ' ', u.cat_id) AS label, u.excess_units_wk, p.price
      FROM up u
      JOIN px p ON p.store_id = u.store_id AND p.cat_id = u.cat_id
      WHERE u.gap_pp > @q2_threshold) y
GROUP BY y.label WITH ROLLUP;

-- 5.3 Rec 3  Pre-stock SNAP weeks.   N192 (benefit), N193 (cost)
--     Scope  : state-categories whose SNAP-day uplift beats @q3_threshold % (B.2: TX FOODS, WI FOODS).
--     Units  : (average SNAP-day units - average non-SNAP-day units) x SNAP days per week
--              (120 SNAP days / 52.1 weeks = 2.3). This is the gross demand lift of the SNAP days.
--     Benefit: those units x the state-category's unit price (test-week revenue / units).
--     Cost   : the same units held for one week.
--     The gross lift is an upper bound: the weekly model already carries snap_days. The
--     residual the model still misses is in 5.4 (lower bound).
WITH sn AS (
    SELECT state_id, cat_id,
           AVG(CASE WHEN snap = 1 THEN sales END)                          AS avg_snap_day,
           AVG(CASE WHEN snap = 0 THEN sales END)                          AS avg_non_snap_day,
           SUM(snap = 1)                                                   AS snap_days,
           COUNT(*)                                                        AS n_days
    FROM state_cat_day
    GROUP BY state_id, cat_id
), up AS (
    SELECT state_id, cat_id,
           100 * (avg_snap_day / avg_non_snap_day - 1)                     AS uplift_pct,
           (avg_snap_day - avg_non_snap_day) * snap_days / (n_days / 7)    AS extra_units_wk
    FROM sn
), px AS (
    SELECT f.state_id, f.cat_id, SUM(r.revenue) / SUM(f.sales)             AS price
    FROM weekly_features f
    JOIN weekly_revenue r ON r.store_id = f.store_id AND r.dept_id = f.dept_id AND r.wm_yr_wk = f.wm_yr_wk
    WHERE f.split = 'test' AND f.n_days = 7
    GROUP BY f.state_id, f.cat_id
)
SELECT IFNULL(y.label, 'TOTAL  (N192 / N193)')                AS scope,
       ROUND(SUM(y.extra_units_wk), 0)                        AS extra_units_per_week,
       ROUND(SUM(y.extra_units_wk * y.price), 2)              AS benefit_usd_per_week,
       ROUND(SUM(y.extra_units_wk * y.price) * @hold_week, 2) AS cost_usd_per_week
FROM (SELECT CONCAT(u.state_id, ' ', u.cat_id) AS label, u.extra_units_wk, p.price
      FROM up u
      JOIN px p ON p.state_id = u.state_id AND p.cat_id = u.cat_id
      WHERE u.uplift_pct > @q3_threshold) y
GROUP BY y.label WITH ROLLUP;

-- 5.4 Rec 3 cross-check (lower bound): revenue the model still under-forecasts in SNAP weeks
--     for the same two state-categories, per average test week. If you prefer a defensible
--     floor to a gross upper bound, quote this one as N192 and say so on the slide.
SELECT state_id, cat_id,
       ROUND(SUM(CASE WHEN snap_days > 0 THEN under_rev END) / @n_test_weeks, 2) AS under_forecast_usd_in_snap_weeks_per_week
FROM v_pred_eval
WHERE model_name = @model AND cat_id = 'FOODS' AND state_id IN ('TX', 'WI')
GROUP BY state_id, cat_id;

-- ==============================================================================
-- NOTES
-- ==============================================================================
-- [ ] After a run, write every value with its query into process/numbers_verified.md and set
--     the Status in required_numbers.md (RUN -> VERIFIED).
-- [ ] N048: say whether the slide counts 31 blocks or 27 report queries.
-- [ ] N180 / N181: if the 20% line flags 0 or more than 3 stores, pick the threshold from the real shares.
-- [ ] Holding rate (25% per year) is an assumption: change @hold_annual at the top and re-run
--     5.1-5.3 if the team prefers another rate.
