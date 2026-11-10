-- ==============================================================================
-- Script Name : 04_sales_predictions_schema.sql
-- Purpose     : Table that receives the predictions written back from KNIME (DB Writer).
-- Database    : bigdataprj   (MySQL 8.0)
--
-- Built from  : dump/bigdataprj_backup_20261109.sql   (CREATE TABLE sales_predictions)
--               data_manipulating/dedupe_sales_predictions.sql   (UNIQUE key, dedupe)
--
-- Required columns (required_files.md): forecast_day, predicted_sales, actual_sales,
-- model_name, prediction_date.
-- ==============================================================================

USE `bigdataprj`;

-- ------------------------------------------------------------------------------
-- 1. Table
--    The UNIQUE key stops duplicate predictions. KNIME's DB Writer in APPEND mode
--    wrote every row twice (39,496 rows instead of 19,748). With this key a repeated
--    run fails instead of silently doubling the table.
--    Note: a NULL model_name is never treated as a duplicate by a UNIQUE key, so
--    always write a model_name.
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `sales_predictions` (
    `id`              BIGINT        NOT NULL AUTO_INCREMENT,
    `item_id`         VARCHAR(100)  NOT NULL,
    `store_id`        VARCHAR(20)   NOT NULL,
    `forecast_day`    VARCHAR(20)   NOT NULL,                     -- 'd_1869', same format as sales_history.day
    `predicted_sales` DECIMAL(12,4) NOT NULL,
    `actual_sales`    DECIMAL(12,4) DEFAULT NULL,
    `model_name`      VARCHAR(100)  DEFAULT NULL,                 -- e.g. 'LinearRegression_v1'
    `prediction_date` TIMESTAMP     NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_prediction` (`item_id`, `store_id`, `forecast_day`, `model_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 1.1 Check the structure
DESCRIBE `sales_predictions`;

-- ------------------------------------------------------------------------------
-- 2. Repair for an OLD sales_predictions table that already holds duplicates
--    (created before the UNIQUE key existed). Not needed after a fresh run of
--    section 1. Uncomment and run once; keeps the lowest id of each duplicate group.
--    Original: dedupe_sales_predictions.sql (a stray "SQL" line that would fail to
--    parse was dropped).
-- ------------------------------------------------------------------------------
-- CREATE TABLE sales_predictions_dedup LIKE sales_predictions;
--
-- INSERT INTO sales_predictions_dedup
-- SELECT sp.*
-- FROM sales_predictions sp
-- JOIN (SELECT MIN(id) AS id
--       FROM sales_predictions
--       GROUP BY item_id, store_id, forecast_day, model_name) k
--   ON k.id = sp.id;
--
-- SELECT COUNT(*) AS rows_after FROM sales_predictions_dedup;   -- expect 19,748
--
-- RENAME TABLE sales_predictions TO sales_predictions_old,
--              sales_predictions_dedup TO sales_predictions;
-- ALTER TABLE sales_predictions
--     ADD UNIQUE KEY uk_prediction (item_id, store_id, forecast_day, model_name);
-- SELECT COUNT(*) AS final_rows FROM sales_predictions;
--
-- DROP TABLE sales_predictions_old;

-- ==============================================================================
-- 3. Weekly predictions table (store x department x week)   PROPOSAL, NOT YET CREATED
--    The table in section 1 is the old item x store x day design (Week 2, R2 0.016).
--    The weekly pipeline (decision_results.md, roadmap p3t4) writes to a NEW table so the
--    old table and the draft dashboard keep working until the new one is ready.
--
--    Required columns from required_files.md are kept:
--      forecast_day    = first day of the forecast week, same format as sales_history.day
--                        (v_weekly_features.first_day)
--      predicted_sales = clipped at 0 (MIN(predicted_sales) >= 0 is checked after the write)
--      actual_sales    = the week's real units, copied from v_weekly_features.sales
--      model_name, prediction_date
--    Grain: one row per store x department x week x model. The UNIQUE key makes a second
--    run fail instead of doubling the table. model_name is NOT NULL because a UNIQUE key
--    never treats NULLs as equal.
--    Only test weeks (week_idx 43-52, split = 'test') are written: 70 x 10 = 700 rows
--    per model.
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `sales_predictions_weekly` (
    `id`              BIGINT        NOT NULL AUTO_INCREMENT,
    `store_id`        VARCHAR(10)   NOT NULL,
    `dept_id`         VARCHAR(50)   NOT NULL,
    `wm_yr_wk`        INT           NOT NULL,
    `week_idx`        SMALLINT      NOT NULL,
    `forecast_day`    VARCHAR(20)   NOT NULL,
    `predicted_sales` DECIMAL(12,4) NOT NULL,
    `actual_sales`    DECIMAL(12,4) NOT NULL,
    `model_name`      VARCHAR(100)  NOT NULL,
    `prediction_date` TIMESTAMP     NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_prediction_weekly` (`store_id`, `dept_id`, `wm_yr_wk`, `model_name`),
    -- forecast_day must be a real calendar day ('d_1870'): gives the schema a second foreign key
    CONSTRAINT `fk_pred_weekly_calendar` FOREIGN KEY (`forecast_day`) REFERENCES `calendar` (`d`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- If the table already exists without the foreign key (CREATE ... IF NOT EXISTS skips it), add it:
-- ALTER TABLE `sales_predictions_weekly`
--     ADD CONSTRAINT `fk_pred_weekly_calendar` FOREIGN KEY (`forecast_day`) REFERENCES `calendar` (`d`);

-- 3.1 After every KNIME run (expect 700 rows per model, no negative prediction, no repeats)
SELECT model_name, COUNT(*) AS rows_n, MIN(predicted_sales) AS min_pred,       -- 700, >= 0
       COUNT(DISTINCT store_id, dept_id, wm_yr_wk) AS distinct_keys,           -- 700
       MIN(week_idx) AS first_week_idx, MAX(week_idx) AS last_week_idx         -- 43, 52
FROM sales_predictions_weekly GROUP BY model_name;

-- 3.2 Leakage / coverage checks (roadmap p3t9, p3t10; needs weekly_features from 02 section 5.1)
-- a) Predictions written for a week that is not a test week            (expect 0)
SELECT COUNT(*) AS predictions_outside_test
FROM sales_predictions_weekly p
JOIN weekly_features f ON f.store_id = p.store_id AND f.dept_id = p.dept_id AND f.wm_yr_wk = p.wm_yr_wk
WHERE f.split <> 'test';
-- b) Test weeks (7 full days) with no prediction, per model            (expect 0)
SELECT m.model_name, COUNT(*) AS missing_test_rows
FROM (SELECT DISTINCT model_name FROM sales_predictions_weekly) m
JOIN weekly_features f ON f.split = 'test' AND f.n_days = 7
LEFT JOIN sales_predictions_weekly p ON p.model_name = m.model_name AND p.store_id = f.store_id
                                    AND p.dept_id = f.dept_id AND p.wm_yr_wk = f.wm_yr_wk
WHERE p.id IS NULL
GROUP BY m.model_name;

-- ==============================================================================
-- STILL TO DO IN KNIME (see process/misc/guide/knime_guide.md)
-- ==============================================================================
-- [ ] The DB Writer must empty the target before writing, then confirm the row
--     count and MIN(predicted_sales) >= 0 (roadmap p3t10; queries 3.1 and 3.2 above).
--     Running the workflow twice must not grow the table (roadmap e3e).
--     Use a DB SQL Executor before the Writer (Writer in Append mode, "do not change" table
--     structure). Do NOT use the Writer's drop/replace option: it recreates the table and
--     loses the UNIQUE key and the foreign key.
--       one model in the table :  TRUNCATE TABLE sales_predictions_weekly;     (knime_guide.md)
--       several models         :  DELETE FROM sales_predictions_weekly
--                                 WHERE model_name = 'LinearRegression_weekly_v1';
--     TRUNCATE would also wipe a baseline model written to the same table.
