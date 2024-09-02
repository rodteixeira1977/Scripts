SET ECHO OFF
-- Script criado por Rodrigo Martins 
-- para checagem dos principais pontos a olhar no ZDLRA 
-- Deve ser executado com o usuario RASYS
-- 
-- 
-- 
-- Versao 1.0

Rem   ZERO DATALOSS RECOVERY APPLIANCE HEALTHCHECK

SET FEEDBACK OFF

CLEAR COLUMNS
CLEAR COMPUTES
CLEAR TIMING
CLEAR BREAKS

/*
SET MARKUP HTML ON
SET HEADING ON
SET PAGESIZE 2000
SET NUMWIDTH 10
SPOOL hc_zdlra.htm
*/

SET TRIMSPOOL ON
SET PAGES 2000
SET LINES 250
SET TAB OFF
SET NUMWIDTH 10
SET HEADING ON

ALTER SESSION SET TIME_ZONE = DBTIMEZONE;
alter session set nls_date_format = 'DD-MON-YYYY HH24:MI:SS';
 
PROMPT
PROMPT
PROMPT ### ZDLRA Health Check
PROMPT ### Version: 06-Mar-2024
SET SERVEROUTPUT ON

column name format a25
column value format a60
SELECT name, value FROM config WHERE name in ('_build','_recovery_appliance_state');

PROMPT
PROMPT
PROMPT ### Informacoes gerais do ZDLRA 
PROMPT ### 

col POLICY_NAME for a15
col db_unique_name for a15
col NZDL_ACTIVE for a11
col RECOVERY_WINDOW_GOAL for a30
col MAX_RETENTION_WINDOW for a30
col RECOVERY_WINDOW_SBT for a30
col LAST_OPTIMIZE for a35
col LAST_VALIDATE for a35
col LAST_METADATA_VALIDATE for a35
col LAST_CROSSCHECK for a35
col RESTORE_WINDOW for a30
col UNPROTECTED_WINDOW_THRESHOLD for a30
col UNPROTECTED_WINDOW for a30
col LAST_PURGE for a35
col MINIMUM_RECOVERY_NEEDED for a40
col AUTOTUNE_DISK_RESERVED_SPACE for a25 
col AUTOTUNE_RESERVED_SPACE for a20 
col POLICY_NAME for a20
col LAST_OPTIMIZE for a40
col LAST_VALIDATE for a40
col LAST_CROSSCHECK for a40
col RESTORE_WINDOW for a30
col NZDL_ACTIVE for a11
col RECOVERY_WINDOW_GOAL for a30
col MAX_RETENTION_WINDOW for a30
col DBNAME for a10

PROMPT ### 
PROMPT ### "TAMANHO DO BD" - The estimated size of the entire protected database (in GB).This does not refer to the space used by this database on the Recovery Appliance
PROMPT ### "D_RESERV_SPC" - The amount of disk space (in GB) reserved for the exclusive use of this database
PROMPT ### "SPC_USE" - The amount of disk space (in GB) currently used by this protected database.
PROMPT ### "RECO_WIN_SPC" - The estimated space (in GB) that is needed to meet the recovery window goal.
PROMPT ### "RECO_WIN_GOAL" - The recovery window goal for backups on disk, as specified in the protection policy.
PROMPT ### "MAX_RETENTION_WIN" - The maximum amount of time to retain disk backups. The Recovery Appliance deletes disk backups when they are older than this window. However, backups may be retained longer if deleting them would negatively affect the recovery_window_goal requirement.
PROMPT ### RESTORE_WINDOW - The time range used to compute the value of RECOVERY_WINDOW_SPACE.

select DB_UNIQUE_NAME "DBNAME",POLICY_NAME,
trunc(SIZE_ESTIMATE) "TAMANHO DO BD",
trunc(DISK_RESERVED_SPACE) "D_RESERV_SPC",
trunc(SPACE_USAGE) "SPC_USE",
trunc(RECOVERY_WINDOW_SPACE) "RECO_WIN_SPC",
extract(DAY FROM RECOVERY_WINDOW_GOAL) "RECO_WIN_GOAL",
extract(DAY FROM MAX_RETENTION_WINDOW) "MAX_RETENTION_WIN"
, RESTORE_WINDOW
from ra_database 
where state = 'ACTIVE' 
order by DB_UNIQUE_NAME;

PROMPT ### 
PROMPT ### NZDL_ACTIVE - YES if real-time redo transport is active. NO if redo has not recently been received.
PROMPT ### SPACE_USAGE - The amount of disk space (in GB) currently used by this protected database.
PROMPT ### SIZE_ESTIMATE -The estimated size of the entire protected database (in GB).This does not refer to the space used by this database on the Recovery Appliance

select DB_UNIQUE_NAME "DBNAME",STATE,DBID,POLICY_NAME,NZDL_ACTIVE,SPACE_USAGE,SIZE_ESTIMATE
from ra_database where state = 'ACTIVE' order by 2,1;

PROMPT ### 
PROMPT ### SPACE_USAGE - The amount of disk space (in GB) currently used by this protected database.
PROMPT ### DISK_RESERVED_SPACE - The amount of disk space (in GB) reserved for the exclusive use of this database
PROMPT ### AUTOTUNE_DISK_RESERVED_SPACE - YES: The Recovery Appliance will automatically set and update DISK_RESERVED_SPACE as needed.
PROMPT ### 				NO: The administrator of the Recovery Appliance must set and update the DISK_RESERVED_SPACE manually.
PROMPT ### CUMULATIVE_USAGE - The cumulative amount of disk space (in GB) allocated for all backups received for this database.
PROMPT ### SIZE_ESTIMATE -The estimated size of the entire protected database (in GB).This does not refer to the space used by this database on the Recovery Appliance
PROMPT ### RECOVERY_WINDOW_SPACE - The estimated space (in GB) that is needed to meet the recovery window goal.
PROMPT ### DEDUPLICATION_FACTOR - The ratio of the total size of virtual full backups to the actual consumed space on the appliance for this protected database.
PROMPT ### MINIMUM_RECOVERY_NEEDED - The minimum interval needed to restore any part of the protected database to the present if there are sufficient archive logs to perform the recovery.

