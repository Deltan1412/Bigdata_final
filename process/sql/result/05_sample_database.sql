-- ==============================================================================
-- Script Name : 05_sample_database.sql
-- Purpose     : Build the small, reproducible sample database that becomes the required
--               deliverable m5_database_dump_sample.sql (required_files.md, section B), so a
--               reviewer can test the pipeline without the 839 MB CSV or the 1-2 GB dumps.
-- Database    : reads `bigdataprj` (full data), writes `bigdataprj_sample`   (MySQL 8.0)
-- Needs       : 01_schema_and_import.sql, 04_sales_predictions_schema.sql (the table)
--
-- WHAT THE SAMPLE HOLDS
--   calendar                  all 1,969 rows
--   sales_history             1% of the series (CRC32(id) % 100 = 0, about 305 series,
--                             about 111,000 rows, all 365 days). Same rule as
--                             weekly_features_sample in 02, so the two samples agree.
--   sell_prices               only the (store, item) pairs of the sampled series
--   sales_predictions_weekly  empty: the reviewer fills it by running KNIME
--   Base tables only. Views and derived tables are rebuilt by running 02 on the sample
--   (a dump would keep the view definitions pointing at bigdataprj_sample).
--
-- SAMPLE CAVEATS (say so in the README)
--   * Units are about 1% of the real size and a few store x department series may be thin.
--     Do not quote sample results in the report.
--   * 02 section 1 flags a store-day as closed when the store sold 0 units. With 1% of the
--     items, many stores show 0 on some days besides Dec 25, so closed_days is noisy.
-- ==============================================================================

CREATE DATABASE IF NOT EXISTS `bigdataprj_sample`
    DEFAULT CHARACTER SET utf8mb4
    DEFAULT COLLATE utf8mb4_0900_ai_ci;

USE `bigdataprj_sample`;

-- ------------------------------------------------------------------------------
-- 1. Tables (LIKE copies columns, primary keys and indexes; foreign keys are added below)
-- ------------------------------------------------------------------------------
DROP TABLE IF EXISTS `sales_predictions_weekly`;
DROP TABLE IF EXISTS `sales_history`;
DROP TABLE IF EXISTS `sell_prices`;
DROP TABLE IF EXISTS `calendar`;

CREATE TABLE `calendar`                 LIKE `bigdataprj`.`calendar`;
CREATE TABLE `sales_history`            LIKE `bigdataprj`.`sales_history`;
CREATE TABLE `sell_prices`              LIKE `bigdataprj`.`sell_prices`;
CREATE TABLE `sales_predictions_weekly` LIKE `bigdataprj`.`sales_predictions_weekly`;

-- ------------------------------------------------------------------------------
-- 2. Fill (reads 11M rows once, a few minutes)
-- ------------------------------------------------------------------------------
INSERT INTO `calendar` SELECT * FROM `bigdataprj`.`calendar`;

INSERT INTO `sales_history`
SELECT * FROM `bigdataprj`.`sales_history`
WHERE CRC32(`id`) % 100 = 0;

INSERT INTO `sell_prices`
SELECT p.*
FROM `bigdataprj`.`sell_prices` p
JOIN (SELECT DISTINCT `store_id`, `item_id` FROM `sales_history`) s
  ON s.`store_id` = p.`store_id` AND s.`item_id` = p.`item_id`;

-- ------------------------------------------------------------------------------
-- 3. Foreign keys, same as the full database
-- ------------------------------------------------------------------------------
ALTER TABLE `sales_history`
    ADD CONSTRAINT `fk_sales_calendar` FOREIGN KEY (`day`) REFERENCES `calendar` (`d`);
ALTER TABLE `sales_predictions_weekly`
    ADD CONSTRAINT `fk_pred_weekly_calendar` FOREIGN KEY (`forecast_day`) REFERENCES `calendar` (`d`);

-- ------------------------------------------------------------------------------
-- 4. Checks
-- ------------------------------------------------------------------------------
SELECT (SELECT COUNT(*) FROM `calendar`)                                AS calendar_rows,       -- 1,969
       (SELECT COUNT(*) FROM `sales_history`)                           AS sales_rows,          -- about 111,000
       (SELECT COUNT(DISTINCT `id`) FROM `sales_history`)               AS series,              -- about 305
       (SELECT COUNT(DISTINCT `day`) FROM `sales_history`)              AS days,                -- 365
       (SELECT COUNT(*) FROM `sell_prices`)                             AS price_rows,
       (SELECT COUNT(*) FROM `sales_predictions_weekly`)                AS prediction_rows;     -- 0

-- Every store x department should still be present (expect 70)
SELECT COUNT(DISTINCT `store_id`, `dept_id`) AS store_dept_series FROM `sales_history`;

-- ------------------------------------------------------------------------------
-- 5. Export (run in a terminal, NOT in this script; replace the placeholders)
--      mysqldump -u <YOUR_USER> -p --single-transaction --no-tablespaces --set-gtid-purged=OFF ^
--                bigdataprj_sample > m5_database_dump_sample.sql
--    The dump has no CREATE DATABASE / USE line, so it restores into any empty schema.
--
--    REVIEWER'S RESTORE (goes into the README):
--      mysql -u <YOUR_USER> -p -e "CREATE DATABASE bigdataprj"
--      mysql -u <YOUR_USER> -p bigdataprj < m5_database_dump_sample.sql
--      then run 02_feature_engineering.sql in full and 04 section 3 (the table is already in
--      the dump, so that statement is a no-op), run the KNIME workflow, then 03 Part C and
--      refresh Power BI.
--    Size check: the file should be a few MB, small enough for GitHub.
-- ------------------------------------------------------------------------------
