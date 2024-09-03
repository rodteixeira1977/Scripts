--
-- DESCRIPTION
-- Lista as top 10 query por ElapseTime do SQL_MONITOR
SET ECHO OFF TIMING OFF FEEDBACK OFF VERIFY OFF LINESIZE 1000 PAGESIZE 100 HEADING ON TAB OFF
--
col "SQL Texto" for a60
select *
 from (select SQL_ID,
 round(avg(ELAPSED_TIME)/1000000,1) "Media ET(s)",
 count(1) "EXECS",
 round(sum(ELAPSED_TIME)/1000000,1) "Total ET(s)" ,
 substr(SQL_TEXT,1,60) "SQL Texto"
 from v$sql_monitor
 group by SQL_ID,SQL_TEXT
 order by 2 DESC)
where EXECS > 1
 and rownum < 11;
SET LINESIZE 300 PAGESIZE 100 TRIM OFF TRIMSPOOL OFF TIMING ON FEEDBACK ON VERIFY ON