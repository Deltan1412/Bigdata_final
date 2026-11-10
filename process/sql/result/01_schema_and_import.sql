-- ==============================================================================
-- Script Name : 01_schema_and_import.sql
-- Purpose     : Create database `bigdataprj`, the three base tables, load the CSVs,
--               add keys/indexes, verify the load, and run the data-quality audit.
-- Database    : bigdataprj   (MySQL 8.0)
-- Tables      : calendar (1,969 rows), sales_history (11,128,850 rows),
--               sell_prices (6,841,121 rows)
--
-- Built from  : data_importing/import_calendar.sql
--               data_importing/import_sales_history.sql
--               data_importing/import_sell_prices.sql
--               data_manipulating/01_full_year_stats_and_quality_audit.sql (audit part)
--
-- BEFORE YOU RUN
--   1. The three LOAD DATA statements read from D:/VNUK/Bigdata_Analysis/Final/data/raw/.
--      On another machine, change that prefix in all three (forward slashes, also on
--      Windows).
--   2. Connect with local_infile enabled:  mysql --local-infile=1 -u <user> -p
--      (MySQL Workbench: set OPT_LOCAL_INFILE=1 in the connection settings).
--   3. The script is re-runnable: it drops and rebuilds the three tables.
--
-- RUN ORDER   : 01 -> 02 -> 04 -> KNIME run -> 03
--               (03 Parts A and B only need 01/02 and can run earlier; 03 Part C builds
--               v_pred_eval on sales_predictions_weekly, which 04 creates and KNIME fills.
--               Running 03 before 04 fails with "table does not exist".)
-- RUN TIME    : sales_history load plus key build takes several minutes.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 0. Database
-- ------------------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS `bigdataprj`
    DEFAULT CHARACTER SET utf8mb4
    DEFAULT COLLATE utf8mb4_0900_ai_ci;

USE `bigdataprj`;

SET GLOBAL local_infile = 1;

-- ==============================================================================
-- 1. calendar  (from data/raw/calendar.csv)
-- ==============================================================================
-- Primary key is `d` ('d_1', 'd_2', ...) because sales_history.day joins to it.
-- sales_history references calendar through a foreign key (step 2.7), so on a re-run
-- the child table must be dropped first or DROP TABLE calendar fails.
DROP TABLE IF EXISTS `sales_history`;
DROP TABLE IF EXISTS `calendar`;

