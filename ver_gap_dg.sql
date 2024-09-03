SET serveroutput on
SET WRAP ON
SET long 300
SET lines 500
SET TRIMSPOOL ON
SET PAGESIZE  0
SET VERIFY    OFF
SET PAGESIZE  9999
SET FEED OFF

COLUMN DESTINATION FORMAT A30

COLUMN F_LOG                   HEADING 'FORCE|LOGGING'                format a10
COLUMN FLASHB_ON               HEADING 'FLASHB|ATIVADO'                format a10

column db_unique_name format a15
column flashb_on format a10
column host_name format a30 tru 
column version format a10 tru 
column destination format a35 wrap 
column process format a7 
column archiver format a8 
column dest_id format 99999999 

---------------------------------------------------------------------------------
-- Script de troubleshooting para Oracle Data Guard
-- Autor: Luciano Alvarenga Maciel Pires
-- Data: 15/08/2017
--
-- Esse script devera ser executado sempre no ambiente da primaria e todas as 
-- informaçs providas devem ser analisadas posteriormente por um administrador 
-- de banco de dados
--
------------------------------------------------------------------------------------
-- |   Historico de alteracao                                                      |
-- |DATA       | Quem        | Motivo                                              |
-- |17/08/2017 | Luciano Luke| Data de criaç do script                           |
-- |21/08/2017 | Luciano Luke| Incluso verificacao de gap + ~ Archives/Hora        |
-- |21/08/2017 | Luciano Luke| Verificao de gap com base nas ultimas 3 horas de    |
-- |                           geracao de archive + 15% + 1 (caso for 0)           |
------------------------------------------------------------------------------------

spool report_troubleshotting_Dataguard.log

set head off
select CHR(10) from dual;
select CHR(10) from dual;
select CHR(10) from dual;
set head on


PROMPT ----------------------------------- Troubleshooting Oracle Data Guard ----------------------------------- 


set head off
select CHR(10) from dual;
select CHR(10) from dual;
select CHR(10) from dual;
set head on

PROMPT 1.1-INFORMACOES DE CONFIG. DO SERVIDOR PRIMARIO (PRIMARY)

select DB_UNIQUE_NAME,DATABASE_ROLE DB_ROLE,FORCE_LOGGING F_LOG,FLASHBACK_ON FLASHB_ON,LOG_MODE,OPEN_MODE,
       GUARD_STATUS GUARD,PROTECTION_MODE PROT_MODE
from v$database;

select INSTANCE_NAME,HOST_NAME,VERSION,ARCHIVER from v$instance;

select DEST_ID,DESTINATION,STATUS,TARGET,ARCHIVER,PROCESS,REGISTER,TRANSMIT_MODE  
from v$archive_dest
where DESTINATION IS NOT NULL;

set head off
select CHR(10) from dual;
select CHR(10) from dual;
select CHR(10) from dual;
set head on


PROMPT 1.2-PARAMETROS

DECLARE
  vp_1    VARCHAR2(500);
BEGIN
----log_archive_dest_state_N
DBMS_OUTPUT.PUT_LINE('..................................................................................'); 
  DBMS_OUTPUT.PUT_LINE('LOG_ARCHIVE_DEST_STATE<n>');
  select value into vp_1 from v$parameter where name='log_archive_dest_state_1';
  DBMS_OUTPUT.PUT_LINE(' |-01: [' || vp_1 || ']'); 
  select value into vp_1 from v$parameter where name='log_archive_dest_state_2';
  DBMS_OUTPUT.PUT_LINE(' |-02: [' || vp_1 || ']'); 
  select value into vp_1 from v$parameter where name='log_archive_dest_state_3';
  DBMS_OUTPUT.PUT_LINE(' |-03: [' || vp_1 || ']'); 
  select value into vp_1 from v$parameter where name='log_archive_dest_state_4';
  DBMS_OUTPUT.PUT_LINE(' |-04: [' || vp_1 || ']'); 
  select value into vp_1 from v$parameter where name='log_archive_dest_state_5';
  DBMS_OUTPUT.PUT_LINE(' |-05: [' || vp_1 || ']'); 
