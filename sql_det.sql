col plan_hash_value FOR 999999999999
col sql_plan_baseline FOR a40
col sql_profile FOR a30
col sql_patch FOR a20

SELECT s.plan_hash_value,
       s.sql_plan_baseline,
       s.sql_profile,
       s.sql_patch,
       s.child_number,
       s.hash_value
FROM   gv$sql s
WHERE sql_id = '&sql_id';
