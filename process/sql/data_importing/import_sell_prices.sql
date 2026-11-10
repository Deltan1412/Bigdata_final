-- ==============================================================================
-- Script Name : import_sell_prices.sql
-- Description : DDL + bulk import for sell_prices.csv (weekly price per store x item)
-- Dataset     : M5 sell_prices.csv (6,841,121 data rows, ~203 MB, LF line endings)
-- Database    : bigdataprj
-- Target Table: sell_prices
-- Join key    : sales_history.day -> calendar.d -> calendar.wm_yr_wk
--               -> sell_prices (store_id, item_id, wm_yr_wk)
-- ==============================================================================

USE `bigdataprj`;

-- 1. Create table (keys are added AFTER the load: faster, and the PK doubles as the uniqueness check)
DROP TABLE IF EXISTS `sell_prices`;

CREATE TABLE `sell_prices` (
    `store_id`   VARCHAR(10)  NOT NULL,
    `item_id`    VARCHAR(50)  NOT NULL,
    `wm_yr_wk`   INT          NOT NULL,
    `sell_price` DECIMAL(8,2) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 2. Fast-load settings (same pattern as import_sales_history.sql)
SET GLOBAL local_infile = 1;
SET autocommit = 0;
SET unique_checks = 0;

-- 3. Bulk import. This file uses LF, so no '\r' is expected; TRIM is a safety net.
-- Edit the path for your machine (use forward slashes, or doubled backslashes, on Windows)
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

-- 4. Primary key (fails if there are duplicate store/item/week rows = uniqueness check)
ALTER TABLE `sell_prices`
    ADD PRIMARY KEY (`store_id`, `item_id`, `wm_yr_wk`),
    ADD INDEX `idx_price_wk` (`wm_yr_wk`);

-- ==============================================================================
-- 5. Verification
-- ==============================================================================

-- 5.1 Row count. Expected: 6,841,121
SELECT COUNT(*) AS total_rows FROM `sell_prices`;

-- 5.2 Range / validity. Expect no NULL, min_price > 0
SELECT MIN(sell_price) AS min_price, MAX(sell_price) AS max_price,
       ROUND(AVG(sell_price), 2) AS avg_price,
       MIN(wm_yr_wk) AS first_wk, MAX(wm_yr_wk) AS last_wk
FROM `sell_prices`;

-- 5.3 Coverage in OUR window: share of sales_history rows that find a price. Expected about 99.8%
SELECT
    COUNT(*)                                        AS sales_rows,
    SUM(p.sell_price IS NOT NULL)                   AS rows_with_price,
    ROUND(100 * SUM(p.sell_price IS NOT NULL) / COUNT(*), 2) AS pct_with_price
FROM `sales_history` s
JOIN `calendar` c        ON s.`day` = c.`d`
LEFT JOIN `sell_prices` p
       ON p.`store_id` = s.`store_id`
      AND p.`item_id`  = s.`item_id`
      AND p.`wm_yr_wk` = c.`wm_yr_wk`;
EXPLAIN
SELECT COUNT(*), SUM(p.sell_price IS NOT NULL)
FROM `sales_history` s
JOIN `calendar` c ON s.`day` = c.`d`
LEFT JOIN `sell_prices` p
       ON p.`store_id` = s.`store_id`
      AND p.`item_id`  = s.`item_id`
      AND p.`wm_yr_wk` = c.`wm_yr_wk`
WHERE s.`store_id` = 'CA_1';