DBMS_OUTPUT.PUT_LINE('..................................................................................'); 
----log_archive_destN
  DBMS_OUTPUT.PUT_LINE('LOG_ARCHIVE_DEST_<n>');
  select value into vp_1 from v$parameter where name='log_archive_dest_1';
  DBMS_OUTPUT.PUT_LINE(' |-01: [' || vp_1 || ']'); 
  select value into vp_1 from v$parameter where name='log_archive_dest_2';
  DBMS_OUTPUT.PUT_LINE(' |-02: [' || vp_1 || ']'); 
  select value into vp_1 from v$parameter where name='log_archive_dest_3';
  DBMS_OUTPUT.PUT_LINE(' |-03: [' || vp_1 || ']'); 
  select value into vp_1 from v$parameter where name='log_archive_dest_4';
  DBMS_OUTPUT.PUT_LINE(' |-04: [' || vp_1 || ']'); 
  select value into vp_1 from v$parameter where name='log_archive_dest_5';
  DBMS_OUTPUT.PUT_LINE(' |-05: [' || vp_1 || ']'); 
DBMS_OUTPUT.PUT_LINE('..................................................................................'); 
  select value into vp_1 from v$parameter where name='log_archive_config';
  DBMS_OUTPUT.PUT_LINE('log_archive_config             ['  || vp_1 || ']');
  select value into vp_1 from v$parameter where name='log_archive_trace';
  DBMS_OUTPUT.PUT_LINE('log_archive_trace              ['  || vp_1 || ']');
  select value into vp_1 from v$parameter where name='log_archive_format';
  DBMS_OUTPUT.PUT_LINE('log_archive_format             ['  || vp_1 || ']');
  select value into vp_1 from v$parameter where name='standby_file_management';
  DBMS_OUTPUT.PUT_LINE('standby_file_management        ['  || vp_1 || ']');
  select value into vp_1 from v$parameter where name='archive_lag_target';
  DBMS_OUTPUT.PUT_LINE('archive_lag_target             ['  || vp_1 || ']');
  select value into vp_1 from v$parameter where name='log_archive_max_processes';
  DBMS_OUTPUT.PUT_LINE('log_archive_max_processes      ['  || vp_1 || ']');
  select value into vp_1 from v$parameter where name='log_archive_min_succeed_dest';
  DBMS_OUTPUT.PUT_LINE('log_archive_min_succeed_dest   ['  || vp_1 || ']');
  select value into vp_1 from v$parameter where name='remote_listener';
  DBMS_OUTPUT.PUT_LINE('remote_listener                ['  || vp_1 || ']');
  select value into vp_1 from v$parameter where name='fal_client';
  DBMS_OUTPUT.PUT_LINE('FAL_CLIENT                     ['  || vp_1 || ']');
  select value into vp_1 from v$parameter where name='fal_server';
  DBMS_OUTPUT.PUT_LINE('FAL_SERVER                     ['  || vp_1 || ']');
  select value into vp_1 from v$parameter where name='db_recovery_file_dest';
  DBMS_OUTPUT.PUT_LINE('DB_RECOVERY_FILE_DEST          ['  || vp_1 || ']');
  select value into vp_1 from v$parameter where name='service_names';
  DBMS_OUTPUT.PUT_LINE('SERVICES                       ['  || vp_1 || ']');
DBMS_OUTPUT.PUT_LINE('..................................................................................'); 
END;
/

DECLARE
  vp_2    VARCHAR2(200);
BEGIN
----Parametros do Broker
  DBMS_OUTPUT.PUT_LINE('-----Parametros de config. do broker');
  select value into vp_2 from v$parameter where name='dg_broker_start';
  DBMS_OUTPUT.PUT_LINE('|-DG_BROKER_START                ['  || vp_2 || ']');
  select value into vp_2 from v$parameter where name='dg_broker_config_file1';
  DBMS_OUTPUT.PUT_LINE('|-DG_BROKER_CONFIG_FILE1         ['  || vp_2 || ']');
  select value into vp_2 from v$parameter where name='dg_broker_config_file2';
  DBMS_OUTPUT.PUT_LINE('|-DG_BROKER_CONFIG_FILE2         ['  || vp_2 || ']');
  
DBMS_OUTPUT.PUT_LINE('..................................................................................'); 
END;
/


set head off
select CHR(10) from dual;
select CHR(10) from dual;
select CHR(10) from dual;
set head on

col current_scn for 999999999999999999999999999999
col APPLIED_SCN for 999999999999999999999999999999