select DB_UNIQUE_NAME "DBNAME",trunc(SPACE_USAGE) "Espaoo Usado(Gb)",trunc(DISK_RESERVED_SPACE) "Espaco Reservado(Gb)",AUTOTUNE_DISK_RESERVED_SPACE "AUTO_D_RES_SPC",AUTOTUNE_RESERVED_SPACE "AUTO_RES_SPC",trunc(CUMULATIVE_USAGE) "Uso Acumulado",trunc(SIZE_ESTIMATE) "Tamanho DB",trunc(RECOVERY_WINDOW_SPACE) "Janela de Recuperacao",DEDUPLICATION_FACTOR,MINIMUM_RECOVERY_NEEDED
from ra_database where state = 'ACTIVE' order by 2;

PROMPT ### 
PROMPT ### RECOVERY_WINDOW_GOAL - The recovery window goal for backups on disk, as specified in the protection policy.
PROMPT ### MAX_RETENTION_WINDOW - The maximum amount of time to retain disk backups. The Recovery Appliance deletes disk backups when they are older than this window. However, backups may be retained longer if deleting them would negatively affect the recovery_window_goal requirement.
PROMPT ### RECOVERY_WINDOW_SBT - The recovery window for backups on tape, as specified in the protection policy.
PROMPT ### RESTORE_WINDOW - The time range used to compute the value of RECOVERY_WINDOW_SPACE.
PROMPT ### UNPROTECTED_WINDOW_THRESHOLD - The user-specified maximum amount of data loss for protected databases that are subject to a protection policy. The Recovery Appliance generates an alert if the unprotected window of this database exceeds this value.
PROMPT ### UNPROTECTED_WINDOW - The point beyond which recovery is impossible unless additional redo is available.

select DB_UNIQUE_NAME "DBNAME",extract(DAY FROM RECOVERY_WINDOW_GOAL) "RECO_WIN_GOAL",extract(DAY FROM MAX_RETENTION_WINDOW) "MAX_RETENT_WIN",extract(DAY FROM RECOVERY_WINDOW_SBT) "RECO_WIN_SBT",RESTORE_WINDOW,UNPROTECTED_WINDOW_THRESHOLD,UNPROTECTED_WINDOW
from ra_database where state = 'ACTIVE' order by 2,1;

PROMPT ### 
PROMPT ### LAST_OPTIMIZE - The time when the most recent data placement optimization was completed.
PROMPT ### LAST_VALIDATE - The time when the most recent validation of backup data was completed.
PROMPT ### LAST_CROSSCHECK - The time when the most recent crosscheck of backup data was completed.
PROMPT ### LAST_PURGE - Time of last purge attempt for database.

select DB_UNIQUE_NAME "DBNAME",LAST_OPTIMIZE,LAST_VALIDATE,LAST_METADATA_VALIDATE,LAST_CROSSCHECK,LAST_PURGE
from ra_database where state = 'ACTIVE' order by 2,1;

PROMPT
PROMPT
PROMPT ### Status do Storage e Armazenamento do ZDLRA 
PROMPT ### 
col "DISK GROUPS" for a20
col name for a20
col  total_databases_added format 9999999999 
col  STORAGE_LOCATION format a20
col  total_space format 999999999.999 Heading "TOTAL_SPACE(GB)"
col  freespace format a20 Heading "FREESPACE(GB)[[%]]"
col  used_space format a20 Heading "USED_SPACE(GB)[[%]]"
col  total_disk_reserved_space format a20 Heading "TOT DSK RESERV SPC(GB)[[%]]"
col  freespace_goal format 999999999.999 Heading "FREESPACE_GOAL(GB)"
col  SYSTEM_PURGING_SPACE format 999999999.999 Heading "SYS_PURGE_SPACE(GB)"
col  total_recovery_window_space format a20 Heading "ESTIMATE RECO WIN SPC(GB)[[%]]"
--col  PCT_FREE for 999.9 heading "FREE SPACE(%)"
--col  PCT_USED for 999.9 heading "USED SPACE(%)"
select
  total_databases_added "TOTAL DBs",  -- Total Databases Added To ZDLRA
   trunc(total_space) "TOTAL_SPACE(GB)",  -- The maximum amount of storage (in GB) that the Recovery Appliance storage location can use for backup data.
  trunc(round(used_space,3))||' ['||round( (used_space*100/total_space) , 2)||'%]'  used_space,  -- The amount of space (in GB) currently used in the Recovery Appliance storage location. AND Used Space %
  trunc(round(ra.total_recovery_window_space,3))||' ['||round( ((total_recovery_window_space*100)/used_space), 2)||'%]' total_recovery_window_space,  -- The TOTAL/SUM of amount of estimated disk space (in GB) needed to meet Rwcovery Window Goal of ALL Databases
  trunc(round(ra.total_disk_reserved_space,3))||' ['||round( ((total_disk_reserved_space*100)/used_space), 2)||'%]' total_disk_reserved_space,  -- The TOTAL/SUM of amount of disk space (in GB) reserved for the exclusive use of ALL Databases
  trunc(round(freespace,3))||' ['||round( ((freespace*100)/total_space), 2)||'%]' freespace,   -- the amount of space (in gb) available for immediate use. AND Free Space %
  trunc(freespace_goal) "FREE_GOAL(GB)",  -- *** the expected free space requirement (in gb) based on usage history. purges may occur to meet this goal.
  system_purging_space -- the amount of space (in gb) reserved for purging operations. Must be always free.
from  ra_storage_location,
  (
  Select
  count(DB_UNIQUE_NAME) total_databases_added,
  sum(disk_reserved_space) total_disk_reserved_space,
  sum(recovery_window_space) total_recovery_window_space
      From  ra_database
  ) ra
;

PROMPT
PROMPT
PROMPT ### Status do ZDLRA
PROMPT ### Check para ver se o ZDLRA esta Bom ou Ruim.  
PROMPT ### Status Ruim quando o banco de dados não está com o backup atualizado ou se tem tarefas de index_backup falhando.

