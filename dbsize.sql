col TAMANHO_DB for a30

select b.name||': '||round(sum(a.bytes)/1024/1024/1024, 2) ||' Gb' as TAMANHO_DB
from (
  select bytes from dba_data_files
union all
  select bytes from dba_temp_files
union all
  select  bytes*members as bytes from v$log
) a, v$database b
group by b.name
/