PROMPT 1.3-INFORMACOES DE INCARNATION E SCN

select INCARNATION# INC#, RESETLOGS_CHANGE# RS_CHANGE#, RESETLOGS_TIME Data_ResetLogs, PRIOR_RESETLOGS_CHANGE# Alter_ResetLogs, STATUS,FLASHBACK_DATABASE_ALLOWED FB_Habilitado from v$database_incarnation;

select a.DB_UNIQUE_NAME, a.SWITCHOVER_STATUS, a.CURRENT_SCN, b.DEST_ID, b.APPLIED_SCN, a.CURRENT_SCN - b.APPLIED_SCN diferenca
from (select DB_UNIQUE_NAME,SWITCHOVER_STATUS,CURRENT_SCN from v$database ) a,
(select DEST_ID, APPLIED_SCN FROM v$archive_dest WHERE TARGET='STANDBY') b
;

--exec DBMS_OUTPUT.PUT_LINE ('Obs. Diferenca de SCN (System Change Number) nao éecessáamente um problema visto que um redo que ainda nãfoi transacionado tem diversas transaçs embarcadas');

set head off
select CHR(10) from dual;
select CHR(10) from dual;
select CHR(10) from dual;
set head on

PROMPT 1.4-VERIFICACAO DE ENVIO E RECEBIMENTO DE ARCHIVES

COL DESTINATION for a15
COL STATUS FOR a15
COL ERROR for a100

select substr(DESTINATION,1,15), 
       STATUS, 
       ERROR 
FROM V$ARCHIVE_DEST 
where destination is not null;

select GROUP# STANDBY_GROUP#,THREAD#,SEQUENCE#,BYTES,USED,ARCHIVED,STATUS 
from v$standby_log order by GROUP#,THREAD#;

select GROUP# ONLINE_GROUP#,THREAD#,SEQUENCE#,BYTES,ARCHIVED,STATUS 
from v$log order by GROUP#,THREAD#;

set head off
select CHR(10) from dual;
select CHR(10) from dual;
select CHR(10) from dual;
set head on


PROMPT 3.Verificacao de eventos de erros do standby
set head off
select CHR(10) from dual;
set head on

declare 
   v_conta number(6);
begin 
    SELECT count(1) into v_conta FROM DBA_LOGSTDBY_EVENTS;
    
    if v_conta = 0 then
       DBMS_OUTPUT.PUT_LINE('Nao existem erros de aplicacao de redos nos ambientes de replica');
    end if;
end;
/
SELECT * FROM DBA_LOGSTDBY_EVENTS;


set head off
select CHR(10) from dual;
select CHR(10) from dual;
select CHR(10) from dual;
set head on

PROMPT 4.INFORMACOES DE PROCESSOS DO PRIMARY DATABASE

column client_pid format a10
select PROCESS,STATUS,CLIENT_PROCESS,CLIENT_PID,THREAD#,SEQUENCE#,BLOCK#,ACTIVE_AGENTS,KNOWN_AGENTS
from v$managed_standby  order by CLIENT_PROCESS,THREAD#,SEQUENCE#;

set head off
select CHR(10) from dual;
set head on

declare 
 v_conta number(3);
begin 
 select count(1) into v_conta
 from v$managed_standby 
 where status in ('ERROR','WAIT_FOR_LOG','WAIT_FOR_GAP','UNUSED')
 ;
 
 if v_conta<>0 then 
    DBMS_OUTPUT.PUT_LINE('[ ! ]                                 ATENCAO                                 [ ! ]');
    DBMS_OUTPUT.PUT_LINE('   Nesse ponto foi detectado erros, logs ou gaps nãencontrados.');
    DBMS_OUTPUT.PUT_LINE('   Verifique o gap e execute o troub_dataguard_replica.sql no ambiente de replica');
 end if;
end;
/



set head off
select CHR(10) from dual;
select CHR(10) from dual;
select CHR(10) from dual;
set head on


PROMPT 5. INFORMACOES GERAIS DE ERRO DO DATAGUARD
set head off
select CHR(10) from dual;
set head on

declare
    v_conta number(6);
begin

select COUNT(1) INTO v_conta from v$dataguard_status where timestamp > systimestamp-1/4
and error_code<>0;

if v_conta=0 then
   DBMS_OUTPUT.PUT_LINE('Nao existem erros no dataguard mapeados na primary');