variable vsn VARCHAR2(12);
exec SELECT version INTO :vsn FROM /* not V19 */ ra_server;
COLUMN report_time FORMAT A27
COLUMN backups FORMAT A7
COLUMN version FORMAT A20
SELECT DECODE(SUM(cnt), 0, 'Bom', 'Ruim') Backups,
       :vsn version, /* not V19 */
       TO_CHAR(SYSTIMESTAMP, 'DD-MON-YYYY HH24:MI:SS TZR') report_time
  FROM (SELECT COUNT(*) cnt
        FROM (SELECT db_unique_name,
                     unprotected_window,
                     creation_time,
                     store_and_forward,
                     minimum_recovery_needed,
                     NVL(unprotected_window_threshold,
                         INTERVAL '3' DAY) unprotected_threshold,
                     MAX(high_time) htime
              FROM ra_database
              LEFT OUTER JOIN ra_disk_restore_range USING (db_key)
              WHERE deleting = 'NO'
                AND (unprotected_window_threshold <= INTERVAL '99' DAY OR
                     unprotected_window_threshold IS NULL)
              GROUP BY db_unique_name,
                       unprotected_window,
                       creation_time,
                       store_and_forward,
                       unprotected_window_threshold,
                       minimum_recovery_needed
             )
        WHERE (htime IS NULL
               OR
               unprotected_window > unprotected_threshold
               OR
               minimum_recovery_needed IS NULL
               OR
               minimum_recovery_needed > INTERVAL '3' DAY)
          AND creation_time < (SYSTIMESTAMP - 3)
          AND store_and_forward = 'NO'
          AND ROWNUM = 1
        UNION ALL
        SELECT COUNT(*) cnt
        FROM ra_task t
        JOIN rc_backup_piece p ON (p.bp_key = t.bp_key)
        JOIN rc_backup_datafile d ON (p.bs_key = d.bs_key)
        WHERE t.task_type = 'INDEX_BACKUP'
          AND t.archived = 'N'
          AND t.creation_time < SYSDATE - 3
          AND NOT EXISTS
                 (SELECT 1
                  FROM rc_backup_piece p2
                  JOIN rc_backup_datafile d2 USING (bs_key)
                  WHERE d2.dbinc_key = d.dbinc_key
                    AND d2.file# = d.file#
                    AND d2.creation_change# = d.creation_change#
                    AND d2.checkpoint_change# > d.checkpoint_change#
                    AND d2.incremental_change# <= d2.creation_change#
                    AND p2.ba_access = 'Local'
                    AND p2.vb_key IS NOT NULL
                 )
          AND ROWNUM = 1
       );

PROMPT
PROMPT
PROMPT ### 
PROMPT ###  
PROMPT ### Incidentes abertos antigos resumidos e sumarizados
col SEVERITY format a20
col "MIN(FIRST_SEEN)" format a40
col "MAX(LAST_SEEN)" format a40
col db_unique_name format a20
col severity format a20

 select ERROR_CODE, DB_UNIQUE_NAME, STATUS, SEVERITY, count(*), min(first_seen), max(last_seen) from ra_incident_log
 where status = 'ACTIVE'
 group by ERROR_CODE, DB_UNIQUE_NAME, STATUS, SEVERITY
 order by 7, 2,1;

PROMPT
PROMPT
PROMPT ### Incidents dos ultimos 5 dias detalhados
PROMPT ### Cada INCIDENT_ID precisa ser investigada fazendo query na ra_incident_log para mais detalhes.
PROMPT ###
PROMPT ### Incidents are prioritized in the following manner:
PROMPT ### FAILED tasks are generally most important.
PROMPT ### VALIDATE errors are important because they indicate problems with backups.
PROMPT ### SEVERITY is INTERNAL (most important), ERROR, WARNING (least important).
PROMPT ### INTERNAL errors belonging to COMPLETED tasks are generally not that important because the completed task indicates the necessary work
PROMPT ### has been done.
PROMPT ###

COLUMN severity FORMAT 999999999
COLUMN error_text FORMAT A100
COLUMN last_seen FORMAT A20
COLUMN creation_time FORMAT A12
COLUMN error_text FORMAT A60 WRAP
column component format a18
col state for a15 
col task_type for a20 

SET NUMF ""
SELECT incident_id,task_id severity,component,
       TO_CHAR(creation_time, 'DD-MON-YYYY') creation_time,
	   TO_CHAR(last_seen, 'DD-MON-YYYY HH24:MI:SS') last_seen,
       task_type, state,       
       (CASE
        WHEN error_code IN (-64780, -64781, -64782, -64783, -64784)
        THEN db_unique_name || ': ' ||
             SUBSTR(error_text,1,INSTR(error_text, 'ORA-06512:') - 2)
        WHEN INSTR(error_text, 'ORA-06512:') > 0
        THEN SUBSTR(error_text,1,INSTR(error_text, 'ORA-06512:') - 2)
        ELSE error_text
        END) error_text
FROM
(
 SELECT last_seen, severity, task_id, state, component, task_type, incident_id,
        creation_time, error_text, i.db_unique_name, error_code,
        CASE
          WHEN state = 'FAILED'          THEN 1
          WHEN severity = 'INTERNAL'
           AND state = 'COMPLETED'
           AND component NOT IN ('VALIDATE', 'CHECK_FILES', 'RESTORE')
                                         THEN 7
          WHEN severity = 'INTERNAL'     THEN 3
          WHEN severity = 'ERROR'        THEN 4
          WHEN severity = 'WARNING'      THEN 6
          ELSE 8
        END importance
 FROM ra_incident_log i LEFT OUTER JOIN ra_task USING (task_id)
 WHERE status = 'ACTIVE'
   AND last_seen > SYSDATE - 5
   AND error_code <> -64736
) l
ORDER BY importance, l.last_seen DESC;

PROMPT
PROMPT
PROMPT ### Incidentes referente ao Tape Library nos ultimos 3 dias 
PROMPT ###
select * from ra_incident_log where parameter = 'ROBOT0' and LAST_SEEN > sysdate - 3 order by incident_id asc;

PROMPT
PROMPT
PROMPT ### API comandos dos ultimos 5 dias
PROMPT ###
COLUMN execute_time FORMAT A20 TRUNC
COLUMN command_issued FORMAT A100 WRAP
SELECT TO_CHAR(execute_time, 'DD-MON-YY HH24:MI:SS') execute_time,
       task_name, command_issued
  FROM ra_api_history a
  WHERE execute_time > SYSDATE - 5
    AND task_name NOT IN ('INTAPI_DELETE_BACKUP_PIECE',
                          'INTAPI_KILL_TASK',
                          'API_QUEUE_SBT_BACKUP')
  ORDER BY a.execute_time DESC;

