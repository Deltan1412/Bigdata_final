USE bigdataprj;

SELECT GROUP_CONCAT(
         CONCAT('SELECT ''', table_name, ''' AS table_name, COUNT(*) AS row_count FROM `', table_name, '`')
         SEPARATOR ' UNION ALL ')
INTO @sql
FROM information_schema.tables
WHERE table_schema = DATABASE() AND table_type = 'BASE TABLE';

SET SESSION group_concat_max_len = 1000000;  -- run this BEFORE the SELECT above if you have many tables
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;