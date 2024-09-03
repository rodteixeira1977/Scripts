
prompt
prompt *** Exibe Informacoes sobre Tabelas ***
prompt

accept vOwner    char prompt "Schema / Owner ....................: "
accept vTbl      char prompt "Nome da Tabela ....................: "

COL OWNER FOR A20
COL TABLE_NAME FOR A30
COL TABLESPACE_NAME FOR A20
COL STATUS FOR A10
COL TIPO FOR A20
COL INDEX_NAME FOR A30
COL CONSTRAINT_NAME FOR A30
COL TRIGGER_NAME FOR A30
COL CHAVE_REFERENCIADA for a35
COL COLUMN_NAME for a35

set feedback off

prompt
prompt ********** Tamanho e Armazenamento *************

select owner, table_name, tablespace_name, status, num_rows LINHAS, LAST_ANALYZED, PARTITIONED, COMPRESSION
from dba_tables
where owner = upper('&vOwner')
  and table_name = upper('&vTbl');


prompt
prompt ********** Informacoes sobre as colunas da tabela ************


select -- table_name,
       column_id POS,
       column_name, 
       data_type||'('||data_length||','||data_precision||')' "TIPO",
       nullable "NULL"
  from dba_tab_columns
 where owner like upper('&vOwner')
   and table_name like upper('&vTbl')
 order by table_name, column_id;

prompt
prompt ********** Informacoes sobre as Constraints ***************

select -- table_name,
       constraint_name,
       constraint_type,
       status,
       index_name,
       r_owner||'.'||r_constraint_name CHAVE_REFERENCIADA,
       status,
       deferred,
       DELETE_RULE,
       search_condition "CHECK"
 from dba_constraints
where owner like upper('&vOwner')
  and table_name like upper('&vTbl')
order by table_name, constraint_type, constraint_name;

prompt
prompt *************** Informacoes dos Indices ********************

select -- table_name, 
       index_name, 
       column_position POS,
       column_name, 
       column_length, 
       descend
  from dba_ind_columns
 where table_owner like upper('&vOwner')
   and table_name like upper('&vTbl')
 order by index_name, column_position;

prompt
prompt ***************** Informacoes das Triggers *******************

select -- table_name,
       trigger_name,
       trigger_type,
       triggering_event,
       status
from dba_triggers
where owner like upper('&vOwner')
  and table_name like upper('&vTbl')
order by table_name, trigger_name;


prompt
prompt ***************** Dependencias - Tabelas Filhas *******************
select c.owner, c.table_name, c.constraint_name, status, deferred, validated
  from dba_constraints c, 
       ( select owner, 
                constraint_name
           from dba_constraints
          where owner = upper('&vOwner')
            and table_name = '&vTbl'
            and constraint_type = 'P' ) P
 where c.r_owner = p.owner and c.r_constraint_name = p.constraint_name;


prompt
set feedback on