PROMPT
PROMPT
PROMPT ### Status do Tape Library
PROMPT ### Se esta parado por algum problema, se tiver abrir chamado na oracle dependendo do caso 
col lib_name for A10
col status for A10
col last_error_text for a120
select LIB_NAME,STATUS,LAST_ERROR_TEXT from ra_sbt_library;

PROMPT
PROMPT
PROMPT ### Status da execucao dos ultimos 30 dias de backups para fita  
PROMPT ###
PROMPT
col TEMPLATE_NAME format a36
col ATTRIBUTE_SET_NAME format a30
col tag format a27
col DB_UNIQUE_NAME format a15
col dbname for a10
col ATTRIBUTE_SET_NAME format a18
col RESTORE_TASK format a7
col MIN_CREATION format a19
col MAX_COMPLETION format a19
col STATE format a10
col STATUS format a6
col COUNT(*) format 99999999
col CREATE_TIME format a11
col LIB_NAME format a20

select to_char(CREATION_TIME, 'YYYY-MM-DD') CREATION_TIME,
DB_UNIQUE_NAME, TASK_TYPE, state, count(*), to_char(min(LAST_EXECUTE_TIME), 'YYYY-MM-DD HH24:MI:SS') MIN_LAST_EXECUTE_TIME, to_char(max(COMPLETION_TIME), 'YYYY-MM-DD HH24:MI:SS') COMPLETION_TIME
from ra_task where TASK_TYPE =   'BACKUP_SBT' and CREATION_TIME > sysdate-30
group by to_char(CREATION_TIME, 'YYYY-MM-DD') , DB_UNIQUE_NAME, TASK_TYPE, STATE
order by 6;

PROMPT
PROMPT
PROMPT ### Detalhes dos backups para fita dos ultimos 30 dias  
PROMPT ###
PROMPT

select to_char(CREATE_TIME, 'YYYY-MM-DD') CREATE_TIME, 
DB_UNIQUE_NAME "DBNAME", 
ATTRIBUTE_SET_NAME,
tag, 
state, 
trunc(sum(bytes)/1024/1024/1024) "Tam(Gb)",
trunc(sum(total)/1024/1024/1024) "Total(Gb)",
count(*), 
to_char(min(CREATE_TIME),'YYYY-MM-DD HH24:MI:SS') MIN_CREATION, 
to_char(max(completion_time),'YYYY-MM-DD HH24:MI:SS') MAX_COMPLETION
from ra_sbt_task
where create_time > sysdate-30
 group by to_char(CREATE_TIME, 'YYYY-MM-DD'), DB_UNIQUE_NAME, ATTRIBUTE_SET_NAME,tag,state
 order by MIN_CREATION,2;

PROMPT
PROMPT
PROMPT ### Resumo dos backups para fita 
PROMPT ###
PROMPT
col ENQUEUED_CREATION_TIME for a50
col DB_UNIQUE_NAME for a15
col BYTES_IN_QUEUE for 999999999999999
col POLICY_NAME for a15
col COMPLETION_TIME for a40
col status for a10
select b.db_unique_name "DBNAME", b.state, b.policy_name,a.ENQUEUED,a.RUNNING,a.COMPLETED,trunc(a.BYTES_IN_QUEUE/1024/1024/1024) "Em Espera(Gb)",a.COMPLETION_TIME, a.ENQUEUED_CREATION_TIME
  from RAI_EM_AGG_SBT_FLAT a, ra_database b
  where a.db_key = b.db_key order by a.COMPLETION_TIME;

PROMPT
PROMPT
PROMPT ### 
PROMPT ### Activity Page e Ultimas 24Horas para Fita 
PROMPT
col db_name for a10
col LIB_NAME for a15
col JOB_NAME for a52
col ATTRIBUTE_SET_NAME for a20
col BYTES for 999999999999999
select DB_NAME,LIB_NAME,JOB_NAME,ATTRIBUTE_SET_NAME,LIB_TYPE,COMPRESSION_ALGORITHM,trunc(BYTES/1024/1024/1024) "Tamanho Gb",trunc(TOTAL_SECONDS) "Tempo(s)", trunc(MAX_SECONDS) "Max s" from RAI_EM_SBT_ACTIVITY_PAGE;
col JOB_NAME for a52
col MAX_COMPLETION_TIME for a40
select DB_NAME,LIB_NAME,JOB_NAME,ATTRIBUTE_SET_NAME,COMPRESSION_ALGORITHM,COMPLETED,MAX_COMPLETION_TIME from RAI_EM_SBT_LAST24HOURS;
col filename for a75
col START_TIME for a35
select task_id,filename,start_time,trunc(bytes/1024/1024/1024) "Tamanho Gb",bs_key,piece# from RAI_SBT_PERFORMANCE order by START_TIME;

PROMPT
PROMPT
PROMPT ### Resumo do Jobs do ZDLRA e detalhes de jobs para fita
PROMPT ###
PROMPT
col "MIN(CREATION_TIME)" for a40
col "MAX(CREATION_TIME)" for a40
col STATE for a22
col DB_UNIQUE_NAME for a10
col TASK_TYPE for a25
col CREATION_TIME for a50
col dbname for a10 

select db_unique_name "DBNAME",task_type,state, COUNT(*), MIN(creation_time), MAX(creation_time)
    from ra_task
    where archived='N'
    group by db_unique_name,task_type, state
    order by db_unique_name,6 ;
	
col STATE for a15
col TASK_TYPE for a15
col "MIN(CREATION_TIME)" for a35
col "MAX(CREATION_TIME)" for a35
select db_unique_name,state, priority, task_type, count(*), MIN(creation_time), MAX(creation_time) 
from ra_task 
where archived = 'N' 
and task_type='BACKUP_SBT' 
group by db_unique_name,state, priority, task_type 
order by db_unique_name,state;	

PROMPT
PROMPT
PROMPT ### 
PROMPT ### Backups concluidos com sucesso nos ultimos 60 dias 
PROMPT
col KEEPBKP_TAG for a40
col DB_UNIQUE_NAME for a15
select a.DB_UNIQUE_NAME,b.DB_KEY,b.LOW_TIME,b.HIGH_TIME,b.KEEP_OPTIONS,b.KEEP_UNTIL,b.KEEPBKP_TAG 
from ra_database a, RA_SBT_RESTORE_RANGE b 
where a.db_key = b.db_key 
and b.LOW_TIME > sysdate - 60
order by b.LOW_TIME asc, a.DB_UNIQUE_NAME ;

