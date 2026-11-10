-- ==============================================================================
-- Script Name : 02_structural_zeros.sql
-- Roadmap     : p2t8 (flag structural zeros: store_closed, on_sale from price)
-- Database    : bigdataprj   (MySQL 8.0)
-- Needs       : sales_history, calendar, sell_prices (import_sell_prices.sql done)
--
-- A zero in `sales` is not always "no demand". Two cases are structural:
--   store_closed : the whole store sold 0 units that day (Dec 25: 3 stores shut,
--                  the other 7 sold only 14 units chain-wide)
--   on_sale      : the item has a price row for that store and week.
--                  M5 has no price row for weeks before the item is introduced,
--                  so on_sale = 0 means "not on the shelf", not "no demand".
-- Both flags let the model and the stock-out analysis separate real zeros.
-- ==============================================================================

USE `bigdataprj`;

-- 1. Store-days with zero total sales (tiny table: 3 rows in this window)
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

-- 2. Feature view used by KNIME / Python instead of the bare calendar join.
--    A view keeps it cheap: nothing is materialised until it is read.
CREATE OR REPLACE VIEW `v_sales_features` AS
SELECT s.id, s.item_id, s.dept_id, s.cat_id, s.store_id, s.state_id, s.day, s.sales,
       c.date, c.wm_yr_wk, c.wday, c.month,
       CASE WHEN c.event_name_1 IS NOT NULL OR c.event_name_2 IS NOT NULL THEN 1 ELSE 0 END AS is_holiday,
       CASE s.state_id WHEN 'CA' THEN c.snap_CA WHEN 'TX' THEN c.snap_TX ELSE c.snap_WI END  AS snap,
       p.sell_price,
       CASE WHEN p.sell_price IS NOT NULL THEN 1 ELSE 0 END                                  AS on_sale,
       CASE WHEN d.store_id IS NOT NULL THEN 1 ELSE 0 END                                    AS store_closed
FROM sales_history s
JOIN calendar c               ON c.d = s.day
LEFT JOIN sell_prices p       ON p.store_id = s.store_id AND p.item_id = s.item_id AND p.wm_yr_wk = c.wm_yr_wk
LEFT JOIN store_day_closed d  ON d.store_id = s.store_id AND d.day = s.day;

-- 3. How many zeros are structural? (run once, scans 11M rows)
SELECT COUNT(*)                                                         AS total_rows,
       SUM(sales = 0)                                                   AS zero_rows,
       SUM(store_closed = 1)                                            AS store_closed_rows,
       SUM(on_sale = 0)                                                 AS not_on_sale_rows,
       SUM(store_closed = 1 AND on_sale = 0)                            AS both_flags,
       SUM(sales = 0 AND (store_closed = 1 OR on_sale = 0))             AS structural_zero_rows,
       SUM(sales = 0 AND store_closed = 0 AND on_sale = 1)              AS true_demand_zero_rows,
       SUM(sales > 0 AND (store_closed = 1 OR on_sale = 0))             AS flagged_but_nonzero  -- expect 0 (sanity)
FROM v_sales_features;

-- 4. Not-on-sale rows by store and department (shows where items are launched mid-window)
SELECT store_id, dept_id, COUNT(*) AS not_on_sale_rows
FROM v_sales_features
WHERE on_sale = 0
GROUP BY store_id, dept_id
ORDER BY not_on_sale_rows DESC
LIMIT 20;
