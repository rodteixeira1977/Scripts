select 'alter system kill session '''||sid||','||serial#||',@'||inst_id||''' immediate;' from gv$session where status = 'ACTIVE' and sql_id = '&SQL_ID';