PROMPT
PROMPT
PROMPT ### 
PROMPT ### Informacoes dos ultimos 2 dias de backups incrementais dos bancos para disco do ZDLRA 
PROMPT
col OUTPUT_BYTES_DISPLAY for a10
col OUTPUT_BYTES_PER_SEC_DISPLAY for a10
col TIME_TAKEN_DISPLAY for a10
col STATUS for a25
col START_TIME for a25

select DB_NAME,START_TIME,END_TIME,STATUS,INPUT_TYPE,COMPRESSION_RATIO,OUTPUT_BYTES_DISPLAY,OUTPUT_BYTES_PER_SEC_DISPLAY,TIME_TAKEN_DISPLAY 
from rc_rman_backup_job_details 
where input_type<>'ARCHIVELOG' and START_TIME > sysdate - 2
ORDER BY START_TIME;

PROMPT
PROMPT
PROMPT ### 
PROMPT ### Ultimos backups incrementais e archives dos bancos para disco do ZDLRA 
PROMPT
col name for a10 
select DB NAME,dbid,NVL(TO_CHAR(max(backuptype_db),'DD/MM/YYYY HH24:MI'),'01/01/0001:00:00') DBBKP,
NVL(TO_CHAR(max(backuptype_arch),'DD/MM/YYYY HH24:MI'),'01/01/0001:00:00') ARCBKP
from (
select a.name DB,dbid,
decode(b.bck_type,'D',max(b.completion_time),'I', max(b.completion_time)) BACKUPTYPE_db,
decode(b.bck_type,'L',max(b.completion_time)) BACKUPTYPE_arch
from rc_database a,bs b
where a.db_key=b.db_key
and b.bck_type is not null
and b.bs_key not in(Select bs_key from rc_backup_controlfile where AUTOBACKUP_DATE
is not null or AUTOBACKUP_SEQUENCE is not null)
and b.bs_key not in(select bs_key from rc_backup_spfile)
group by a.name,dbid,b.bck_type
) group by db,dbid
ORDER BY least(to_date(DBBKP,'DD/MM/YYYY HH24:MI'),to_date(ARCBKP,'DD/MM/YYYY HH24:MI'))
/


PROMPT
PROMPT
PROMPT ### Ultimo Validate por banco de dados
PROMPT ### olhar os bancos com as datas mais antigas (acima de 30 dias). Abrir chamado Oracle
PROMPT
select DB_UNIQUE_NAME,state,LAST_VALIDATE from ra_database where state = 'ACTIVE' order by 3;

PROMPT
PROMPT
PROMPT ### Ultimo Optimize por banco de dados 
PROMPT ### olhar os bancos com as datas mais antigas (acima de 30 dias). Abrir chamado Oracle 
PROMPT
select DB_UNIQUE_NAME,state,LAST_OPTIMIZE from ra_database where state = 'ACTIVE' order by 3;

PROMPT
PROMPT
PROMPT ### Ultimo Crosscheck por banco de dados 
PROMPT ### olhar os bancos com as datas mais antigas (acima de 30 dias). Abrir chamado Oracle 
PROMPT
select DB_UNIQUE_NAME,state,LAST_CROSSCHECK from ra_database where state = 'ACTIVE' order by 3;

PROMPT
PROMPT
PROMPT ### Ultimo Purge por banco de dados 
PROMPT ### olhar os bancos com as datas mais antigas (acima de 30 dias). Abrir chamado Oracle 
PROMPT
select DB_UNIQUE_NAME,state,LAST_PURGE from ra_database where state = 'ACTIVE' order by 3;

PROMPT
PROMPT
PROMPT ### Count de jobs para fita por dia  
PROMPT ###  
PROMPT
col completion_time for a20

select task_type, to_char(completion_time,'YYYY-MM-DD') completion_time, count(*) 
from ra_task 
where archived = 'Y' 
and completion_time > sysdate - 30
and task_type like '%BACKUP_SBT' 
group by task_type, to_char(completion_time,'YYYY-MM-DD')  
order by 1,2;


PROMPT
PROMPT
PROMPT ### 
PROMPT ### Jobs Pending - Abrir Chamado 
PROMPT
 select DB_UNIQUE_NAME,REQUEST_TIME,APPROVAL_TIME,CHANNELS_REQD,LAST_PING_TIME from RAI_PENDING_JOBS
 
PROMPT
PROMPT
PROMPT ### 
PROMPT ### Detalhes dos backups dos Databases Protected  
PROMPT 

SET SERVEROUTPUT ON
SET LINES 260 TRIMS ON
SET TIMING ON
SET FEEDBACK OFF

