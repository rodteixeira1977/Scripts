/**********************************************************************************************************************************
* Author        : Oracle High Availability Systems Development, Server Technologies - Oracle Corporation
* Version       : 4.1
* DATE          : 02-NOV-2023
* Purpose       : Script to gather information from a client database that will be used to estimate the ZDLRA.
*                 resources that are required to service this database.
***********************************************************************************************************************************
*  Disclaimer:
*  -----------
*  Although this program has been tested and used successfully, it is not supported by Oracle Support Services.
*  It has been tested internally, however, and works as documented. We do not guarantee that it will work for you,
*  so be sure to test it in your environment before relying on it.  We do not clam any responsibility for any problems
*  and/or damage caused by this program.  This program comes "as is" and any use of this program is at your own risk!!
*  Proofread this script before using it! Due to the differences in the way text editors, e-mail packages and operating systems
*  handle text formatting (spaces, tabs and carriage returns).
***********************************************************************************************************************************
*  Usage:
*  ------
*  To execute this script, please follow the steps below:
*    1)- Copy this script to the desired location.
*    2)- Execute the script at the SQL prompt (SQL> @zdlra-client-metrics_cf.sql) as a privileged user.
*    3)- Please provide the script output to the Oracle resource assisting you with ZDLRA sizing.
*
*    This script needs to run individually on each database that you are planning to configure with ZDLRA.
*
*   ** IMPORTANT ** For container databases (CDB), only run this script once in the container database itself.
*                   DO NOT run it in each Pluggabe Database (PDB).
*
***********************************************************************************************************************************/

COLUMN db_name NEW_VALUE mydb_name
SELECT SYS_CONTEXT('USERENV', 'DB_NAME') AS db_name 
  FROM dual;

SPOOL &mydb_name._zdlra_client_metrics_cf.lst
 
SET LINES 150 TRIMS ON
SET FEEDBACK OFF
SET PAGES 0
SET SERVEROUTPUT ON
DECLARE
  is_pdb_error                  EXCEPTION; 
  TYPE cv_typ IS REF CURSOR;
  cv                            cv_typ;
  db_total_bytes                NUMBER;
  cf_bytes                      NUMBER;
  db_free_bytes                 NUMBER;
  db_incr_history_days          NUMBER;
  db_incr_backup_bytes_per_day  NUMBER;
  db_incr_backup_pct            NUMBER;
  protdb_recovery_window_days   NUMBER;
  redo_backup_bytes_per_day     NUMBER;
  redo_backup_bytes_pct         NUMBER;
  online_redo_bytes             NUMBER;
  db_total_blocks               NUMBER;
  db_free_blocks                NUMBER;
  db_dbid                       NUMBER;
  protdb_name                   VARCHAR2(30);
  protdb_unique_name            VARCHAR2(30);
  inst_cnt                      NUMBER;
  df_cnt                        NUMBER;
  largest_df_bytes              NUMBER;
  backup_rate                   NUMBER;
  last_full_backup              DATE;
  last_incr_backup              DATE;
  last_arch_backup              DATE;
  n                             NUMBER;

  c_pdb_check                  VARCHAR2(1000) := 'SELECT COUNT(*) FROM v$database WHERE dbid = con_dbid';

  c_pdb_count                  VARCHAR2(1000) := 'SELECT COUNT(*) FROM v$pdbs';

  c_cdb_data_file              VARCHAR2(1000) := 'SELECT SUM(bytes), MAX(bytes), COUNT(*) FROM CDB_DATA_FILES';
                                        
  c_data_file                  VARCHAR2(1000) := 'SELECT SUM(bytes), MAX(bytes), COUNT(*) FROM DBA_DATA_FILES';
                                    
  c_cdb_free_space             VARCHAR2(1000) := 'SELECT SUM(bytes), SUM(blocks) FROM cdb_free_space';

  c_free_space                 VARCHAR2(1000) := 'SELECT SUM(bytes), SUM(blocks) FROM dba_free_space';                                                 

  FUNCTION is_cdb RETURN BOOLEAN IS
    TYPE cv_typ IS REF CURSOR;
    cv                            cv_typ;
    n VARCHAR2(3);
    c_cdb                        VARCHAR2(1000) := 'SELECT cdb FROM v$database';
  BEGIN
    SELECT 'x'
      INTO n 
      FROM dba_views
     WHERE view_name = 'CDB_DATA_FILES';
     
     OPEN cv FOR c_cdb;
     FETCH cv INTO n;
     CLOSE cv;
       
    IF n = 'NO' THEN
      RETURN FALSE;
    END IF;
     
    RETURN TRUE;    
  EXCEPTION
    WHEN OTHERS THEN
      RETURN FALSE;
  END is_cdb;

  PROCEDURE Pv(n IN VARCHAR2, v IN NUMBER) IS
  BEGIN
    dbms_output.Put_line(n || '=' || v);
  END;

