SHOW FULL PROCESSLIST;

SELECT trx_mysql_thread_id, trx_state, trx_started, trx_rows_locked, trx_query
FROM information_schema.innodb_trx
ORDER BY trx_started;