DECLARE
  -- Set mask to TRUE to mask the DBID, NAME, and DB_UNIQUE_NAME from the output.
  mask                          CONSTANT BOOLEAN := FALSE;

  -- Set mask_db_key to TRUE to mask the DB_KEY.
  -- Note: The DB_KEY has no meaning outside the RMAN catalog.
  -- Without the RMAN catalog data, it cannot be used to identify a database name or dbid.
  -- It can be useful to have he DB_KEY in the output to allow for discussion on specific databases.
  -- The customer can map it to a database name by querying the RMAN catalog (RC_DATABASE).
  mask_db_key                   CONSTANT BOOLEAN := FALSE;

  -- Set include_standby to TRUE to include standby databases in the output.
  -- Typically, only set to TRUE if ONLY the standby databases will be replicated to a remote ZDLRA.
  -- include_standby will automatically be set to FALSE for catalog versions prior to 11g to avoid ORA-00942 errors.
  include_standby               BOOLEAN := FALSE;

  -- Set backup_age_limit to the number of days back to consider backups. Any database not backed up since the backup_age_limit will not be included in the output.
  -- Not usually modified.
  backup_age_limit              CONSTANT NUMBER := 30;

  -- Set compression_ratio to the RMAN compression ratio for compressed backupsets.
  -- Not usually modified, unless the customer knows the compression ratio is different.
  compression_ratio             CONSTANT NUMBER := 3;

  --
  -- DO NOT EDIT BELOW THIS LINE
  --
  TYPE cv_typ IS REF CURSOR;
  TYPE database_typ IS RECORD (db_key         VARCHAR2(10),
                               dbid           VARCHAR2(12),
                               name           VARCHAR2(8),
                               db_unique_name VARCHAR2(10),
                               database_role  VARCHAR2(7));

  script_version                CONSTANT VARCHAR2(30) := '3.0 - 01-MAY-2017';
  cv                            cv_typ;
  d                             database_typ;
  db_size_bytes                 NUMBER;
  db_full_backup_bytes          NUMBER;
  cf_total_bytes                NUMBER;
  full_backup_bytes             NUMBER;
  full_backupset_bytes          NUMBER;
  incr_history_days             NUMBER;
  incr_backup_bytes_per_day     NUMBER;
  incr_backup_pct               NUMBER;
  redo_bytes_per_day            NUMBER;
  redo_pct                      NUMBER;
  recovery_window_days          NUMBER;
  incr_days                     NUMBER;
  arch_days                     NUMBER;
  db_exclude_cnt                NUMBER := 0;
  db_include_cnt                NUMBER := 0;
  incr_begin_date               DATE;
  incr_end_date                 DATE;
  min_completion_time           DATE;
  max_completion_time           DATE;
  full_last_completion_time     DATE;
  incr_last_completion_time     DATE;
  arch_last_completion_time     DATE;
  max_last_completion_time      DATE;
  begin_time                    DATE;
  cat_dbname                    VARCHAR2(30);
  cat_host                      VARCHAR2(30);
  cat_schema                    VARCHAR2(30);
  cat_version                                   VARCHAR2(30);
  cat_major_version                             NUMBER;
  pieces                        NUMBER;
  include_db                    VARCHAR2(5);

  db_size_bytes_out             VARCHAR2(20);
  full_backup_bytes_out         VARCHAR2(20);
  full_backupset_bytes_out      VARCHAR2(20);
  incr_backup_bytes_per_day_out VARCHAR2(20);
  incr_backup_pct_out           VARCHAR2(20);
  redo_bytes_per_day_out        VARCHAR2(20);
  redo_pct_out                  VARCHAR2(20);
  recovery_window_days_out      VARCHAR2(20);
  full_last_completion_time_out VARCHAR2(20);
  incr_last_completion_time_out VARCHAR2(20);
  arch_last_completion_time_out VARCHAR2(20);
  incr_days_out                 VARCHAR2(20);
  arch_days_out                 VARCHAR2(20);
  method_out                    VARCHAR2(9);

  c_include_standby             VARCHAR2(1000) := 'SELECT TO_CHAR(rd.db_key) AS db_key,
                                                          TO_CHAR(rd.dbid) AS dbid,
                                                          rd.name AS name,
                                                          NVL(rs.db_unique_name,rd.name) AS db_unique_name,
                                                          rs.database_role AS database_role
                                                     FROM
                                                          rc_database rd,
                                                          rc_site rs
                                                    WHERE rd.db_key = rs.db_key
                                                   ORDER BY rs.database_role,
                                                            rd.name,
                                                            rs.db_unique_name,
                                                            dbid';

  c_exclude_standby             VARCHAR2(1000) := 'SELECT TO_CHAR(rd.db_key) AS db_key,
                                                          TO_CHAR(rd.dbid) AS dbid,
                                                          rd.name AS name,
                                                          rd.name AS db_unique_name,
                                                          ''PRIMARY'' AS database_role
                                                     FROM
                                                          rc_database rd
                                                  ORDER BY rd.name,
                                                           dbid';