end if;

end;
/
select TIMESTAMP,SEVERITY,ERROR_CODE,MESSAGE from v$dataguard_status where timestamp > systimestamp-1
and error_code<>0;


set head off
select CHR(10) from dual;
select CHR(10) from dual;
select CHR(10) from dual;
set head on


PROMPT 5.INFORMACOES DE GAP DE ARCHIVE ENTRE PROD E REPLICA

DECLARE 
  gap_dif NUMBER(10);
  avg_3h number(5);
  vdt varchar2(15);
  hini varchar2(3);
  hfim varchar2(3);
  num_threshold_gap number(10,10);
BEGIN

SELECT sum(cu.currentsequence - appl.lastapplied ) INTO gap_dif
FROM (
  select gvi.thread#, gvd.dest_id, MAX(gvd.log_sequence) currentsequence
  FROM gv$archive_dest gvd, gv$instance gvi
  WHERE gvd.status = 'VALID'
  AND gvi.inst_id = gvd.inst_id
  GROUP BY thread#, dest_id
) cu, (
  SELECT thread#, dest_id, MAX(sequence#) lastarchived
  FROM gv$archived_log
  WHERE resetlogs_change# = (SELECT resetlogs_change# FROM v$database)
  AND archived = 'YES'
  GROUP BY thread#, dest_id
) la, (
  SELECT thread#, dest_id, MAX(sequence#) lastapplied
  FROM gv$archived_log
  WHERE resetlogs_change# = (SELECT resetlogs_change# FROM v$database)
  AND applied = 'YES'
  AND standby_dest = 'YES'
  GROUP BY thread#, dest_id
) appl
  WHERE cu.thread# = la.thread#
  AND cu.thread# = appl.thread#
  AND cu.dest_id = la.dest_id
  AND cu.dest_id = appl.dest_id
  AND cu.dest_id = (select min(dest_id) from v$archive_dest WHERE TARGET='STANDBY')
;

select to_char(sysdate,'dd/mm/yyyy') vdt, to_char(to_number(to_char(sysdate,'hh24')-1)) hr_fim, to_char(to_number(to_char(sysdate,'hh24')-4)) hr_inicio
into vdt, hfim, hini 
from dual;


select avg(redo_gerado) into avg_3h from
(
select to_char(first_time,'hh24'), count(1) redo_gerado
from v$archived_log
where first_time between to_date(vdt || '' || hini || ':00:00','dd/mm/yyyy hh24:mi:ss')
                     and to_date(vdt || '' || hfim || ':00:00','dd/mm/yyyy hh24:mi:ss')
group by to_char(first_time,'hh24')
) ;


DBMS_OUTPUT.PUT_LINE ('Gap entre a producao e replica                        : ' || to_char(gap_dif));
DBMS_OUTPUT.PUT_LINE ('Media de geracao de archives (3hs)                    : ' || to_char(avg_3h));


--select NVL2((avg_3h/100)*15,1) into num_threshold_gap from dual;

    if gap_dif > 20 then ---> Alterar para 20 depois de testar o codigo
         if gap_dif < avg_3h+ ((avg_3h/100)*15)+1 then   --considerando +15% sobre a quantidade de redos gerados / se as 3 horas forem 0 ele considera 1
            DBMS_OUTPUT.PUT_LINE ('No momento a base possui '|| to_char(gap_dif) || ' archives de gap.');
            DBMS_OUTPUT.PUT_LINE ('Com media de geracao de ' || to_char(avg_3h) || ' archives nas ultimas 3 horas.');
            DBMS_OUTPUT.PUT_LINE ('Realize o acompanhamento sem acao até normalizacao. ');
         else
            DBMS_OUTPUT.PUT_LINE ('[!] ATENCAO [!]');
            DBMS_OUTPUT.PUT_LINE ('O gap entre o ambiente de producao e replica apresenta acima da media de geracao de redos das ultimas 3 horas + 15%.');
            DBMS_OUTPUT.PUT_LINE ('Esse ambiente deveráer verificado por um DBA.');
         end if;
    else
         DBMS_OUTPUT.PUT_LINE ('Ambiente nãapresenta gaps consideraveis.');
    end if;

end;
/


spool off
host start report_troubleshotting_Dataguard.log


clear computes  
clear BREaks
clear buffer
clear COLUMNS
