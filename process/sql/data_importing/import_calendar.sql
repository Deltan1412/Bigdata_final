-- ==============================================================================
-- Script Name : import_calendar.sql
-- Description : DDL and Import script for data/raw/calendar.csv into MySQL
-- Database    : bigdataprj
-- Target Table: calendar
-- ==============================================================================

-- 1. Ensure target database is selected
CREATE DATABASE IF NOT EXISTS `bigdataprj`
    DEFAULT CHARACTER SET utf8mb4
    DEFAULT COLLATE utf8mb4_0900_ai_ci;

USE `bigdataprj`;

-- 2. Create the calendar table
-- Primary Key is set on `d` ('d_1', 'd_2', ...) because it is joined with `sales_history.day`
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

-- ==============================================================================
-- IMPORT METHOD 1: LOAD DATA LOCAL INFILE (Fast bulk import from CSV)
-- ==============================================================================
-- NOTES:
-- 1) If using MySQL CLI, connect with: mysql --local-infile=1 -u <username> -p
-- 2) If using MySQL Workbench, make sure "OPT_LOCAL_INFILE=1" is enabled in connection settings.
-- 3) Replace '/absolute/path/to/data/raw/calendar.csv' with your actual file path if different.
-- 4) The SET clause uses NULLIF() to convert empty strings '' to true NULL values.
--    This is crucial so that queries like `event_name_1 IS NOT NULL` properly identify holidays.

SET GLOBAL local_infile = 1;

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

-- ==============================================================================
-- ALTERNATIVE IMPORT METHOD 2: Direct Self-Contained INSERTs
-- ==============================================================================
-- If your MySQL environment restricts LOAD DATA (e.g. secure_file_priv or local_infile=0),
-- you can run the pre-generated batch INSERT script:
--   SOURCE process/big-data-analytics-project/import_calendar_data.sql;
-- (Or open import_calendar_data.sql in MySQL Workbench and execute it directly).

-- ==============================================================================
-- 3. Verification & Quality Checks
-- ==============================================================================

-- 3.1 Verify total row count (Expect: 1,969)
SELECT COUNT(*) AS total_imported_days FROM `calendar`;

-- 3.2 Inspect sample rows
SELECT * FROM `calendar` ORDER BY `date` ASC LIMIT 5;
SELECT * FROM `calendar` ORDER BY `date` DESC LIMIT 5;

-- 3.3 Verify holiday distribution (events correctly stored as NULL vs non-NULL)
SELECT
    COUNT(*) AS total_days,
    SUM(CASE WHEN `event_name_1` IS NOT NULL OR `event_name_2` IS NOT NULL THEN 1 ELSE 0 END) AS holiday_count,
    SUM(CASE WHEN `event_name_1` IS NULL AND `event_name_2` IS NULL THEN 1 ELSE 0 END) AS regular_days
FROM `calendar`;

-- 3.4 Sanity join check with sales_history (matching data_preparation.sql)
SELECT
    s.id,
    s.item_id,
    s.day,
    s.sales,
    c.date,
    CASE
        WHEN c.event_name_1 IS NOT NULL OR c.event_name_2 IS NOT NULL THEN 1
        ELSE 0
    END AS is_holiday
FROM sales_history AS s
LEFT JOIN calendar AS c
    ON s.day = c.d
LIMIT 10;
