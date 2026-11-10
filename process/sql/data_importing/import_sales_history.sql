-- ==============================================================================
-- Script Name : import_sales_history.sql
-- Description : Optimized DDL and Bulk Import script for m5_sales_last_365_days.csv
-- Dataset     : M5 Forecasting - Last 365 Days (~11,128,850 rows, ~839 MB)
-- Database    : bigdataprj
-- Target Table: sales_history
-- ==============================================================================

-- 1. Ensure target database exists and is selected
CREATE DATABASE IF NOT EXISTS `bigdataprj`
    DEFAULT CHARACTER SET utf8mb4
    DEFAULT COLLATE utf8mb4_0900_ai_ci;

USE `bigdataprj`;

-- 2. Drop existing table if recreating
DROP TABLE IF EXISTS `sales_history`;

-- 3. Create sales_history table
-- Note: Indexes are added AFTER data load for drastically faster ingestion.
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

-- ==============================================================================
-- 4. Ingestion Performance Optimizations
-- ==============================================================================
-- Enable local_infile for client session
SET GLOBAL local_infile = 1;

-- Temporarily disable integrity checks and autocommit for fast bulk insertion
SET @OLD_AUTOCOMMIT = @@AUTOCOMMIT;
SET @OLD_UNIQUE_CHECKS = @@UNIQUE_CHECKS;
SET @OLD_FOREIGN_KEY_CHECKS = @@FOREIGN_KEY_CHECKS;
SET @OLD_SQL_MODE = @@SQL_MODE;

SET autocommit = 0;
SET unique_checks = 0;
SET foreign_key_checks = 0;
SET sql_mode = '';

-- Optional (if your MySQL user has SUPER/SYSTEM_VARIABLES_ADMIN privileges):
-- SET sql_log_bin = 0;

-- ==============================================================================
-- 5. Bulk Import via LOAD DATA LOCAL INFILE
-- ==============================================================================
-- Note on line terminator: m5_sales_last_365_days.csv uses Windows CRLF (\r\n).
-- We specify LINES TERMINATED BY '\r\n' and TRIM trailing '\r' on @sales to ensure
-- no carriage return characters pollute the integer sales column.

LOAD DATA LOCAL INFILE '/media/deltan/Else/VNUK/Bigdata_Analysis/Final/data/raw/m5_sales_last_365_days.csv'
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

-- Commit the transaction after bulk load
COMMIT;

-- Restore session settings
SET autocommit = @OLD_AUTOCOMMIT;
SET unique_checks = @OLD_UNIQUE_CHECKS;
SET foreign_key_checks = @OLD_FOREIGN_KEY_CHECKS;
SET sql_mode = @OLD_SQL_MODE;

-- ==============================================================================
-- 6. Post-Import Indexing
-- ==============================================================================
-- Creating indexes after loading 11M rows is 5-10x faster than loading into an
-- already indexed table.

-- Index on `day` optimizes the join: sales_history.day = calendar.d
CREATE INDEX `idx_sales_day` ON `sales_history` (`day`);

-- Composite index optimizes filtering and grouping by store & item in forecasting
CREATE INDEX `idx_sales_store_item` ON `sales_history` (`store_id`, `item_id`);

-- Index for category/department aggregations
CREATE INDEX `idx_sales_cat_dept` ON `sales_history` (`cat_id`, `dept_id`);

-- ==============================================================================
-- 7. Verification & Sanity Checks
-- ==============================================================================

-- 7.1 Verify total row count (Expected: 11,128,850 rows)
SELECT COUNT(*) AS total_rows FROM `sales_history`;

-- 7.2 Inspect sample rows
SELECT * FROM `sales_history` LIMIT 10;

-- 7.3 Distribution summary across stores and states
SELECT
    `state_id`,
    `store_id`,
    COUNT(*) AS total_records,
    SUM(`sales`) AS total_units_sold,
    AVG(`sales`) AS avg_daily_sales
FROM `sales_history`
GROUP BY `state_id`, `store_id`
ORDER BY `state_id`, `store_id`;

-- 7.4 Verify join with calendar table (data_preparation.sql logic)
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