CREATE TABLE `calendar` (
    `date` DATE NOT NULL,
    `wm_yr_wk` INT NOT NULL,
    `weekday` VARCHAR(15) NOT NULL,
    `wday` TINYINT UNSIGNED NOT NULL,
    `month` TINYINT UNSIGNED NOT NULL,
    `year` SMALLINT UNSIGNED NOT NULL,
    `d` VARCHAR(20) NOT NULL,
    `event_name_1` VARCHAR(50) DEFAULT NULL,
    `event_type_1` VARCHAR(30) DEFAULT NULL,
    `event_name_2` VARCHAR(50) DEFAULT NULL,
    `event_type_2` VARCHAR(30) DEFAULT NULL,
    `snap_CA` TINYINT(1) NOT NULL DEFAULT 0,
    `snap_TX` TINYINT(1) NOT NULL DEFAULT 0,
    `snap_WI` TINYINT(1) NOT NULL DEFAULT 0,
    PRIMARY KEY (`d`),
    UNIQUE KEY `uk_calendar_date` (`date`),
    INDEX `idx_calendar_wm_yr_wk` (`wm_yr_wk`),
    INDEX `idx_calendar_year_month` (`year`, `month`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- NULLIF() turns empty strings into true NULLs, so `event_name_1 IS NOT NULL`
-- correctly identifies event days.
LOAD DATA LOCAL INFILE 'D:/VNUK/Bigdata_Analysis/Final/data/raw/calendar.csv'
INTO TABLE `calendar`
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(
    @date,
    @wm_yr_wk,
    @weekday,
    @wday,
    @month,
    @year,
    @d,
    @event_name_1,
    @event_type_1,
    @event_name_2,
    @event_type_2,
    @snap_CA,
    @snap_TX,
    @snap_WI
)
SET
    `date`         = STR_TO_DATE(TRIM(@date), '%Y-%m-%d'),
    `wm_yr_wk`     = CAST(TRIM(@wm_yr_wk) AS UNSIGNED),
    `weekday`      = TRIM(@weekday),
    `wday`         = CAST(TRIM(@wday) AS UNSIGNED),
    `month`        = CAST(TRIM(@month) AS UNSIGNED),
    `year`         = CAST(TRIM(@year) AS UNSIGNED),
    `d`            = TRIM(@d),
    `event_name_1` = NULLIF(TRIM(@event_name_1), ''),
    `event_type_1` = NULLIF(TRIM(@event_type_1), ''),
    `event_name_2` = NULLIF(TRIM(@event_name_2), ''),
    `event_type_2` = NULLIF(TRIM(@event_type_2), ''),
    `snap_CA`      = CAST(TRIM(@snap_CA) AS UNSIGNED),
    `snap_TX`      = CAST(TRIM(@snap_TX) AS UNSIGNED),
    `snap_WI`      = CAST(TRIM(@snap_WI) AS UNSIGNED);

-- 1.1 Row count (expect 1,969)
SELECT COUNT(*) AS total_imported_days FROM `calendar`;

-- 1.2 First and last rows
SELECT * FROM `calendar` ORDER BY `date` ASC  LIMIT 5;
SELECT * FROM `calendar` ORDER BY `date` DESC LIMIT 5;

-- 1.3 Event distribution (events stored as NULL vs non-NULL)
SELECT
    COUNT(*) AS total_days,
    SUM(CASE WHEN `event_name_1` IS NOT NULL OR `event_name_2` IS NOT NULL THEN 1 ELSE 0 END) AS holiday_count,
    SUM(CASE WHEN `event_name_1` IS NULL AND `event_name_2` IS NULL THEN 1 ELSE 0 END)         AS regular_days
FROM `calendar`;

-- ==============================================================================
-- 2. sales_history  (from data/raw/m5_sales_last_365_days.csv, ~839 MB)
-- ==============================================================================
-- Keys and indexes are added AFTER the load: much faster than loading into an
-- indexed table.
DROP TABLE IF EXISTS `sales_history`;

CREATE TABLE `sales_history` (
    `id`       VARCHAR(100) NOT NULL,
    `item_id`  VARCHAR(50)  NOT NULL,
    `dept_id`  VARCHAR(50)  NOT NULL,
    `cat_id`   VARCHAR(50)  NOT NULL,
    `store_id` VARCHAR(50)  NOT NULL,
    `state_id` VARCHAR(50)  NOT NULL,
    `day`      VARCHAR(20)  NOT NULL,
    `sales`    INT          NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 2.1 Fast-load settings: integrity checks and autocommit off during the bulk load
SET @OLD_AUTOCOMMIT = @@AUTOCOMMIT;
SET @OLD_UNIQUE_CHECKS = @@UNIQUE_CHECKS;
SET @OLD_FOREIGN_KEY_CHECKS = @@FOREIGN_KEY_CHECKS;
SET @OLD_SQL_MODE = @@SQL_MODE;

SET autocommit = 0;
SET unique_checks = 0;
SET foreign_key_checks = 0;
SET sql_mode = '';

-- Optional (needs SUPER / SYSTEM_VARIABLES_ADMIN):
-- SET sql_log_bin = 0;

-- 2.2 Bulk load. This CSV uses Windows line endings (\r\n); the trailing \r is also
-- trimmed from @sales so it cannot pollute the integer column.
LOAD DATA LOCAL INFILE 'D:/VNUK/Bigdata_Analysis/Final/data/raw/m5_sales_last_365_days.csv'
INTO TABLE `sales_history`
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(
    `id`,
    `item_id`,
    `dept_id`,
    `cat_id`,
    `store_id`,
    `state_id`,
    `day`,
    @sales
)
SET
    `sales` = CAST(TRIM(TRAILING '\r' FROM @sales) AS SIGNED);

COMMIT;

SET autocommit = @OLD_AUTOCOMMIT;
SET unique_checks = @OLD_UNIQUE_CHECKS;
SET foreign_key_checks = @OLD_FOREIGN_KEY_CHECKS;
SET sql_mode = @OLD_SQL_MODE;

-- 2.3 Row count (expect 11,128,850; if you see 22,257,700 the file was loaded twice)
SELECT COUNT(*) AS total_rows FROM `sales_history`;

-- 2.4 First rows
SELECT * FROM `sales_history` LIMIT 10;

-- 2.5 Rows per state and store
SELECT
    `state_id`,
    `store_id`,
    COUNT(*)     AS total_records,
    SUM(`sales`) AS total_units_sold,
    AVG(`sales`) AS avg_daily_sales
FROM `sales_history`
GROUP BY `state_id`, `store_id`
ORDER BY `state_id`, `store_id`;

-- 2.6 Why the Week 1/2 statistics were wrong (roadmap p2t6).
--     The Week 1 KNIME query ended in LIMIT 100000. While the table has no clustered
--     key, rows come back in load order = day order, 30,490 series per day, so
--     100,000 rows = 3.28 days (d_1577-d_1580).
--     RUN THIS BEFORE step 2.7. After the primary key exists the table is ordered by
--     (id, day) and this query no longer reproduces the 3.28-day result.
SELECT COUNT(*)                                   AS sample_rows,
       COUNT(DISTINCT day)                        AS distinct_days,
       MIN(CAST(SUBSTRING(day, 3) AS UNSIGNED))   AS first_day_no,
       MAX(CAST(SUBSTRING(day, 3) AS UNSIGNED))   AS last_day_no,
       ROUND(COUNT(*) / 30490, 2)                 AS days_covered      -- expect 3.28
FROM (SELECT day FROM `sales_history` LIMIT 100000) AS smp;

-- 2.7 Keys and indexes (primary key first, so the table is rebuilt only once)
--     Grain of the table is one row per (id, day). The key doubles as the uniqueness
--     check: the ALTER fails if there are duplicates (e.g. a double load).
ALTER TABLE `sales_history` ADD PRIMARY KEY (`id`, `day`);

-- idx_sales_day: join sales_history.day = calendar.d (also required by the foreign key)
CREATE INDEX `idx_sales_day` ON `sales_history` (`day`);
-- store and item filtering / grouping in forecasting
CREATE INDEX `idx_sales_store_item` ON `sales_history` (`store_id`, `item_id`);
-- category / department aggregations
CREATE INDEX `idx_sales_cat_dept` ON `sales_history` (`cat_id`, `dept_id`);

-- Foreign key to the calendar. Validates all 11M rows, so it takes a few minutes.
-- (sell_prices cannot get a foreign key: calendar.wm_yr_wk is not unique.)
ALTER TABLE `sales_history`
    ADD CONSTRAINT `fk_sales_calendar` FOREIGN KEY (`day`) REFERENCES `calendar` (`d`);

-- ==============================================================================
-- 3. sell_prices  (from data/raw/sell_prices.csv, ~203 MB, LF line endings)
-- ==============================================================================
-- Join path: sales_history.day -> calendar.d -> calendar.wm_yr_wk
--            -> sell_prices (store_id, item_id, wm_yr_wk)
DROP TABLE IF EXISTS `sell_prices`;

CREATE TABLE `sell_prices` (
    `store_id`   VARCHAR(10)  NOT NULL,
    `item_id`    VARCHAR(50)  NOT NULL,
    `wm_yr_wk`   INT          NOT NULL,
    `sell_price` DECIMAL(8,2) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Fast-load settings, same pattern as section 2
SET autocommit = 0;
SET unique_checks = 0;

LOAD DATA LOCAL INFILE 'D:/VNUK/Bigdata_Analysis/Final/data/raw/sell_prices.csv'
INTO TABLE `sell_prices`
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(`store_id`, `item_id`, `wm_yr_wk`, @sell_price)
SET `sell_price` = CAST(TRIM(TRAILING '\r' FROM @sell_price) AS DECIMAL(8,2));

COMMIT;
SET autocommit = 1;
SET unique_checks = 1;

-- Primary key (fails on duplicate store/item/week rows = uniqueness check)
ALTER TABLE `sell_prices`
    ADD PRIMARY KEY (`store_id`, `item_id`, `wm_yr_wk`),
    ADD INDEX `idx_price_wk` (`wm_yr_wk`);

-- 3.1 Row count (expect 6,841,121)
SELECT COUNT(*) AS total_rows FROM `sell_prices`;

-- 3.2 Range / validity (expect no NULL, min_price > 0)
SELECT MIN(sell_price) AS min_price, MAX(sell_price) AS max_price,
       ROUND(AVG(sell_price), 2) AS avg_price,
       MIN(wm_yr_wk) AS first_wk, MAX(wm_yr_wk) AS last_wk
FROM `sell_prices`;

-- ==============================================================================
-- 4. Cross-table checks (needs all three tables)
-- ==============================================================================

-- 4.1 Price coverage in OUR window: share of sales rows that find a price
--     (expect about 99.8%; the missing 0.19% are all sales = 0, see 02_feature_engineering.sql)
SELECT
    COUNT(*)                                                 AS sales_rows,
    SUM(p.sell_price IS NOT NULL)                            AS rows_with_price,
    ROUND(100 * SUM(p.sell_price IS NOT NULL) / COUNT(*), 2) AS pct_with_price
FROM `sales_history` s
JOIN `calendar` c        ON s.`day` = c.`d`
LEFT JOIN `sell_prices` p
       ON p.`store_id` = s.`store_id`
      AND p.`item_id`  = s.`item_id`
      AND p.`wm_yr_wk` = c.`wm_yr_wk`;

-- 4.2 The same join for one store, to confirm the indexes are used
EXPLAIN
SELECT COUNT(*), SUM(p.sell_price IS NOT NULL)
FROM `sales_history` s
JOIN `calendar` c ON s.`day` = c.`d`
LEFT JOIN `sell_prices` p
       ON p.`store_id` = s.`store_id`
      AND p.`item_id`  = s.`item_id`
      AND p.`wm_yr_wk` = c.`wm_yr_wk`
WHERE s.`store_id` = 'CA_1';

-- 4.3 Sanity join sales_history x calendar
SELECT
    s.id,
    s.item_id,
    s.dept_id,
    s.store_id,
    s.day,
    s.sales,
    c.date,
    CASE
        WHEN c.event_name_1 IS NOT NULL OR c.event_name_2 IS NOT NULL THEN 1
        ELSE 0
    END AS is_holiday
FROM `sales_history` AS s
LEFT JOIN `calendar` AS c
    ON s.day = c.d
LIMIT 10;

-- ==============================================================================
-- 5. Data-quality audit on the full 365-day data (roadmap p2t6 + p2t7)
--    Four dimensions with exact counts. Fill the Before/After table in the report
--    from 5.5b. Supersedes the Week 1 audit, which ran on LIMIT 100000.
--    Expected values in the comments come from the CSV profiling in
--    process/misc/decision_results.md; confirm them when you run this.
-- ==============================================================================

-- 5.1 Full-year totals (the descriptive tables by category / store are in 03_kpi_queries.sql)
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

-- 5.2 COMPLETENESS: blanks / NULLs in every column (columns are NOT NULL, so also check '')
SELECT SUM(id = '')       AS blank_id,
       SUM(item_id = '')  AS blank_item_id,
       SUM(dept_id = '')  AS blank_dept_id,
       SUM(cat_id = '')   AS blank_cat_id,
       SUM(store_id = '') AS blank_store_id,
       SUM(state_id = '') AS blank_state_id,
       SUM(day = '')      AS blank_day,
       SUM(sales IS NULL) AS null_sales
FROM sales_history;

-- 5.2b Completeness of the grid: every day must hold exactly 30,490 series
SELECT COUNT(*) AS days_with_wrong_row_count                        -- expect 0
FROM (SELECT day FROM sales_history GROUP BY day HAVING COUNT(*) <> 30490) AS x;

-- 5.2c Join completeness: rows that find no calendar row
SELECT COUNT(*) AS rows_without_calendar                            -- expect 0
FROM sales_history s LEFT JOIN calendar c ON s.day = c.d
WHERE c.d IS NULL;

-- 5.3 UNIQUENESS: grain is (id, day). The primary key from step 2.7 already enforces
--     it; this query is the evidence for the report.
SELECT COUNT(*) AS total_rows,
       COUNT(DISTINCT id, day) AS distinct_id_day,
       COUNT(*) - COUNT(DISTINCT id, day) AS duplicate_rows           -- expect 0
FROM sales_history;

-- 5.4 VALIDITY
SELECT SUM(sales < 0)                                              AS negative_sales,          -- expect 0
       SUM(day NOT REGEXP '^d_[0-9]+$')                           AS bad_day_format,          -- expect 0
       SUM(CAST(SUBSTRING(day, 3) AS UNSIGNED) NOT BETWEEN 1577 AND 1941) AS day_out_of_window, -- expect 0
       SUM(id NOT LIKE CONCAT(item_id, '\_', store_id, '\_evaluation')) AS id_format_mismatch, -- expect 0
       SUM(LEFT(store_id, 2) <> state_id)                         AS store_state_mismatch     -- expect 0
FROM sales_history;

SELECT COUNT(*) AS price_rows, SUM(sell_price <= 0) AS nonpositive_price,      -- expect 0
       MIN(sell_price) AS min_price, MAX(sell_price) AS max_price
FROM sell_prices;

-- 5.5 OUTLIERS: global IQR (k = 1.5, upper bound only, same rule as Week 1 so the
--     numbers are comparable). Quantiles come from the exact value histogram
--     (nearest rank), which is cheap for integer sales.
--     DECISION (decision_results.md): outliers are RETAINED, nothing is removed or
--     capped. The numbers below are a sensitivity result that shows why: this rule
--     would discard about 73% of all units.
SET @n  := (SELECT COUNT(*) FROM sales_history);
SET @q1 := (SELECT MIN(sales) FROM (SELECT sales, SUM(COUNT(*)) OVER (ORDER BY sales) AS cum
                                    FROM sales_history GROUP BY sales) h WHERE cum >= 0.25 * @n);
SET @q3 := (SELECT MIN(sales) FROM (SELECT sales, SUM(COUNT(*)) OVER (ORDER BY sales) AS cum
                                    FROM sales_history GROUP BY sales) h WHERE cum >= 0.75 * @n);
SET @ub := @q3 + 1.5 * (@q3 - @q1);
SELECT @q1 AS q1, @q3 AS q3, @ub AS upper_bound;                  -- 0, 1, 2.5 (so values > 2 are outliers)

-- 5.5b Before vs After table (full year). The "After" row is the sensitivity case
--      only; the pipeline keeps the raw data.
SELECT 'Before (raw)' AS stage,
       COUNT(*) AS n, SUM(sales) AS units, MIN(sales) AS min_s, MAX(sales) AS max_s,
       ROUND(AVG(sales), 3) AS mean_s, ROUND(STDDEV_SAMP(sales), 3) AS sd_s
FROM sales_history
UNION ALL
SELECT 'After (sales <= upper bound)',
       COUNT(*), SUM(sales), MIN(sales), MAX(sales), ROUND(AVG(sales), 3), ROUND(STDDEV_SAMP(sales), 3)
FROM sales_history WHERE sales <= @ub;

-- 5.5c What the global IQR rule would throw away
SELECT SUM(sales > @ub)                                              AS outlier_rows,
       ROUND(100 * SUM(sales > @ub) / COUNT(*), 2)                   AS outlier_rows_pct,
       SUM(CASE WHEN sales > @ub THEN sales ELSE 0 END)              AS outlier_units,
       ROUND(100 * SUM(CASE WHEN sales > @ub THEN sales ELSE 0 END) / SUM(sales), 2) AS outlier_units_pct
FROM sales_history;

-- 5.5d Tail sizes
SELECT SUM(sales > 5) AS gt5, SUM(sales > 10) AS gt10, SUM(sales > 20) AS gt20, SUM(sales > 50) AS gt50
FROM sales_history;

-- ==============================================================================
-- NOT YET WRITTEN (no existing SQL covers these)
-- ==============================================================================
-- [x] Per-series outlier fence report: NOT NEEDED. Outliers are retained (decision_results.md,
--     "Outlier policy decision"). The brief asks for a documented rationale for retaining or
--     handling outliers; the global IQR counts in 5.5b-5.5c are the supporting evidence.
-- [ ] Optional: a row-count-per-table helper (see process/misc/check_state.sql).
