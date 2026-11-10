-- ==============================================================================
-- Script Name : 01_full_year_stats_and_quality_audit.sql
-- Roadmap     : p2t6 (correct Week 1/2 stats) + p2t7 (quality audit on full data)
-- Database    : bigdataprj   (MySQL 8.0)
-- Tables      : sales_history (11,128,850 rows), calendar, sell_prices
-- Run time    : a few minutes in total (full scans of 11M rows; idx_sales_day exists)
--
-- WHY: the Week 1 KNIME query ended in LIMIT 100000. sales_history is stored in
-- day order with 30,490 series per day, so 100,000 rows = 3.28 days (d_1577-d_1580).
-- Every Week 1/2 statistic (87,390 rows, mean 0.394, category shares) therefore
-- describes 4 days, not the 365-day window. This script recomputes them on all rows.
-- ==============================================================================

USE `bigdataprj`;

-- ------------------------------------------------------------------------------
-- 0. Prove the sampling problem (p2t6)
--    NOTE: LIMIT without ORDER BY is not guaranteed, but InnoDB returned the rows in
--    load order, i.e. day order, which is what KNIME saw.
-- ------------------------------------------------------------------------------
SELECT COUNT(*)                                   AS sample_rows,
       COUNT(DISTINCT day)                        AS distinct_days,
       MIN(CAST(SUBSTRING(day, 3) AS UNSIGNED))   AS first_day_no,
       MAX(CAST(SUBSTRING(day, 3) AS UNSIGNED))   AS last_day_no,
       ROUND(COUNT(*) / 30490, 2)                 AS days_covered      -- expect 3.28
FROM (SELECT day FROM sales_history LIMIT 100000) AS smp;

-- ------------------------------------------------------------------------------
-- 1. Full-year descriptive statistics (replaces the 100,000-row figures)
-- ------------------------------------------------------------------------------
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

-- 1.1 Category shares, full year (Week 1/2 showed FOODS 61.7% / HOBBIES 11.2% / HOUSEHOLD 27.1% of units = 4 days)
SELECT cat_id,
       COUNT(*)                                                 AS row_cnt,
       ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)         AS row_share_pct,
       SUM(sales)                                               AS units,
       ROUND(100 * SUM(sales) / SUM(SUM(sales)) OVER (), 2)     AS unit_share_pct,
       ROUND(AVG(sales), 3)                                     AS mean_sales
FROM sales_history
GROUP BY cat_id
ORDER BY cat_id;

-- 1.2 Same by store / state (supports the stock-out and state-bias questions)
SELECT state_id, store_id, COUNT(*) AS row_cnt, SUM(sales) AS units, ROUND(AVG(sales), 3) AS mean_sales
FROM sales_history
GROUP BY state_id, store_id
ORDER BY state_id, store_id;

-- ------------------------------------------------------------------------------
-- 2. Quality audit: four dimensions, exact counts (p2t7)
-- ------------------------------------------------------------------------------

-- 2.1 COMPLETENESS: blanks / NULLs in every column (NOT NULL columns, so also check '')
SELECT SUM(id = '')       AS blank_id,
       SUM(item_id = '')  AS blank_item_id,
       SUM(dept_id = '')  AS blank_dept_id,
       SUM(cat_id = '')   AS blank_cat_id,
       SUM(store_id = '') AS blank_store_id,
       SUM(state_id = '') AS blank_state_id,
       SUM(day = '')      AS blank_day,
       SUM(sales IS NULL) AS null_sales
FROM sales_history;

-- 2.1b Completeness of the grid: every day must hold exactly 30,490 series
SELECT COUNT(*) AS days_with_wrong_row_count                        -- expect 0
FROM (SELECT day FROM sales_history GROUP BY day HAVING COUNT(*) <> 30490) AS x;

-- 2.1c Join completeness: rows that find no calendar row
SELECT COUNT(*) AS rows_without_calendar                            -- expect 0
FROM sales_history s LEFT JOIN calendar c ON s.day = c.d
WHERE c.d IS NULL;