BEGIN
  -- Record the begin time
  begin_time := SYSDATE;

  -- Record catalog information
 SELECT sys_context('userenv','db_name'),
        sys_context('userenv', 'server_host'),
        sys_context ('userenv', 'session_user')
   INTO cat_dbname,
        cat_host,
        cat_schema
   FROM dual;

  -- Get the catalog version
  SELECT MAX(version)
    INTO cat_version
        FROM rcver;

  cat_major_version := TO_NUMBER(SUBSTR(cat_version,1,INSTR(cat_version,'.') - 1));

  -- Write out the report header
  dbms_output.put_line('********* Start of ZDLRA Client Sizing Metrics - Catalog (3.x) ****************');
  dbms_output.put_line(RPAD('-',242,'-'));
  dbms_output.put_line(RPAD('|Include',8)||'|'||
                       RPAD('DBID',12)||'|'||
                       RPAD('DBName',8)||'|'||
                       RPAD('DBRole',7)||'|'||
                       LPAD('DB Size GB',11)||'|'||
                       LPAD('Full GB',11)||'|'||
                       RPAD('Method',9)||'|'||
                       LPAD('Incr GB/Day',11)||'|'||
                       LPAD('Incr Pct/Day',6)||'|'||
                       LPAD('Redo GB/Day',11)||'|'||
                       LPAD('Redo Pct/Day',6)||'|'||
                       LPAD('Rcvry Window',5)||'|'||
                       LPAD('Last Full',11)||'|'||
                       LPAD('Last Incr',11)||'|'||
                       LPAD('Last Arch',11)||'|'||
                       LPAD('Incr Days',8)||'|'||
                       LPAD('Arch Days',8)||'|');
  dbms_output.put_line(RPAD('-',242,'-'));

  --If the catalog version is less than 11g, then include_standby must be set to false
  --to avoid ORA-00942
  IF cat_major_version < 11 THEN
    include_standby := FALSE;
  END IF;

  --Gather protected database information
  IF include_standby THEN
    OPEN cv FOR c_include_standby;
  ELSE
    OPEN cv FOR c_exclude_standby;
  END IF;
  LOOP
    FETCH cv INTO d;
    EXIT WHEN cv%NOTFOUND;

    -- Initialize all variables to null
    db_full_backup_bytes := '';
    db_size_bytes := '';
    cf_total_bytes := '';
    full_backup_bytes := '';
    full_backupset_bytes :='';
    pieces := '';
    incr_history_days := '';
    incr_backup_bytes_per_day := '';
    incr_backup_pct := '';
    redo_bytes_per_day := '';
    redo_pct := '';
    recovery_window_days := '';
    incr_begin_date := '';
    incr_end_date := '';
    full_last_completion_time := '';
    incr_last_completion_time := '';
    arch_last_completion_time := '';
    max_last_completion_time := '';
    incr_days := '';
    arch_days := '';
    method_out := 'BDF';

    -- Get the latest full backup size, based on actual blocks written per datafile to the backup;
    -- not the size of the datafile itself. This method does not count empty blocks that have never
    -- contained data.
    SELECT SUM(rbd.blocks * rbd.block_size),
           SUM(rbd.datafile_blocks * rbd.block_size),
           MAX(pieces),
           MAX(rbd.completion_time)
      INTO db_full_backup_bytes,
           db_size_bytes,
           pieces,
           full_last_completion_time
      FROM rc_backup_datafile rbd,
           (SELECT file#,
                   MAX(completion_time) completion_time
              FROM rc_backup_datafile
             WHERE db_key = d.db_key
               AND (incremental_level = 0 OR incremental_level IS NULL)
             GROUP BY file#) mct
     WHERE db_key = d.db_key
       AND rbd.file# = mct.file#
       AND rbd.completion_time = mct.completion_time
       AND (rbd.incremental_level = 0 OR rbd.incremental_level IS NULL);

        -- The blocks column in rc_backup_datafile is not reliable for multi-piece backups. So, use the backupset size.
        -- If the backupset is compressed, use a standard compression ratio to report an estimated uncompressed size.

        IF pieces > 1 THEN
          SELECT SUM(bytes * TO_NUMBER(DECODE(compressed,'YES',compression_ratio,'NO','1','1'))),
                 DECODE(MAX(compressed),'YES','COMP BSET','NO','BSET','BSET')
            INTO db_full_backup_bytes,
                 method_out
            FROM rc_backup_piece
           WHERE bs_key IN (SELECT bs_key
                              FROM rc_backup_datafile rbd,
                               (SELECT file#,
                                       MAX(completion_time) completion_time
                                  FROM rc_backup_datafile
                                 WHERE db_key = d.db_key
                                   AND (incremental_level = 0 OR incremental_level IS NULL)
                                GROUP BY file#) mct
                         WHERE db_key = d.db_key
                           AND rbd.file# = mct.file#
                           AND rbd.completion_time = mct.completion_time
                           AND (rbd.incremental_level = 0 OR rbd.incremental_level IS NULL));
        END IF;

  -- The backup size cannot be greater than the database size. If it is, the compression ratio must be wrong. So limit the full backup size to the database size
  IF db_full_backup_bytes > db_size_bytes OR db_full_backup_bytes = 0 THEN
    db_full_backup_bytes := db_size_bytes;
  END IF;

    -- Track last completion of any type of backup for excluding old backups from the report.
    max_last_completion_time := full_last_completion_time;

    -- Get the size of the controlfile backup.
    SELECT MAX(blocks * block_size)
      INTO cf_total_bytes
      FROM rc_backup_controlfile
     WHERE db_key = d.db_key;

    -- Add the size of the latest full backup and controlfile backup
    full_backup_bytes := db_full_backup_bytes + cf_total_bytes;

    -- Get the average daily size of the incremental backups.
     SELECT SUM(avg_incr_bytes),
            MAX(max_completion_time),
            ROUND(MAX(incr_days),0)
       INTO incr_backup_bytes_per_day,
            incr_last_completion_time,
            incr_days
       FROM (SELECT file#,
                    SUM(incr_bytes) / GREATEST(SUM(incr_days),1) AS avg_incr_bytes,
                    MAX(completion_time) AS max_completion_time,
                    SUM(incr_days) AS incr_days
               FROM (SELECT rbd.file#,
                            SUM(blocks * block_size) AS incr_bytes,
                            MAX(rbd.completion_time) AS completion_time,
                            MAX(rbd.completion_time) - fct.last_full_time AS incr_days
                       FROM rc_backup_datafile rbd,
                            (SELECT file#,
                                    db_key,
                                    completion_time AS last_full_time,
                                    LEAD(rbd.completion_time, 1, SYSDATE) OVER (PARTITION BY rbd.file# ORDER BY rbd.completion_time) AS next_full_time
                               FROM rc_backup_datafile rbd
                              WHERE db_key = d.db_key
                                AND (incremental_level = 0 OR incremental_level IS NULL)
                                AND rbd.completion_time >= SYSDATE - backup_age_limit) fct
                      WHERE rbd.db_key = fct.db_key
                        AND rbd.file# = fct.file#
                        AND rbd.incremental_level = 1
                        AND rbd.completion_time BETWEEN fct.last_full_time AND fct.next_full_time
                     GROUP BY rbd.file#,
                              fct.last_full_time,
                              fct.next_full_time)
             GROUP BY file#)
;
    -- Track last completion of any type of backup for excluding old backups from the report.
    IF incr_last_completion_time > max_last_completion_time THEN
      max_last_completion_time := incr_last_completion_time;
    END IF;

    -- Get the average daily redo generation
    SELECT SUM(blocks * block_size) / GREATEST(MAX(next_time) - MIN(first_time),1),
           MAX(next_time),
           ROUND(GREATEST(MAX(next_time) - MIN(first_time),1),0)
      INTO redo_bytes_per_day,
           arch_last_completion_time,
           arch_days
      FROM rc_backup_redolog
     WHERE db_key = d.db_key
       AND first_time >= SYSDATE - backup_age_limit;

    -- Track last completion of any type of backup for excluding old backups from the report.
    IF arch_last_completion_time > max_last_completion_time THEN
      max_last_completion_time := arch_last_completion_time;
    END IF;

    -- Get the recovery window
    SELECT MAX(TO_NUMBER(REGEXP_SUBSTR(value, '([[:digit:]]+)', 1, 1)))
      INTO recovery_window_days
      FROM rc_rman_configuration
     WHERE db_key = d.db_key
       AND  name = 'RETENTION POLICY';

    -- Use the redo generation for incremental, if incrementals are not being run
    IF incr_backup_bytes_per_day IS NULL THEN
      incr_backup_bytes_per_day := redo_bytes_per_day;
    END IF;

    -- Calculate the incremental change percentage
    IF incr_backup_bytes_per_day IS NOT NULL THEN
      incr_backup_pct := ROUND(incr_backup_bytes_per_day / full_backup_bytes * 100,2);
    END IF;

    -- Calculate the redo percentage
    IF redo_bytes_per_day IS NOT NULL THEN
      redo_pct := ROUND(redo_bytes_per_day / full_backup_bytes * 100,2);
    END IF;

    -- Convert all bytes to GB
    IF db_size_bytes IS NOT NULL THEN
      db_size_bytes := ROUND(db_size_bytes/POWER(1024,3),3);
    END IF;

    IF full_backup_bytes IS NOT NULL THEN
      full_backup_bytes := ROUND(full_backup_bytes/POWER(1024,3),3);
    END IF;

          IF full_backupset_bytes IS NOT NULL THEN
      full_backupset_bytes := ROUND(full_backupset_bytes/POWER(1024,3),3);
    END IF;

    IF incr_backup_bytes_per_day IS NOT NULL THEN
      incr_backup_bytes_per_day := ROUND(incr_backup_bytes_per_day/POWER(1024,3),3);
    END IF;

    IF redo_bytes_per_day IS NOT NULL THEN
      redo_bytes_per_day := ROUND(redo_bytes_per_day/POWER(1024,3),3);
    END IF;

    -- Convert values to character for output, ensuring null values are handled for reporting purposes
    IF db_size_bytes IS NOT NULL THEN
      db_size_bytes_out := TO_CHAR(db_size_bytes);
    ELSE
      db_size_bytes_out := '*';
    END IF;

    IF full_backup_bytes IS NOT NULL THEN
      full_backup_bytes_out := TO_CHAR(full_backup_bytes);
    ELSE
      full_backup_bytes_out := '*';
    END IF;

        IF full_backupset_bytes IS NOT NULL THEN
      full_backupset_bytes_out := TO_CHAR(full_backupset_bytes);
    ELSE
      full_backupset_bytes_out := '*';
    END IF;

    IF incr_backup_bytes_per_day IS NOT NULL THEN
      incr_backup_bytes_per_day_out := TO_CHAR(incr_backup_bytes_per_day);
    ELSE
      incr_backup_bytes_per_day_out := '*';
    END IF;

    IF incr_backup_pct IS NOT NULL THEN
      incr_backup_pct_out := TO_CHAR(incr_backup_pct);
    ELSE
      incr_backup_pct_out := '*';
    END IF;

    IF recovery_window_days IS NOT NULL THEN
      recovery_window_days_out := TO_CHAR(recovery_window_days);
    ELSE
      recovery_window_days_out := '*';
    END IF;

    IF redo_bytes_per_day IS NOT NULL THEN
      redo_bytes_per_day_out := TO_CHAR(redo_bytes_per_day);
    ELSE
      redo_bytes_per_day_out := '*';
    END IF;

    IF redo_pct IS NOT NULL THEN
      redo_pct_out := TO_CHAR(redo_pct);
    ELSE
      redo_pct_out := '*';
    END IF;

    IF full_last_completion_time IS NOT NULL THEN
      full_last_completion_time_out := TO_CHAR(full_last_completion_time,'DD-MON-YYYY');
    ELSE
      full_last_completion_time_out := '*';
    END IF;

    IF incr_last_completion_time IS NOT NULL THEN
      incr_last_completion_time_out := TO_CHAR(incr_last_completion_time,'DD-MON-YYYY');
    ELSE
      incr_last_completion_time_out := '*';
    END IF;

    IF arch_last_completion_time IS NOT NULL THEN
      arch_last_completion_time_out := TO_CHAR(arch_last_completion_time,'DD-MON-YYYY');
    ELSE
      arch_last_completion_time_out := '*';
    END IF;

    IF arch_days IS NOT NULL THEN
      arch_days_out := TO_CHAR(arch_days);
    ELSE
      arch_days_out := '*';
    END IF;

    IF incr_days IS NOT NULL THEN
      incr_days_out := TO_CHAR(incr_days);
    ELSE
      incr_days_out := '*';
    END IF;

    -- Mask DBID, NAME, and DB_UNIQUE_NAME, if mask is set to TRUE
    IF mask THEN
      d.dbid := '########';
      d.name := '########';
      d.db_unique_name := '########';
    END IF;

        -- Mask DB_KEY, if mask_db_key is set to TRUE
    IF mask_db_key THEN
      d.db_key := '########';
    END IF;

        -- Include or exclude the database from the sizing based on age of last backup.
        IF max_last_completion_time >= SYSDATE - backup_age_limit THEN
          include_db := 'YES';
          db_include_cnt := db_include_cnt + 1;
        ELSE
          include_db := 'NO';
          db_exclude_cnt := db_exclude_cnt + 1;
        END IF;

    -- Output the data
    dbms_output.put_line('|'||
                             RPAD(include_db,7)||'|'||
                             RPAD(d.dbid,12)||'|'||
                         RPAD(d.name,8)||'|'||
                         RPAD(d.database_role,7)||'|'||
                         LPAD(db_size_bytes_out,11)||'|'||
                         LPAD(full_backup_bytes_out,11)||'|'||
                         RPAD(method_out,9)||'|'||
                         LPAD(incr_backup_bytes_per_day_out,11)||'|'||
                         LPAD(incr_backup_pct_out,8)||'|'||
                         LPAD(redo_bytes_per_day_out,11)||'|'||
                         LPAD(redo_pct_out,8)||'|'||
                         LPAD(recovery_window_days_out,5)||'|'||
                         LPAD(full_last_completion_time_out,11)||'|'||
                         LPAD(incr_last_completion_time_out,11)||'|'||
                         LPAD(arch_last_completion_time_out,11)||'|'||
                         LPAD(incr_days_out,9)||'|'||
                         LPAD(arch_days_out,9)||'|');
  END LOOP;
  dbms_output.put_line(RPAD('-',242,'-'));
  dbms_output.put_line('********* End of ZDLRA Client Sizing Metrics ****************');
  dbms_output.put_line('Catalog schema        : '||cat_schema);
  dbms_output.put_line('Catalog database      : '||cat_dbname);
  dbms_output.put_line('Catalog host          : '||cat_host);
  dbms_output.put_line('Catalog version       : '||cat_version);
  dbms_output.put_line('Begin time            : '||TO_CHAR(begin_time,'DD-MON-YYYY HH24:MI:SS'));
  dbms_output.put_line('End time              : '||TO_CHAR(SYSDATE,'DD-MON-YYYY HH24:MI:SS'));
  dbms_output.put_line('Databases incldued    : '||db_include_cnt);
  dbms_output.put_line('Databases excluded    : '||db_exclude_cnt||' (No backups in past '||backup_age_limit||' days.)');
  dbms_output.put_line('Script version        : '||script_version);
END;
/
