-- Active: 1794192990810@@127.0.0.1@3306@bigdataprj
CREATE TABLE sales_predictions_dedup LIKE sales_predictions;

INSERT INTO sales_predictions_dedup
SELECT sp.*
FROM sales_predictions sp
JOIN (SELECT MIN(id) AS id
      FROM sales_predictions
      GROUP BY item_id, store_id, forecast_day, model_name) k
  ON k.id = sp.id;

SELECT COUNT(*) AS rows_after FROM sales_predictions_dedup;  -- expect 19748
SQL

RENAME TABLE sales_predictions TO sales_predictions_old,
             sales_predictions_dedup TO sales_predictions;
ALTER TABLE sales_predictions
ADD UNIQUE KEY uk_prediction (item_id, store_id, forecast_day, model_name);
SELECT COUNT(*) AS final_rows FROM sales_predictions;

DROP TABLE sales_predictions_old;

SHOW TABLES;