-- 2.2 UNIQUENESS: grain is (id, day)
SELECT COUNT(*) AS total_rows,
       COUNT(DISTINCT id, day) AS distinct_id_day,
       COUNT(*) - COUNT(DISTINCT id, day) AS duplicate_rows           -- expect 0
FROM sales_history;

-- 2.2b If you add the key, this doubles as a permanent uniqueness check (slow, run once):
-- ALTER TABLE sales_history ADD PRIMARY KEY (id, day);

-- 2.3 VALIDITY
SELECT SUM(sales < 0)                                              AS negative_sales,          -- expect 0
       SUM(day NOT REGEXP '^d_[0-9]+$')                           AS bad_day_format,          -- expect 0
       SUM(CAST(SUBSTRING(day, 3) AS UNSIGNED) NOT BETWEEN 1577 AND 1941) AS day_out_of_window, -- expect 0
       SUM(id NOT LIKE CONCAT(item_id, '\_', store_id, '\_evaluation')) AS id_format_mismatch, -- expect 0
       SUM(LEFT(store_id, 2) <> state_id)                         AS store_state_mismatch     -- expect 0
FROM sales_history;

SELECT COUNT(*) AS price_rows, SUM(sell_price <= 0) AS nonpositive_price,      -- expect 0
       MIN(sell_price) AS min_price, MAX(sell_price) AS max_price
FROM sell_prices;

-- 2.4 OUTLIERS: global IQR (k = 1.5, upper bound only, same rule as Week 1 so the numbers are comparable)
--     Quantiles come from the exact value histogram (nearest rank), which is cheap for integer sales.
SET @n  := (SELECT COUNT(*) FROM sales_history);
SET @q1 := (SELECT MIN(sales) FROM (SELECT sales, SUM(COUNT(*)) OVER (ORDER BY sales) AS cum
                                    FROM sales_history GROUP BY sales) h WHERE cum >= 0.25 * @n);
SET @q3 := (SELECT MIN(sales) FROM (SELECT sales, SUM(COUNT(*)) OVER (ORDER BY sales) AS cum
                                    FROM sales_history GROUP BY sales) h WHERE cum >= 0.75 * @n);
SET @ub := @q3 + 1.5 * (@q3 - @q1);
SELECT @q1 AS q1, @q3 AS q3, @ub AS upper_bound;                  -- 0, 1, 2.5 (so values > 2 are outliers)

-- 2.4b Before vs After table (full year). Fill the Week 1 document from this result.
SELECT 'Before (raw)' AS stage,
       COUNT(*) AS n, SUM(sales) AS units, MIN(sales) AS min_s, MAX(sales) AS max_s,
       ROUND(AVG(sales), 3) AS mean_s, ROUND(STDDEV_SAMP(sales), 3) AS sd_s
FROM sales_history
UNION ALL
SELECT 'After (sales <= upper bound)',
       COUNT(*), SUM(sales), MIN(sales), MAX(sales), ROUND(AVG(sales), 3), ROUND(STDDEV_SAMP(sales), 3)
FROM sales_history WHERE sales <= @ub;

-- 2.4c What the global IQR rule throws away (shows why p2t9 prefers capping per series)
SELECT SUM(sales > @ub)                                              AS outlier_rows,
       ROUND(100 * SUM(sales > @ub) / COUNT(*), 2)                   AS outlier_rows_pct,
       SUM(CASE WHEN sales > @ub THEN sales ELSE 0 END)              AS outlier_units,
       ROUND(100 * SUM(CASE WHEN sales > @ub THEN sales ELSE 0 END) / SUM(sales), 2) AS outlier_units_pct
FROM sales_history;

-- 2.4d Tail sizes for choosing a cap
SELECT SUM(sales > 5) AS gt5, SUM(sales > 10) AS gt10, SUM(sales > 20) AS gt20, SUM(sales > 50) AS gt50
FROM sales_history;
