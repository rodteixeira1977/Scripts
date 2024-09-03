
-- Índices da Tabela

set heading on
col OWNER for a20
col R_OWNER for a15
col INDEX_OWNER for a20
col INDEX_NAME for a20
column uniqueness format a9 heading 'Unique?'
column index_name format a30 heading 'Index|Name'
column table_name format a24 heading 'Table|Name'
column column_name format a24 heading 'Column|Name'
column table_type format a8 heading 'Index|Type'
column constraint_name format a20 
column r_constraint_name format a20
undef OWNER;
undef TABLE;
break on table_name skip 1 on table_type on index_name on uniqueness
select b.table_name, b.index_name,
uniqueness, a.column_name
from dba_ind_columns a, dba_indexes b
where b.owner = '&&OWNER'
and b.table_name = '&&TABLE'
and a.index_name = b.index_name
and a.table_name = b.table_name
order by b.table_type, b.table_name,
b.index_name, a.column_position
;

-- CONSTRAINTS da Tabela
select a.owner,a.CONSTRAINT_NAME,a.CONSTRAINT_TYPE,a.TABLE_NAME,a.R_OWNER,a.R_CONSTRAINT_NAME,c.table_name R_TABLE_NAME,b.column_name, b.position, a.STATUS,a.index_owner,a.index_name
from dba_constraints a, dba_cons_columns b, dba_indexes c
where a.owner = b.owner and a.constraint_name = b.constraint_name and a.owner = c.owner and a.r_constraint_name = c.index_name 
and a.owner = '&&OWNER' and a.TABLE_NAME=upper('&&TABLE')
and a.constraint_type='R';


select owner,segment_name,segment_type,bytes/1024/1024,tablespace_name MB,partition_name from dba_segments where owner='&&OWNER' and segment_name in ('&&TABLE') order by partition_name;

select owner,table_name,degree,last_analyzed,num_rows from dba_tables where owner = '&&OWNER' and table_name ='&&TABLE';

select '_______Rows|Chain|AvgFSpace|___Blocks|Empty|AvgRowLen|Analyzed_|Table_________'
       from dual union all
select substr (S, 1, 120) from (
  select lpad (to_char (nvl (t.NUM_ROWS, 0), 'FM999G999G990'), 11, ' ') ||'|'||
         lpad (to_char (nvl (t.CHAIN_CNT * 100 / greatest (1, t.NUM_ROWS), 0), 'FM90D0'), 4, ' ') ||'%|'||
         lpad (to_char (nvl (t.AVG_SPACE / 1024, 0), 'FM99990D00'), 8, ' ') ||'k|'||
         lpad (to_char (nvl (t.BLOCKS, 0), 'FM999999990'), 9, ' ') ||'|'||
         lpad (to_char (nvl (t.EMPTY_BLOCKS * 100 / greatest (1, t.BLOCKS), 0), 'FM90D0'), 4, ' ') ||'%|'||
         lpad (to_char (nvl (t.AVG_ROW_LEN, 0), 'FM999990D0'), 8, ' ') ||'k|'||
         nvl (to_char (t.LAST_ANALYZED, 'DDMonYYYY'), '--never--') ||'|'||
         t.OWNER ||'.'|| t.TABLE_NAME
         S
    from DBA_TABLES t
   where t.OWNER = '&&OWNER' and  t.TABLE_NAME='&&TABLE'
   order by t.OWNER, t.TABLE_NAME
);

SELECT column_name, num_distinct, histogram 
FROM   dba_tab_col_statistics 
WHERE  owner = '&&OWNER' and table_name = '&&TABLE'; 

