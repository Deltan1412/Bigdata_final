USE bigdataprj;
SELECT MIN(date) AS first_day, MAX(date) AS last_day, COUNT(DISTINCT wm_yr_wk) AS weeks
FROM calendar
WHERE d IN (SELECT DISTINCT day FROM sales_history);