BEGIN
  --Gather protected database information
  SELECT name
    INTO protdb_name
    FROM v$database;

  SELECT value 
    INTO protdb_unique_name
    FROM v$parameter
   WHERE name = 'db_unique_name';

  -- Get the total size of the datafiles    
  IF is_cdb THEN
    -- Validate this is the CDB and not a PDB within the CDB
    OPEN cv FOR c_pdb_check;
    FETCH cv INTO n;
    CLOSE cv;
     
    IF n= 0 THEN
      RAISE is_pdb_error;
    END IF;

    -- Get the count of PDB's in the CDB
    -- Not using for now...
    -- OPEN cv FOR c_pdb_count;
    -- FETCH cv INTO n;
    -- CLOSE cv;

    -- protdb_name := protdb_name||' (CDB/'||n||' PDBs)';
    OPEN cv FOR c_cdb_data_file;
  ELSE
    OPEN cv FOR c_data_file;
  END IF;
  
  FETCH cv INTO db_total_bytes, largest_df_bytes, df_cnt;
  CLOSE cv;

  -- Get the total free space
  IF is_cdb THEN
    OPEN cv FOR c_cdb_free_space;
  ELSE
    OPEN cv FOR c_free_space;
  END IF;

  FETCH cv INTO db_free_bytes, db_free_blocks;
  CLOSE cv;

  -- Get the dbid
  SELECT dbid
    INTO db_dbid
    FROM v$database;

  -- Get the controlfile size
  SELECT SUM(block_size * file_size_blks)
    INTO cf_bytes
    FROM v$controlfile
   WHERE status IS NULL;

  -- Get the daily incremental backup size
  BEGIN
    SELECT TRUNC(SUM(block_size * blocks) /
                 (MAX(TRUNC(completion_time)) - MIN(TRUNC(completion_time))))
      INTO db_incr_backup_bytes_per_day
      FROM v$backup_datafile
     WHERE incremental_level = 1;
  EXCEPTION
    WHEN ZERO_DIVIDE THEN
	  db_incr_backup_bytes_per_day := NULL;
  END;

  -- Get the recovery window
  SELECT MIN(TO_NUMBER(REGEXP_SUBSTR(value, '([[:digit:]]+)', 1, 1))) 
    INTO protdb_recovery_window_days
    FROM v$rman_configuration
   WHERE name = 'RETENTION POLICY';
   
 -- Get the daily redo size
  SELECT NVL(TRUNC(AVG(day_redo_size)),0)
    INTO redo_backup_bytes_per_day
    FROM (SELECT day_finished, SUM(block_size * blocks) day_redo_size
            FROM (SELECT Max(block_size) block_size,
                         Max(blocks) blocks,
                         Max(Trunc(completion_time)) day_finished
                    FROM V$ARCHIVED_LOG al
                   GROUP BY thread#, sequence#)
           GROUP BY day_finished);

  -- Use the daily redo size for the daily incremental size, if no incrementals
  IF db_incr_backup_bytes_per_day IS NULL THEN
    db_incr_backup_bytes_per_day := redo_backup_bytes_per_day;
  END IF;

  -- Get the number of instances
  SELECT COUNT(*) 
    INTO inst_cnt
    FROM gv$instance;

  -- Get the backup rate (GB/HR)
  SELECT ROUND(MEDIAN(mbytes_processed / 1024 / (end_time - start_time) / 24) , 0)
    INTO backup_rate
    FROM v$rman_status
   WHERE operation = 'BACKUP'
     AND status = 'COMPLETED'
     AND mbytes_processed > 0
     AND (end_time - start_time) * 1440 >= 5;

  -- Get the last backup dates
  SELECT MAX(completion_time)
    INTO last_full_backup
    FROM v$backup_datafile
   WHERE file# > 0
     AND (incremental_level = 0 
          OR
          incremental_level IS NULL);

  SELECT MAX(completion_time)
    INTO last_incr_backup
    FROM v$backup_datafile
   WHERE file# > 0
     AND incremental_level = 1;

  SELECT MAX(end_time)
    INTO last_arch_backup
    FROM v$rman_backup_job_details
   WHERE input_type = 'ARCHIVELOG';

  -- Output protected database information
  dbms_output.Put_line('********** Start of ZDLRA Client Sizing Metrics (4.x) **********');

  Pv(RPAD('* Database dbid',40), db_dbid);

  dbms_output.Put_line(RPAD('* Protected Database Name',40)||'='||protdb_name);

  dbms_output.Put_line(RPAD('* Protected Database Unique Name',40)||'='||protdb_unique_name);

  Pv(RPAD('* Database Size (GB)',40), ROUND(db_total_bytes/POWER(1024,3),6));

  Pv(RPAD('* Full Backup Size (GB)',40), ROUND((db_total_bytes + cf_bytes - db_free_bytes)/POWER(1024,3),6));

  Pv(RPAD('* Incremental Backup Size (GB)',40), ROUND((db_incr_backup_bytes_per_day)/POWER(1024,3),6));

  Pv(RPAD('* Incremental Backup Size Percent',40), ROUND((db_incr_backup_bytes_per_day)/(db_total_bytes - db_free_bytes),6));

  Pv(RPAD('* Daily Archive Log Size (GB)',40), ROUND((redo_backup_bytes_per_day)/POWER(1024,3),6));

  Pv(RPAD('* Daily Archive Backup Percent',40), ROUND((redo_backup_bytes_per_day)/(db_total_bytes - db_free_bytes),6));

  Pv(RPAD('* Recovery Window (Days)',40), protdb_recovery_window_days);

  Pv(RPAD('* Datafile Count',40), df_cnt);

  Pv(RPAD('* Largest Datafile (GB)',40), ROUND(largest_df_bytes/POWER(1024,3),6));

  Pv(RPAD('* Instance Count',40), inst_cnt);

  Pv(RPAD('* Backup Rate (GB/HR)',40), backup_rate);

  dbms_output.Put_line(RPAD('* Last Full Backup',40)||'='||last_full_backup);

  dbms_output.Put_line(RPAD('* Last Incr Backup',40)||'='||last_incr_backup);

  dbms_output.Put_line(RPAD('* Last Arch Backup',40)||'='||last_arch_backup);

  dbms_output.Put_line('********** End of ZDLRA Client Sizing Metrics (4.x) **********');

EXCEPTION
  WHEN is_pdb_error THEN
    dbms_output.Put_line('***** Only run this script in the Container Database (CDB); not in Pluggable databases (PDB) *****');
END;
/

SPOOL OFF
EXIT