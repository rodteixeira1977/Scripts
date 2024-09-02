define AWR_MINER_VER = 24.6.rc

/*
	Version History

	2024-06-24	24.6.3 	mgr	Added con_dbid to SIZE-ON-DISK query
	2024-06-01	24.6.1 	mgr	Fixed SIZE-ON-DISK when CDB has PDBs with different block sizes
	2024-02-14	24.2.0	mgr	Query change on WRM$_SNAPSHOT because it is partitioned in DB 21.0
	2023-12-19	23.11.3	mgr	Added several NLS session settings to force Language and Territory
	2023-12-18	23.11.2	mgr	Removed SEGMENT-IO-AWR section, as it never ran
	2023-12-16	23.11.1	mgr	Condensed format and removed DBID selection, always use active DBID
	2023-12-15	23.11.0	mgr	Reformated for readablity, converted spaces to tabs, etc
	2023-10-02	22.8	pro	Add Set NLS_NUMERIC_CHARACTERS
	2023-09-19	22.7	pro	Extract Full Database Version on DBs higher than 18
	2023-09-11	22.6	pro	Add set numformat to prevent this parameter being set in glogin.sql
	2023-09-06	22.5	pro	Fix invalid column name error on db selection for 12.1 and lower databases
	2023-08-08	22.4	pro	Do not select DB_UNIQUE_NAME,DATABASE_ROLE on 12.1 and lower
	2023-07-19	22.3	pro	Rename temporary files and add text to them
	2023-05-18	22.2	pro	Fix statistics_level obtention for nonCDB databases
	2023-05-04	22.1	pro	Make INVALID_SYS_STATS error a warning
	2023-05-03	22.1	pro	Add CON_ID = 0 to statistics_level obtention
	2023-04-28	22.1	pro	Add action for INVALID_SYSTEM_STATS error
	2023-03-27	22.1	pro	Disable paralellisim for 11g databases
	2023-03-13	22.0	pro	Consolidate miners (EMR and AWR) stdout
	2023-03-09	21.6.9	pro	Add non-interactive execution and consolidate miners stdout
	2023-03-07	21.6.8	pro	Add calculation of paralellism degree based on cpu_num in the host
	2023-03-06	21.6.7	pro	Add Paralellisim to segment_io_awr query
	2023-03-03	21.6.6	pro	Consolidate Error Messages
	2023-03-02	21.6.5	pro	Add Built-in Diagnostics
	2023-03-01	21.6.4	pro	Improve stdout messages
	2023-02-28	21.6.3	pro	Add Paralellisim to segment_io query
	2023-02-13	21.6.2	pro	Add DIAGNOSTICS-ROW-COUNTS section
	2023-02-10	21.6.2	pro	Remove obsoleted DATABASE-PARAMETER
	2022-11-03	21.6.1	pro	Collect values from (MAX_SNAPSHOT -1)
*/

define SQL_TOP_N = 100
define CAPTURE_HOST_NAMES = 'YES'

-- Set the paralellism degree for the segment_io query , if equals 0 the paralellism degree is calculated automatically
-- based on the number of CPUS existing in the host . Any other value different from 0 is used as it is
define CUSTOM_PARALELLISM_DEGREE = 0

-- Last n days of data to capture.
define NUM_DAYS = 30
-- Only change the DATE_BEGIN | END parameters to filter to a certain range.
-- For 99% of the use-cases, just leave these parameters alone.
-- If DATE_BEGIN is changed, NUM_DAYS is ignored
-- Date Format YYYY-MM-DD
define DATE_BEGIN = '2000-01-01'
define DATE_END = '2040-01-01'

set pagesize 50000
set linesize 1000
set arraysize 5000
set termout off
set timing off
set serveroutput on
set verify off
set feedback off
set tab off
set wrap off
set heading on
set trimspool on

set define '&'
set concat '~'
set colsep " "
set underline '-'
set numformat ""
set numwidth 10

REPHEADER OFF
REPFOOTER OFF

alter session set optimizer_dynamic_sampling = 4;
alter session set workarea_size_policy = manual;
alter session set sort_area_size = 268435456;
alter session set cursor_sharing = exact;

-- Force NLS settings to known values, required for post processing
alter session set nls_language = American;
alter session set nls_territory = America;
alter session set nls_calendar = Gregorian;
alter session set nls_date_language = American;
alter session set nls_date_format = 'YYYY-MM-DD HH24:MI:SS';
alter session set nls_timestamp_format = 'YYYY-MM-DD HH24:MI:SS';
alter session set nls_numeric_characters = ".,";
alter session set nls_length_semantics = BYTE;

set termout on
prompt +-------------------------------------------------------------------+
prompt |  ###   ###  ###   ####                                            |
prompt | #   # #    #     #   #                 _                          |
prompt | #   # #    #    ######     /\   |  |  |_)   |\/|  o   _    _   ,_ |
prompt |  ###  ###  ### ##   ##    /--\  |/\|  | \   |  |  |  | |  (/_  |  |
prompt +-------------------------------------------------------------------+
prompt
prompt AWR-Miner Version &AWR_MINER_VER
prompt Collects metrics and statistics from AWR History of individual Oracle Databases.
prompt
set termout off

-- ##############################################################################################
-- Get the Database ID to execute the script and set plsql_ccflags
-- ##############################################################################################
whenever sqlerror continue

column DBID_1 new_value DBID noprint
select ltrim(dbid) DBID_1 from v$database;

define DB_VERSION = 0
column :DB_VERSION_1 noprint new_value DB_VERSION
variable DB_VERSION_1 number

set termout on 
declare
	version_gte_11_2	varchar2(30);
	l_sql			varchar2(32767);
	l_variables		varchar2(1000) := ' ';
	dbinfo_sql		varchar2(32767);
	dbinfo_sql_cursor	sys_refcursor;
	l_dbid			number;
	l_db_name		varchar2(9);
	l_db_unique_name	varchar2(30);
	l_database_role		varchar2(16);

begin
	:DB_VERSION_1 := dbms_db_version.version + (dbms_db_version.release / 10);

	dbms_output.put_line('Database Ids in this AWR Repository:');
	dbms_output.put_line('-------------------------------------------------------------------------------');

	if :DB_VERSION_1 >= 12.2 then
		-- dbms_output.put_line(chr(10));
		dbms_output.put_line(rpad('Database ID',20)||rpad('Database Name',20)||rpad('Database Unique Name',25)||rpad('Database Role',20));
		dbms_output.put_line(rpad('-----------',20)||rpad('-------------',20)||rpad('--------------------',25)||rpad('-------------',20));

		dbinfo_sql := 'select distinct dh.dbid,dh.db_name,dh.db_unique_name,dh.database_role from dba_hist_database_instance dh order by db_name';
		open dbinfo_sql_cursor for dbinfo_sql;
		loop
			fetch dbinfo_sql_cursor into l_dbid, l_db_name, l_db_unique_name, l_database_role;
			exit when dbinfo_sql_cursor%notfound;
			dbms_output.put_line(rpad(l_dbid,20)||rpad(l_db_name,20)||rpad(l_db_unique_name,25)||rpad(l_database_role,20));
		end loop;
		close dbinfo_sql_cursor;
		-- dbms_output.put_line(chr(10));
	else
		-- dbms_output.put_line(chr(10));
		dbms_output.put_line(rpad('Database ID',20)||rpad('Database Name',20));
		dbms_output.put_line(rpad('-----------',20)||rpad('-------------',20));

		dbinfo_sql := 'select distinct dh.dbid,dh.db_name from dba_hist_database_instance dh order by db_name';
		open dbinfo_sql_cursor for dbinfo_sql;
		loop
			fetch dbinfo_sql_cursor into l_dbid, l_db_name;
			exit when dbinfo_sql_cursor%notfound;
			dbms_output.put_line(rpad(l_dbid,20)||rpad(l_db_name,20));
		end loop;
		close dbinfo_sql_cursor;
		-- dbms_output.put_line(chr(10));
	end if;

	if :DB_VERSION_1 >= 11.2 then
		l_variables := l_variables||'ver_gte_11_2:TRUE';
	else
		l_variables := l_variables||'ver_gte_11_2:FALSE';
	end if;

	if :DB_VERSION_1 >= 11.1 then
		l_variables := l_variables||',ver_gte_11_1:TRUE';
	else
		l_variables := l_variables||',ver_gte_11_1:FALSE';
	end if;

	l_sql := q'[alter session set plsql_ccflags =']'||l_variables||q'[']';
	execute immediate l_sql;
end;
/
prompt

set termout off
select :DB_VERSION_1 from dual;

-- ##############################################################################################
-- Determine if we have valid stats on the SYS SCHEMA
-- ##############################################################################################
whenever sqlerror continue
set termout on

declare
	l_stat_rows number := 1;
	l_last_analyzed_days number:= 0;
	l_last_analyzed_threshold constant number:= 60;
	l_actual_rows number;
	l_pct_change number := 0;
	l_error boolean := False;
begin
	select nvl(NUM_ROWS,1) nrows,round(sysdate - S.LAST_ANALYZED) last_analyzed_days
	into l_stat_rows,l_last_analyzed_days
	from sys.DBA_TAB_STATISTICS s
	where owner = 'SYS' and table_name = 'WRM$_SNAPSHOT' and object_type = 'TABLE';

	select count(*) num_rows
	into l_actual_rows
	from sys.dba_hist_snapshot;

	if l_stat_rows is null or l_stat_rows < 1 then
		l_stat_rows := 1;
	end if;
	--dbms_output.put_line('Stats: '||l_stat_rows);
	--dbms_output.put_line('Actual: '||l_actual_rows);

	l_pct_change := abs(round((l_actual_rows-l_stat_rows)/l_stat_rows,3))*100;
	--dbms_output.put_line('% Change: '||l_pct_change);

	if l_pct_change >= 30 or l_last_analyzed_days > l_last_analyzed_threshold then
		dbms_output.put_line('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
		dbms_output.put_line('WARNING:');
		dbms_output.put_line('INVALID_SYS_STATS: Invalid or outdated statistics on SYS Schema.');
		if l_last_analyzed_days > l_last_analyzed_threshold then
			dbms_output.put_line(q'!Statistics haven't been collect for !'||l_last_analyzed_days||q'! days!');
		end if;
		dbms_output.put_line(chr(10));
		dbms_output.put_line('This can have serious, negative performance implications for this script ');
		dbms_output.put_line('as well as AWR, ASH, and ADDM. Please review My Oracle Support Doc ID 457926.1');
		dbms_output.put_line('for details on gathering stats on SYS objects.');
		dbms_output.put_line('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
		dbms_output.put_line(chr(10));
		-- dbms_output.put_line('-> This script will now EXIT with error ORA-00900.');
		l_error := true ;
	end if;

	-- if l_error = true then
	-- execute immediate 'bogus statement to force exit';
	-- end if;
end;
/

-- ##############################################################################################
-- Get the TIME_WAITED_MICRO column based on the Database version
-- ##############################################################################################
define T_WAITED_MICRO_COL = 'TIME_WAITED_MICRO'
column :T_WAITED_MICRO_COL_1 new_value T_WAITED_MICRO_COL noprint
variable T_WAITED_MICRO_COL_1 varchar2(30)

begin
	if :DB_VERSION_1 >= 11.1 then
		:T_WAITED_MICRO_COL_1 := 'TIME_WAITED_MICRO_FG';
	else
		:T_WAITED_MICRO_COL_1 := 'TIME_WAITED_MICRO';
	end if;
end;
/

set termout off
select :T_WAITED_MICRO_COL_1 from dual;
set termout on

-- ##############################################################################################
-- Get the DB Block Size for Storage calculations
-- ##############################################################################################
define DB_BLOCK_SIZE = 0
column :DB_BLOCK_SIZE_1 noprint new_value DB_BLOCK_SIZE
variable DB_BLOCK_SIZE_1 number

begin

	:DB_BLOCK_SIZE_1 := 0;

	for c1 in (
		with inst as (
			select min(instance_number) inst_num
			from dba_hist_snapshot
			where dbid = &DBID
			)
		select value the_block_size
		from dba_hist_parameter
		where dbid = &DBID
			and parameter_name = 'db_block_size'
			and snap_id = (select max(snap_id)
				from dba_hist_osstat
				where dbid = &DBID
					and instance_number = (select inst_num from inst))
			and instance_number = (select inst_num from inst)
	)
	loop
		:DB_BLOCK_SIZE_1 := c1.the_block_size;
	end loop; --c1

	if :DB_BLOCK_SIZE_1 = 0 then
		:DB_BLOCK_SIZE_1 := 8192;
	end if;
end;
/

set termout off
select :DB_BLOCK_SIZE_1 from dual;

-- ##############################################################################################
-- Get the SNAPSHOT range
-- ##############################################################################################
column snap_min1 new_value SNAP_ID_MIN

set termout off
select min(snap_id) - 1 snap_min1
from dba_hist_snapshot
where dbid = &DBID
	and (('&DATE_BEGIN' = '2000-01-01' and begin_interval_time > (
			select max(begin_interval_time) - &NUM_DAYS
			from dba_hist_snapshot
			where dbid = &DBID))
		or ('&DATE_BEGIN' != '2000-01-01' and begin_interval_time >= trunc(to_date('&DATE_BEGIN','YYYY-MM-DD'))));

column snap_max1 new_value SNAP_ID_MAX noprint
select max(snap_id) - 1 snap_max1
from dba_hist_snapshot
where dbid = &DBID
	and begin_interval_time < trunc(to_date('&DATE_END','YYYY-MM-DD'))+1
	and ('&DATE_BEGIN' = '2000-01-01' or ( '&DATE_BEGIN' != '2000-01-01' and begin_interval_time >= trunc(to_date('&DATE_BEGIN','YYYY-MM-DD'))));

set termout on

-- Error if there are not snapshots for the data range selected
whenever sqlerror exit
begin
	--if length(&SNAP_ID_MIN) > 0 and length(&SNAP_ID_MAX) > 0 then
	--dbms_output.put_line('foo'|| REGEXP_REPLACE('&SNAP_ID_MIN','[[:space:]]','')||'bar');
	--if ('&SNAP_ID_MIN') != '' then
	if length(regexp_replace('&SNAP_ID_MIN','[[:space:]]','')) > 0 and length(regexp_replace('&SNAP_ID_MAX','[[:space:]]','')) > 0 then
		null;
	else
		dbms_output.put_line('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
		dbms_output.put_line('ERROR:');
		dbms_output.put_line('INVALID_DATE_RANGE: The chosen date range does NOT contain any AWR snapshot.');
		dbms_output.put_line('Begin date :'||to_date('&DATE_BEGIN','YYYY-MM-DD'));
		dbms_output.put_line('End date   :'||to_date('&DATE_END','YYYY-MM-DD'));
		dbms_output.put_line('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
		dbms_output.put_line(chr(10));
		dbms_output.put_line('-> This script will now EXIT with error ORA-00900.');
		execute immediate 'bogus statement to force exit';
	end if;
end;
/

-- Error if there are not enough snapshots collected in AWR repository to perform analysis
whenever sqlerror exit
declare
	l_snapshot_count number := 0;
begin
	for c1 in (select count(*) cnt
		from dba_hist_snapshot
		where dbid = &DBID)
	loop
		l_snapshot_count := c1.cnt;
	end loop;

	if l_snapshot_count > 2 then
		null;
	else
		dbms_output.put_line('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
		dbms_output.put_line('ERROR:');
		dbms_output.put_line('INVALID_SNAPSHOT_COUNT: Unable to find enough AWR Snapshots to perform Analysis.');
		dbms_output.put_line('Please review My Oracle Support Docs IDs 1599440.1 and 1301503.1.');
		dbms_output.put_line('for troubleshooting missing AWR Snapshots and Other Collection Issues.');
		dbms_output.put_line('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
		dbms_output.put_line(chr(10));
		dbms_output.put_line('-> This script will now EXIT with error ORA-00900.');
		execute immediate 'bogus statement to force exit';
	end if;
end;
/

-- ##############################################################################################
-- Get the NUM_CPUS from the host to set PARALLELISM_DEGREE automatically
-- ##############################################################################################
column :CUSTOM_PARALELLISM_DEGREE_1 new_value CUSTOM_PARALELLISM_DEGREE
variable CUSTOM_PARALELLISM_DEGREE_1 number

define PARALELLISM_DEGREE_AUTO = 0
column :PARALELLISM_DEGREE_1 new_value PARALELLISM_DEGREE_AUTO
variable PARALELLISM_DEGREE_1 number

declare
	v_cpu_num number :=0 ;
begin

	-- Grab the current value set in the script
	:CUSTOM_PARALELLISM_DEGREE_1 := &CUSTOM_PARALELLISM_DEGREE;

	if :CUSTOM_PARALELLISM_DEGREE_1 = 0 then

		for c1 in (
			with inst as (
				SELECT min(instance_number) inst_num
				FROM dba_hist_snapshot
				WHERE dbid = &DBID AND snap_id BETWEEN to_number(&SNAP_ID_MIN) AND to_number(&SNAP_ID_MAX))
			SELECT value cpu_num
			FROM dba_hist_osstat
			WHERE dbid = &DBID
				AND snap_id = (
					SELECT max(snap_id)
					FROM dba_hist_osstat
					WHERE dbid = &DBID AND instance_number = (SELECT inst_num FROM inst))
				AND instance_number = (SELECT inst_num FROM inst)
				AND stat_name = 'NUM_CPUS'
			)
		loop
			v_cpu_num:=c1.cpu_num;
		end loop; --c1

		if v_cpu_num > 0 then
			:PARALELLISM_DEGREE_1:=v_cpu_num;
		else
			:PARALELLISM_DEGREE_1:=0;
		end if;
	else
		:PARALELLISM_DEGREE_1 := &CUSTOM_PARALELLISM_DEGREE;
	end if;

	-- Disable parallelisim for 11g databases
	if :DB_VERSION_1 <= 11.2 then
		:PARALELLISM_DEGREE_1 := 0;
	end if;
end;
/

set termout off
select :PARALELLISM_DEGREE_1 from dual;

define PARALELLISM_DEGREE = &PARALELLISM_DEGREE_AUTO

-- ##############################################################################################
-- Check the Health of the Metrics and Statistics in the AWR repository
-- ##############################################################################################

-- Error if 'statistics_level' init parameter is set to BASIC (Disables AWR Collection)
set termout on
whenever sqlerror exit
declare
	statistics_level_param_value varchar2(30) := '';
begin
	SELECT value
	INTO statistics_level_param_value
	FROM V$SYSTEM_PARAMETER
	WHERE name='statistics_level' AND rownum = 1;

	if statistics_level_param_value != 'BASIC' then
		null;
	else
		dbms_output.put_line('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
		dbms_output.put_line('ERROR:');
		dbms_output.put_line('INVALID_STATS_LEVEL: Parameter statistcs_level is set to BASIC.');
		dbms_output.put_line('statistics_level MUST be set to TYPICAL or ALL to enable AWR collections');
		dbms_output.put_line('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
		dbms_output.put_line(chr(10));
		dbms_output.put_line('-> This script will now EXIT with error ORA-00900.');
		execute immediate 'bogus statement to force exit';
	end if;
end;
/

-- Error if there are no metrics in DBA_HIST_SYSMETRIC_SUMMARY for the AWR Snapshot range
whenever sqlerror exit
declare
	l_metrics_count number := 0;
begin
	SELECT count(*)
	INTO l_metrics_count
	FROM dba_hist_sysmetric_summary
	WHERE dbid = &DBID AND snap_id between &SNAP_ID_MIN and &SNAP_ID_MAX;

	if l_metrics_count > 1 then
		null;
	else
		dbms_output.put_line('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
		dbms_output.put_line('ERROR:');
		dbms_output.put_line('INVALID_SYSTEM_METRICS: Unable to find System Metrics for the chosen range.');
		dbms_output.put_line('The view DBA_HIST_SYSMETRIC_SUMMARY does not contains rows.');
		dbms_output.put_line('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
		dbms_output.put_line(chr(10));
		dbms_output.put_line('-> This script will now EXIT with error ORA-00900.');
		execute immediate 'bogus statement to force exit';
	end if;
end;
/

-- Error if thera are no metrics in DBA_HIST_SYSSTAT for the AWR Snapshot range
set serveroutput on format wrapped
whenever sqlerror exit
declare
	l_metrics_count number := 0;
begin
	SELECT count(*)
	INTO l_metrics_count
	FROM dba_hist_sysstat
	WHERE dbid = &DBID AND snap_id between &SNAP_ID_MIN and &SNAP_ID_MAX;

	if l_metrics_count > 1 then
		null;
	else
		dbms_output.put_line('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
		dbms_output.put_line('ERROR:');
		dbms_output.put_line('INVALID_SYSTEM_STATS: Unable to find System Statistics for the chosen range.');
		dbms_output.put_line('The view DBA_HIST_SYSSTAT does not contains rows.');
		dbms_output.put_line(chr(10));
		dbms_output.put_line('ACTION:');
		dbms_output.put_line(' To get proper AWR results modify Snapshot collection settings to:');
		dbms_output.put_line(' BEGIN');
		dbms_output.put_line('   DBMS_WORKLOAD_REPOSITORY.MODIFY_SNAPSHOT_SETTINGS( ');
		dbms_output.put_line('      interval => 60,');
		dbms_output.put_line('      retention => 47520);');
		dbms_output.put_line(' END;');
		dbms_output.put_line(' /');
		dbms_output.put_line(' Where:');
		dbms_output.put_line('  interval is set to 60 minutes');
		dbms_output.put_line('  retention is set to 47520 minutes (33 days)');
		dbms_output.put_line('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
		dbms_output.put_line(chr(10));
		dbms_output.put_line('-> This script will now EXIT with error ORA-00900.');
		execute immediate 'bogus statement to force exit';
	end if;
end;
/
set serveroutput on

-- Error if thera are no metrics in DBA_HIST_TBSPC_SPACE_USAGE for the AWR Snapshot range
whenever sqlerror exit
declare
	l_metrics_count number := 0;
begin
	SELECT count(*)
	INTO l_metrics_count
	FROM dba_hist_tbspc_space_usage
	WHERE dbid = &DBID AND snap_id between &SNAP_ID_MIN and &SNAP_ID_MAX;

	if l_metrics_count > 1 then
		null;
	else
		dbms_output.put_line('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
		dbms_output.put_line('ERROR:');
		dbms_output.put_line('INVALID_TABLESPACE_STATS: Unable to find tablespace usage statistics information for the chosen range.');
		dbms_output.put_line('The view DBA_HIST_TBSPC_SPACE_USAGE does not contains rows.');
		dbms_output.put_line('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
		dbms_output.put_line(chr(10));
		dbms_output.put_line('-> This script will now EXIT with error ORA-00900.');
		execute immediate 'bogus statement to force exit';
	end if;
end;
/

-- ##############################################################################################
-- Show the Execution Environment
-- ##############################################################################################
set termout off
column db_name1 new_value DBNAME
select dbid,db_name db_name1
from dba_hist_database_instance
where dbid = &DBID and rownum = 1;

define DB_BLOCK_SIZE_DSP = &DB_BLOCK_SIZE
define SNAP_ID_MIN_DSP = &SNAP_ID_MIN
define SNAP_ID_MAX_DSP = &SNAP_ID_MAX
define DB_VERSION_DSP = &DB_VERSION

set termout on
prompt Execution Environment:
prompt --------------------------------------------------------------------------------

prompt Database ID         : &DBID
prompt Database Name       : &DBNAME
prompt Database Version    : &DB_VERSION_DSP
prompt Database Block Size : &DB_BLOCK_SIZE_DSP
prompt Min Snapshot ID     : &SNAP_ID_MIN_DSP
prompt Max Snapshot ID     : &SNAP_ID_MAX_DSP
prompt Collect last n days : &NUM_DAYS
prompt Time Waited Column  : &T_WAITED_MICRO_COL
prompt Paralellisim Degree : &PARALELLISM_DEGREE
prompt --------------------------------------------------------------------------------

prompt
prompt Starting Extract Script!
prompt

set termout off
whenever sqlerror continue
column FILE_NAME new_value SPOOL_FILE_NAME noprint
select 'awr-hist-'||ltrim('&DBID')||'-'||ltrim('&DBNAME')||'-'||ltrim('&SNAP_ID_MIN')||'-'||ltrim('&SNAP_ID_MAX')||'.out' FILE_NAME from dual;

set timing on
timing start &SPOOL_FILE_NAME

-- ##############################################################################################
set termout on
prompt Extracting OS information...
set termout off
spool &SPOOL_FILE_NAME

prompt ------------------------- BEGIN-OS-INFORMATION ------------------------------------------

REPHEADER ON
REPFOOTER ON

declare
	l_pad_length		number :=60;
	l_hosts			varchar2(4000);
	l_dbid			number;

	db_version_sql		varchar2(32767);
	db_version_sql_cursor	sys_refcursor;
	l_db_version		varchar2(30);
begin

	dbms_output.put_line('~~BEGIN-OS-INFORMATION~~');
	dbms_output.put_line(rpad('STAT_NAME',l_pad_length)||' '||'STAT_VALUE');
	dbms_output.put_line(rpad('-',l_pad_length,'-')||' '||rpad('-',l_pad_length,'-'));

	for c1 in (
		with inst as (
			select min(instance_number) inst_num
			from dba_hist_snapshot
			where dbid = &DBID
				and snap_id between to_number(&SNAP_ID_MIN) and to_number(&SNAP_ID_MAX))
		select case when stat_name = 'PHYSICAL_MEMORY_BYTES' then 'PHYSICAL_MEMORY_GB' else stat_name end stat_name,
			case when stat_name in ('PHYSICAL_MEMORY_BYTES') then round(value/1024/1024/1024,2) else value end stat_value
		from dba_hist_osstat
		where dbid = &DBID
			and snap_id = (select max(snap_id) from dba_hist_osstat where dbid = &DBID and instance_number = (select inst_num from inst))
			and instance_number = (select inst_num from inst)
			and (stat_name like 'NUM_CPU%' or stat_name in ('PHYSICAL_MEMORY_BYTES')))
	loop
		dbms_output.put_line(rpad(c1.stat_name,l_pad_length)||' '||c1.stat_value);
	end loop; --c1

	for c1 in (select CPU_COUNT,CPU_CORE_COUNT,CPU_SOCKET_COUNT
		from DBA_CPU_USAGE_STATISTICS
		where dbid = &DBID
			and timestamp = (select max(timestamp) from DBA_CPU_USAGE_STATISTICS where dbid = &DBID) and rownum = 1)
	loop
		dbms_output.put_line(rpad('!CPU_COUNT',l_pad_length)||' '||c1.CPU_COUNT);
		dbms_output.put_line(rpad('!CPU_CORE_COUNT',l_pad_length)||' '||c1.CPU_CORE_COUNT);
		dbms_output.put_line(rpad('!CPU_SOCKET_COUNT',l_pad_length)||' '||c1.CPU_SOCKET_COUNT);
	end loop;

	for c1 in (select distinct platform_name from sys.GV_$DATABASE where dbid = &DBID and rownum = 1)
	loop
		dbms_output.put_line(rpad('!PLATFORM_NAME',l_pad_length)||' '||c1.platform_name);
	end loop;

	for c2 in (select
			$IF $$VER_GTE_11_2 $THEN
				REPLACE(platform_name,' ','_') platform_name,
			$ELSE
				'None' platform_name,
			$END
			--VERSION,
			db_name,DBID
		from dba_hist_database_instance
		where dbid = &DBID and startup_time = (select max(startup_time) from dba_hist_database_instance where dbid = &DBID ) and rownum = 1)
	loop
		dbms_output.put_line(rpad('PLATFORM_NAME',l_pad_length)||' '||c2.platform_name);
		-- dbms_output.put_line(rpad('VERSION',l_pad_length)||' '||c2.VERSION);
		dbms_output.put_line(rpad('DB_NAME',l_pad_length)||' '||c2.db_name);
		dbms_output.put_line(rpad('DBID',l_pad_length)||' '||c2.DBID);
	end loop; --c2

	-- Get the Database Version
	if :DB_VERSION_1 >= 18 then
		db_version_sql := '
			with inst as (
				select min(instance_number) inst_num
				from dba_hist_snapshot
				where dbid = &DBID and snap_id between to_number(&SNAP_ID_MIN) and to_number(&SNAP_ID_MAX))
				select VERSION_FULL
				from GV$INSTANCE
				where instance_number = (select inst_num from inst)';

		open db_version_sql_cursor for db_version_sql;
			loop
				fetch db_version_sql_cursor into l_db_version;
				exit when db_version_sql_cursor%notfound;
				dbms_output.put_line(rpad('VERSION',l_pad_length)||' '||l_db_version);
			end loop;
	else
		db_version_sql := '
			select VERSION
			FROM dba_hist_database_instance
			where dbid = &DBID
				and startup_time = (select max(startup_time) from dba_hist_database_instance where dbid = &DBID) and rownum = 1';

		open db_version_sql_cursor for db_version_sql;
			loop
				fetch db_version_sql_cursor into l_db_version;
				exit when db_version_sql_cursor%notfound;
				dbms_output.put_line(rpad('VERSION',l_pad_length)||' '||l_db_version);
			end loop;
	end if;

	for c3 in (select count(distinct s.instance_number) instances
		from dba_hist_database_instance i,dba_hist_snapshot s
			where i.dbid = s.dbid and i.dbid = &DBID and s.snap_id between &SNAP_ID_MIN and &SNAP_ID_MAX)
	loop
		dbms_output.put_line(rpad('INSTANCES',l_pad_length)||' '||c3.instances);
	end loop; --c3

	for c4 in (select distinct regexp_replace(host_name,'^([[:alnum:]]+)\..*$','\1') host_name
		from dba_hist_database_instance i,dba_hist_snapshot s
		where i.dbid = s.dbid and i.dbid = &DBID and s.startup_time = i.startup_time and s.snap_id between &SNAP_ID_MIN and &SNAP_ID_MAX
		order by 1)
	loop
		if '&CAPTURE_HOST_NAMES' = 'YES' then
			l_hosts := l_hosts || c4.host_name ||',';
		end if;
	end loop; --c4
	l_hosts := rtrim(l_hosts,',');
	dbms_output.put_line(rpad('HOSTS',l_pad_length)||' '||l_hosts);

	for c5 in (select regexp_replace(sys_context('USERENV', 'MODULE'),'^(.+?)@.+$','\1') module from DUAL)
	loop
		dbms_output.put_line(rpad('MODULE',l_pad_length)||' '||c5.module);
	end loop; --c5

	dbms_output.put_line(rpad('AWR_MINER_VER',l_pad_length)||' &AWR_MINER_VER');
	dbms_output.put_line('~~END-OS-INFORMATION~~');
end;
/

prompt
prompt ------------------------- BEGIN-OS-INFORMATION2 ------------------------------------------

declare
	l_pad_length		number :=60;
	l_hosts			varchar2(4000);
	l_dbid			number;

	l_instance_number	number := null;

	db_version_sql		varchar2(32767);
	db_version_sql_cursor	sys_refcursor;
	l_db_version		varchar2(30);
	l_db_name		varchar2(30);
	l_startup_time		varchar2(30);
begin
	dbms_output.put_line('~~BEGIN-OS-INFORMATION2~~');
	dbms_output.put_line(rpad('STAT_NAME',l_pad_length)||' '||rpad('INSTANCE',l_pad_length)||' ' ||'STAT_VALUE');
	dbms_output.put_line(rpad('-',l_pad_length,'-')||' '||rpad('-',l_pad_length,'-')||' '||rpad('-',l_pad_length,'-'));

	for c1 in (
		select case when stat_name = 'PHYSICAL_MEMORY_BYTES' then 'PHYSICAL_MEMORY_GB' else stat_name end stat_name,
			case when stat_name in ('PHYSICAL_MEMORY_BYTES') then round(value/1024/1024/1024,2) else value end stat_value,
			instance_number
		from dba_hist_osstat o
		where dbid = &DBID
			and snap_id = (select max(snap_id) from dba_hist_osstat i where i.dbid = o.dbid and i.instance_number = o.instance_number)
			and (stat_name like 'NUM_CPU%' or stat_name in ('PHYSICAL_MEMORY_BYTES'))
		)
	loop
		dbms_output.put_line(rpad(c1.stat_name,l_pad_length)||' '||rpad(c1.instance_number,l_pad_length)||' '||c1.stat_value);
	end loop; --c1

	for c1 in (select CPU_COUNT,CPU_CORE_COUNT,CPU_SOCKET_COUNT
		from DBA_CPU_USAGE_STATISTICS
		where dbid = &DBID
			and timestamp = (select max(timestamp) from DBA_CPU_USAGE_STATISTICS where dbid = &DBID ) and rownum = 1)
	loop
		dbms_output.put_line(rpad('!CPU_COUNT',l_pad_length)||' '||rpad('0',l_pad_length)||' '||c1.CPU_COUNT);
		dbms_output.put_line(rpad('!CPU_CORE_COUNT',l_pad_length)||' '||rpad('0',l_pad_length)||' '||c1.CPU_CORE_COUNT);
		dbms_output.put_line(rpad('!CPU_SOCKET_COUNT',l_pad_length)||' '||rpad('0',l_pad_length)||' '||c1.CPU_SOCKET_COUNT);
	end loop;

	for c1 in (select inst_id, platform_name from sys.GV_$DATABASE
		where dbid = &DBID and rownum = 1)
	loop
		dbms_output.put_line(rpad('!PLATFORM_NAME',l_pad_length)||' '||rpad('0',l_pad_length)||' '||c1.platform_name);
	end loop;


	l_instance_number := null;

	for c2 in (select distinct
			$IF $$VER_GTE_11_2 $THEN
				REPLACE(platform_name,' ','_') platform_name,
			$ELSE
				'None' platform_name,
			$END
			-- VERSION,
			i.db_name, i.DBID, i.instance_number, i.startup_time
		from dba_hist_database_instance i,dba_hist_snapshot s
		where i.dbid = s.dbid and i.dbid = &DBID and s.startup_time = i.startup_time and s.snap_id between &SNAP_ID_MIN and &SNAP_ID_MAX
		order by i.instance_number, i.startup_time desc)
	loop
		if c2.instance_number = l_instance_number then
			CONTINUE;
		end if;

		l_instance_number := c2.instance_number;

		dbms_output.put_line(rpad('PLATFORM_NAME',l_pad_length)||' '||rpad('0',l_pad_length)||' '||c2.platform_name);
		-- dbms_output.put_line(rpad('VERSION',l_pad_length)||' '||rpad('0',l_pad_length)||' '||c2.VERSION);
		dbms_output.put_line(rpad('DB_NAME',l_pad_length)||' '||rpad('0',l_pad_length)||' '||c2.db_name);
		dbms_output.put_line(rpad('DBID',l_pad_length)||' '||rpad('0',l_pad_length)||' '||c2.DBID);
		dbms_output.put_line(rpad('INSTANCE_NUMBER',l_pad_length)||' '||rpad('0',l_pad_length)||' '||c2.INSTANCE_NUMBER);
	end loop; --c2

	-- Get the Database Version
	if :DB_VERSION_1 >= 18 then
		db_version_sql := '
			select INSTANCE_NUMBER, VERSION_FULL
			from GV$INSTANCE
			order by instance_number asc';

		open db_version_sql_cursor for db_version_sql;
		loop
			fetch db_version_sql_cursor into l_instance_number,l_db_version;
			exit when db_version_sql_cursor%notfound;
			dbms_output.put_line(rpad('VERSION',l_pad_length)||' '||rpad(l_instance_number,l_pad_length)||' '||l_db_version);
		end loop;
	else
		db_version_sql := '
			select distinct i.instance_number, VERSION, i.db_name, i.DBID, i.startup_time
			from dba_hist_database_instance i,dba_hist_snapshot s
			where i.dbid = s.dbid and i.dbid = &DBID and s.startup_time = i.startup_time and s.snap_id between &SNAP_ID_MIN and &SNAP_ID_MAX
			order by i.instance_number, i.startup_time desc' ;

		open db_version_sql_cursor for db_version_sql;
		loop
			fetch db_version_sql_cursor into l_instance_number,l_db_version,l_db_name,l_dbid, l_startup_time;
			exit when db_version_sql_cursor%notfound;
			dbms_output.put_line(rpad('VERSION',l_pad_length)||' '||rpad(l_instance_number,l_pad_length)||' '||l_db_version);
		end loop;
	end if;

	if '&CAPTURE_HOST_NAMES' = 'YES' then
		l_instance_number := null;

		for c4 in (
			select distinct i.instance_number, regexp_replace(i.host_name,'^([[:alnum:]]+)\..*$','\1') host_name, i.startup_time
			from dba_hist_database_instance i,dba_hist_snapshot s
			where i.dbid = s.dbid and i.dbid = &DBID and s.startup_time = i.startup_time and s.snap_id between &SNAP_ID_MIN and &SNAP_ID_MAX
			order by i.instance_number, host_name, i.startup_time desc)
		loop
			if c4.instance_number = l_instance_number then
				CONTINUE;
			end if;

			l_instance_number := c4.instance_number;

			dbms_output.put_line(rpad('HOSTS',l_pad_length)||' '||rpad(c4.instance_number,l_pad_length)||' '||c4.host_name);
		end loop; --c4
	end if;

	for c5 in (select regexp_replace(sys_context('USERENV', 'MODULE'),'^(.+?)@.+$','\1') module from DUAL)
	loop
		dbms_output.put_line(rpad('MODULE',l_pad_length)||' '||rpad('0',l_pad_length)||' '||c5.module);
	end loop; --c5

	dbms_output.put_line(rpad('AWR_MINER_VER',l_pad_length)||' '||rpad('0',l_pad_length)||' &AWR_MINER_VER');
	dbms_output.put_line('~~END-OS-INFORMATION2~~');
end;
/

spool off

-- ##############################################################################################
set termout on
prompt Extracting DB patch History...
set termout off
spool &SPOOL_FILE_NAME append;

prompt ------------------------- BEGIN-PATCH-HISTORY --------------------------------------------

REPHEADER PAGE LEFT '~~BEGIN-PATCH-HISTORY~~'
REPFOOTER PAGE LEFT '~~END-PATCH-HISTORY~~'

column action_time format a24
column comments format a80
select * from (
	select rownum rnum, h.* from DBA_REGISTRY_HISTORY h order by action_time desc)
where rownum <= 10;

spool off

-- ##############################################################################################
set termout on
prompt Extracting Module...
set termout off
spool &SPOOL_FILE_NAME append;

prompt ------------------------- BEGIN-MODULE ---------------------------------------------------

REPHEADER PAGE LEFT '~~BEGIN-MODULE~~'
REPFOOTER PAGE LEFT '~~END-MODULE~~'

set linesize 50
select regexp_replace(sys_context('USERENV', 'MODULE'),'^(.+?)@.+$','\1') module from DUAL;

-- reset to original value
set linesize 1000

spool off

-- ##############################################################################################
set termout on
prompt Extracting DB AWR snapshots...
set termout off
spool &SPOOL_FILE_NAME append;

prompt ------------------------- BEGIN-SNAP-HISTORY ---------------------------------------------

REPHEADER PAGE LEFT '~~BEGIN-SNAP-HISTORY~~'
REPFOOTER PAGE LEFT '~~END-SNAP-HISTORY~~'

select min(snap_id) snap_min, max(snap_id) snap_max,count(*) cnt,count(distinct INSTANCE_NUMBER) inst_count,
	sum(ERROR_COUNT) ERROR_COUNT
from dba_hist_snapshot
where dbid = &DBID;

spool off

-- ##############################################################################################
set termout on
prompt Extracting DB SGA and PGA settings...
set termout off
spool &SPOOL_FILE_NAME append;

prompt ------------------------- BEGIN-MEMORY ---------------------------------------------------

REPHEADER PAGE LEFT '~~BEGIN-MEMORY~~'
REPFOOTER PAGE LEFT '~~END-MEMORY~~'

select snap_id,
	instance_number,
	max (decode (stat_name, 'SGA', stat_value, null)) "SGA",
	max (decode (stat_name, 'PGA', stat_value, null)) "PGA",
	max (decode (stat_name, 'SGA', stat_value, null)) + max (decode (stat_name, 'PGA', stat_value,
	null)) "TOTAL"
from
	(select snap_id,
		instance_number,
		round (sum (bytes) / 1024 / 1024 / 1024, 1) stat_value,
		max ('SGA') stat_name
	from dba_hist_sgastat
	where dbid = &DBID and snap_id between &SNAP_ID_MIN and &SNAP_ID_MAX
	group by snap_id, instance_number
	union all
	select snap_id,
		instance_number,
		round (value / 1024 / 1024 / 1024, 1) stat_value,
		'PGA' stat_name
	from dba_hist_pgastat
	where dbid = &DBID and snap_id between &SNAP_ID_MIN and &SNAP_ID_MAX and NAME = 'total PGA allocated'
	)
group by snap_id,
instance_number
order by snap_id,
instance_number;

spool off

-- ##############################################################################################
set termout on
prompt Extracting DB SGA Advice...
set termout off
spool &SPOOL_FILE_NAME append;

prompt ------------------------- BEGIN-MEMORY-SGA-ADVICE ----------------------------------------

REPHEADER PAGE LEFT '~~BEGIN-MEMORY-SGA-ADVICE~~'
REPFOOTER PAGE LEFT '~~END-MEMORY-SGA-ADVICE~~'

select snap_id,instance_number,sga_target_gb,size_factor,ESTD_PHYSICAL_READS,lead_read_diff
from (
	with top_n_dbtime as (
		select snap_id from (
			select snap_id, sum(average) dbtime_p_s,
				dense_rank() over (order by sum(average) desc nulls last) rnk
			from dba_hist_sysmetric_summary
			where dbid = &DBID
				and snap_id between &SNAP_ID_MIN and &SNAP_ID_MAX
				and metric_name = 'Database Time Per Sec'
			group by snap_id)
		where rnk <= 10)
	select a.SNAP_ID,
		INSTANCE_NUMBER,
		round(sga_size/1024,1) sga_target_gb,
		sga_size_FACTOR size_factor,
		ESTD_PHYSICAL_READS,
		round((ESTD_PHYSICAL_READS - lead(ESTD_PHYSICAL_READS,1,ESTD_PHYSICAL_READS) over (partition by a.snap_id,instance_number order by sga_size_FACTOR asc nulls last)),1) lead_read_diff,
		min(sga_size_FACTOR) over (partition by a.snap_id,instance_number) min_factor,
		max(sga_size_FACTOR) over (partition by a.snap_id,instance_number) max_factor
	from DBA_HIST_SGA_TARGET_ADVICE a,top_n_dbtime tn
	where dbid = &DBID
		and a.snap_id = tn.snap_id)
where (size_factor = 1
	or size_factor = min_factor
	or size_factor = max_factor
	or lead_read_diff > 1)
order by snap_id asc,instance_number, size_factor asc nulls last;

spool off

-- ##############################################################################################
set termout on
prompt Extracting DB PGA Advice...
set termout off
spool &SPOOL_FILE_NAME append;

prompt ------------------------- BEGIN-MEMORY-PGA-ADVICE ----------------------------------------

REPHEADER PAGE LEFT '~~BEGIN-MEMORY-PGA-ADVICE~~'
REPFOOTER PAGE LEFT '~~END-MEMORY-PGA-ADVICE~~'

select SNAP_ID,
	INSTANCE_NUMBER,
	PGA_TARGET_GB,
	SIZE_FACTOR,
	ESTD_EXTRA_MB_RW,
	LEAD_SIZE_DIFF_MB,
	ESTD_PGA_CACHE_HIT_PERCENTAGE
from
	( with top_n_dbtime as
		(select snap_id
		from
			(select snap_id,
				sum(average) dbtime_p_s,
				dense_rank() over (order by sum(average) desc nulls last) rnk
			from dba_hist_sysmetric_summary
			where dbid = &DBID
				and snap_id between &SNAP_ID_MIN and &SNAP_ID_MAX
				and metric_name = 'Database Time Per Sec'
			group by snap_id
			)
		where rnk <= 10
		)
	select a.SNAP_ID,
		INSTANCE_NUMBER,
		round(PGA_TARGET_FOR_ESTIMATE/1024/1024/1024,1) pga_target_gb,
		PGA_TARGET_FACTOR size_factor,
		round(ESTD_EXTRA_BYTES_RW/1024/1024,1) ESTD_EXTRA_MB_RW,
		round((ESTD_EXTRA_BYTES_RW - lead(ESTD_EXTRA_BYTES_RW,1,ESTD_EXTRA_BYTES_RW) over (partition by a.snap_id,instance_number order by PGA_TARGET_FACTOR asc nulls last))/1024/1024,1) lead_size_diff_mb,
		ESTD_PGA_CACHE_HIT_PERCENTAGE,
		min(PGA_TARGET_FACTOR) over (partition by a.snap_id,instance_number) min_factor,
		max(PGA_TARGET_FACTOR) over (partition by a.snap_id,instance_number) max_factor
	from DBA_HIST_PGA_TARGET_ADVICE a,
		top_n_dbtime tn
	where dbid = &DBID
		and a.snap_id = tn.snap_id
	)
where (size_factor = 1
	or size_factor = min_factor
	or size_factor = max_factor
	or lead_size_diff_mb > 1)
	order by snap_id asc,
		instance_number,
		size_factor asc nulls last;

spool off

-- ##############################################################################################
set termout on
prompt Extracting DB size...
set termout off
spool &SPOOL_FILE_NAME append;

prompt ------------------------- BEGIN-SIZE-ON-DISK ---------------------------------------------

REPHEADER OFF
REPFOOTER OFF

define DB_SIZE_QUERY = ' '
column :DB_SIZE_QUERY_1 new_value DB_SIZE_QUERY noprint 
variable DB_SIZE_QUERY_1 varchar2(4000)

begin
	if :DB_VERSION_1 <= 11.2 then
		:DB_SIZE_QUERY_1 := q'! ts_info as (
					select dbid, ts#, tsname, max(block_size) block_size
					from dba_hist_datafile
					where dbid = &DBID
					group by dbid, ts#, tsname),
				snap_info as (
					select dbid, to_char(trunc(end_interval_time,'DD'),'MM/DD/YY') dd, max(s.snap_id) snap_id
					from dba_hist_snapshot s
					where dbid = &DBID and s.snap_id between &SNAP_ID_MIN and &SNAP_ID_MAX			
					group by dbid, trunc(end_interval_time,'DD'))
			select s.snap_id, round(sum(sp.tablespace_size*ts.block_size)/1024/1024/1024,2) size_gb
			from dba_hist_tbspc_space_usage sp,
				ts_info ts,
				snap_info s
			where s.dbid = sp.dbid
				and s.dbid = &DBID
				and s.snap_id between &SNAP_ID_MIN and &SNAP_ID_MAX
				and s.snap_id = sp.snap_id
				and sp.dbid = ts.dbid
				and sp.tablespace_id = ts.ts#
			group by s.snap_id, s.dd
			order by s.snap_id !';
	else
		:DB_SIZE_QUERY_1 := q'! ts_info as (
					select dbid, con_id, con_dbid, ts#, tsname, max(block_size) block_size
					from dba_hist_datafile
					where dbid = &DBID
					group by dbid, con_id, con_dbid, ts#, tsname),
				snap_info as (
					select dbid, to_char(trunc(end_interval_time,'DD'),'MM/DD/YY') dd, max(s.snap_id) snap_id
					from dba_hist_snapshot s
					where dbid = &DBID and s.snap_id between &SNAP_ID_MIN and &SNAP_ID_MAX			
					group by dbid, trunc(end_interval_time,'DD'))
			select s.snap_id, round(sum(sp.tablespace_size*ts.block_size)/1024/1024/1024,2) size_gb
			from dba_hist_tbspc_space_usage sp,
				ts_info ts,
				snap_info s
			where s.dbid = sp.dbid
				and s.dbid = &DBID
				and s.snap_id between &SNAP_ID_MIN and &SNAP_ID_MAX
				and s.snap_id = sp.snap_id
				and sp.dbid = ts.dbid
				and sp.con_id = ts.con_id
				and sp.con_dbid = ts.con_dbid
				and sp.tablespace_id = ts.ts#
			group by s.snap_id, s.dd
			order by s.snap_id !';
	end if;
end;
/

select :DB_SIZE_QUERY_1 from dual;

REPHEADER PAGE LEFT '~~BEGIN-SIZE-ON-DISK~~'
REPFOOTER PAGE LEFT '~~END-SIZE-ON-DISK~~'

with &DB_SIZE_QUERY ;

spool off

-- ##############################################################################################
set termout on
prompt Extracting OS statistics...
set termout off
spool &SPOOL_FILE_NAME append;

prompt ------------------------- BEGIN-OSSTAT ---------------------------------------------------

REPHEADER PAGE LEFT '~~BEGIN-OSSTAT~~'
REPFOOTER PAGE LEFT '~~END-OSSTAT~~'

select snap_id,
	INSTANCE_NUMBER,
	max(decode(STAT_NAME,'LOAD', round(value,1),null)) "load",
	max(decode(STAT_NAME,'NUM_CPUS', value,null)) "cpus",
	max(decode(STAT_NAME,'NUM_CPU_CORES', value,null)) "cores",
	max(decode(STAT_NAME,'NUM_CPU_SOCKETS', value,null)) "sockets",
	max(decode(STAT_NAME,'PHYSICAL_MEMORY_BYTES', round(value/1024/1024),null)) "mem_gb",
	max(decode(STAT_NAME,'FREE_MEMORY_BYTES', round(value/1024/1024),null)) "mem_free_gb",
	max(decode(STAT_NAME,'IDLE_TIME', value,null)) "idle",
	max(decode(STAT_NAME,'BUSY_TIME', value,null)) "busy",
	max(decode(STAT_NAME,'USER_TIME', value,null)) "user",
	max(decode(STAT_NAME,'SYS_TIME', value,null)) "sys",
	max(decode(STAT_NAME,'IOWAIT_TIME', value,null)) "iowait",
	max(decode(STAT_NAME,'NICE_TIME', value,null)) "nice",
	max(decode(STAT_NAME,'OS_CPU_WAIT_TIME', value,null)) "cpu_wait",
	max(decode(STAT_NAME,'RSRC_MGR_CPU_WAIT_TIME', value,null)) "rsrc_mgr_wait",
	max(decode(STAT_NAME,'VM_IN_BYTES', value,null)) "vm_in",
	max(decode(STAT_NAME,'VM_OUT_BYTES', value,null)) "vm_out",
	max(decode(STAT_NAME,'cpu_count', value,null)) "cpu_count"
from
	(select snap_id,
		INSTANCE_NUMBER,
		STAT_NAME,
		value
	from DBA_HIST_OSSTAT
	where dbid = &DBID
		and snap_id between &SNAP_ID_MIN and &SNAP_ID_MAX
	union all
	select SNAP_ID,
		INSTANCE_NUMBER,
		PARAMETER_NAME STAT_NAME,
		to_number(value) value
	from DBA_HIST_PARAMETER
	where dbid = &DBID
		and snap_id between &SNAP_ID_MIN and &SNAP_ID_MAX
		and PARAMETER_NAME = 'cpu_count'
	)
group by snap_id,
	INSTANCE_NUMBER
order by snap_id,
	INSTANCE_NUMBER;

spool off

-- ##############################################################################################
set termout on
prompt Extracting Host metrics...
set termout off
spool &SPOOL_FILE_NAME append;

prompt ------------------------- BEGIN-MAIN-METRICS ---------------------------------------------

REPHEADER PAGE LEFT '~~BEGIN-MAIN-METRICS~~'
REPFOOTER PAGE LEFT '~~END-MAIN-METRICS~~'

select snap_id "snap",num_interval "dur_m", end_time "end",inst "inst",
	max(decode(metric_name,'Host CPU Utilization (%)', average,null)) "os_cpu",
	max(decode(metric_name,'Host CPU Utilization (%)', maxval,null)) "os_cpu_max",
	max(decode(metric_name,'Host CPU Utilization (%)', STANDARD_DEVIATION,null)) "os_cpu_sd",
	max(decode(metric_name,'Database Wait Time Ratio', round(average,1),null)) "db_wait_ratio",
	max(decode(metric_name,'Database CPU Time Ratio', round(average,1),null)) "db_cpu_ratio",
	max(decode(metric_name,'CPU Usage Per Sec', round(average/100,3),null)) "cpu_per_s",
	max(decode(metric_name,'CPU Usage Per Sec', round(STANDARD_DEVIATION/100,3),null)) "cpu_per_s_sd",
	max(decode(metric_name,'Host CPU Usage Per Sec', round(average/100,3),null)) "h_cpu_per_s",
	max(decode(metric_name,'Host CPU Usage Per Sec', round(STANDARD_DEVIATION/100,3),null)) "h_cpu_per_s_sd",
	max(decode(metric_name,'Average Active Sessions', average,null)) "aas",
	max(decode(metric_name,'Average Active Sessions', STANDARD_DEVIATION,null)) "aas_sd",
	max(decode(metric_name,'Average Active Sessions', maxval,null)) "aas_max",
	max(decode(metric_name,'Database Time Per Sec', average,null)) "db_time",
	max(decode(metric_name,'Database Time Per Sec',	STANDARD_DEVIATION,null)) "db_time_sd",
	max(decode(metric_name,'SQL Service Response Time', average,null)) "sql_res_t_cs",
	max(decode(metric_name,'Background Time Per Sec', average,null)) "bkgd_t_per_s",
	max(decode(metric_name,'Logons Per Sec', average,null)) "logons_s",
	max(decode(metric_name,'Current Logons Count', average,null)) "logons_total",
	max(decode(metric_name,'Executions Per Sec', average,null)) "exec_s",
	max(decode(metric_name,'Hard Parse Count Per Sec', average,null)) "hard_p_s",
	max(decode(metric_name,'Logical Reads Per Sec', average,null)) "l_reads_s",
	max(decode(metric_name,'User Commits Per Sec', average,null)) "commits_s",
	max(decode(metric_name,'Physical Read Total Bytes Per Sec', round((average)/1024/1024,1),null)) "read_mb_s",
	max(decode(metric_name,'Physical Read Total Bytes Per Sec', round((maxval)/1024/1024,1),null)) "read_mb_s_max",
	max(decode(metric_name,'Physical Read Total IO Requests Per Sec', average,null)) "read_iops",
	max(decode(metric_name,'Physical Read Total IO Requests Per Sec', maxval,null)) "read_iops_max",
	max(decode(metric_name,'Physical Reads Per Sec', average,null)) "read_bks",
	max(decode(metric_name,'Physical Reads Direct Per Sec', average,null)) "read_bks_direct",
	max(decode(metric_name,'Physical Write Total Bytes Per Sec', round((average)/1024/1024,1),null)) "write_mb_s",
	max(decode(metric_name,'Physical Write Total Bytes Per Sec', round((maxval)/1024/1024,1),null)) "write_mb_s_max",
	max(decode(metric_name,'Physical Write Total IO Requests Per Sec', average,null)) "write_iops",
	max(decode(metric_name,'Physical Write Total IO Requests Per Sec', maxval,null)) "write_iops_max",
	max(decode(metric_name,'Physical Writes Per Sec', average,null)) "write_bks",
	max(decode(metric_name,'Physical Writes Direct Per Sec', average,null)) "write_bks_direct",
	max(decode(metric_name,'Redo Generated Per Sec', round((average)/1024/1024,1),null)) "redo_mb_s",
	max(decode(metric_name,'DB Block Gets Per Sec', average,null)) "db_block_gets_s",
	max(decode(metric_name,'DB Block Changes Per Sec', average,null)) "db_block_changes_s",
	max(decode(metric_name,'GC CR Block Received Per Second', average,null)) "gc_cr_rec_s",
	max(decode(metric_name,'GC Current Block Received Per Second', average,null)) "gc_cu_rec_s",
	max(decode(metric_name,'Global Cache Average CR Get Time', average,null)) "gc_cr_get_cs",
	max(decode(metric_name,'Global Cache Average Current Get Time', average,null)) "gc_cu_get_cs",
	max(decode(metric_name,'Global Cache Blocks Corrupted', average,null)) "gc_bk_corrupted",
	max(decode(metric_name,'Global Cache Blocks Lost', average,null)) "gc_bk_lost",
	max(decode(metric_name,'Active Parallel Sessions', average,null)) "px_sess",
	max(decode(metric_name,'Active Serial Sessions', average,null)) "se_sess",
	max(decode(metric_name,'Average Synchronous Single-Block Read Latency', average,null)) "s_blk_r_lat",
	max(decode(metric_name,'Cell Physical IO Interconnect Bytes', round((average)/1024/1024,1),null)) "cell_io_int_mb",
	max(decode(metric_name,'Cell Physical IO Interconnect Bytes', round((maxval)/1024/1024,1),null)) "cell_io_int_mb_max"
from (
	select snap_id,
		num_interval,
		to_char(end_time,'YY/MM/DD HH24:MI') end_time,
		instance_number inst,metric_name,
		round(average,1) average,
		round(maxval,1) maxval,
		round(standard_deviation,1) standard_deviation
	from dba_hist_sysmetric_summary
	where dbid = &DBID
		and snap_id between &SNAP_ID_MIN and &SNAP_ID_MAX
		--and snap_id = 920
		--and instance_number = 4
		and metric_name in (
			'Host CPU Utilization (%)',
			'CPU Usage Per Sec',
			'Host CPU Usage Per Sec',
			'Average Active Sessions',
			'Database Time Per Sec',
			'Executions Per Sec',
			'Hard Parse Count Per Sec',
			'Logical Reads Per Sec',
			'Logons Per Sec',
			'Physical Read Total Bytes Per Sec',
			'Physical Read Total IO Requests Per Sec',
			'Physical Reads Per Sec',
			'Physical Write Total Bytes Per Sec',
			'Redo Generated Per Sec',
			'User Commits Per Sec',
			'Current Logons Count',
			'DB Block Gets Per Sec',
			'DB Block Changes Per Sec',
			'Database Wait Time Ratio',
			'Database CPU Time Ratio',
			'SQL Service Response Time',
			'Background Time Per Sec',
			'Physical Write Total IO Requests Per Sec',
			'Physical Writes Per Sec',
			'Physical Writes Direct Per Sec',
			'Physical Writes Direct Lobs Per Sec',
			'Physical Reads Direct Per Sec',
			'Physical Reads Direct Lobs Per Sec',
			'GC CR Block Received Per Second',
			'GC Current Block Received Per Second',
			'Global Cache Average CR Get Time',
			'Global Cache Average Current Get Time',
			'Global Cache Blocks Corrupted',
			'Global Cache Blocks Lost',
			'Active Parallel Sessions',
			'Active Serial Sessions',
			'Average Synchronous Single-Block Read Latency',
			'Cell Physical IO Interconnect Bytes'
			)
	)
group by snap_id,num_interval, end_time,inst
order by snap_id, end_time,inst;

spool off

-- ##############################################################################################
set termout on
prompt Extracting SqlNet metrics...
set termout off
spool &SPOOL_FILE_NAME append;

prompt ------------------------- BEGIN-SQLNET-METRICS -------------------------------------------

REPHEADER PAGE LEFT '~~BEGIN-SQLNET-METRICS~~'
REPFOOTER PAGE LEFT '~~END-SQLNET-METRICS~~'

select snap_id "snap",inst "inst",
	max(decode(stat_name,'Requests to/from client', value,null)) "rqsts_to_from_client",
	max(decode(stat_name,'SQL*Net roundtrips to/from client', value,null)) "sqlnet_to_from_client",
	max(decode(stat_name,'bytes received via SQL*Net from client', value,null)) "sqlnet_bytes_received",	-- "sqlnet_bytes_received_from_client"
	max(decode(stat_name,'bytes sent via SQL*Net to client', value,null)) "sqlnet_bytes_sent",		-- "sqlnet_bytes_sent_to_client"
	max(decode(stat_name,'bytes via SQL*Net vector from client', value,null)) "sqlnet_bytes_vector_from",	-- "sqlnet_bytes_vector_from_client"
	max(decode(stat_name,'bytes via SQL*Net vector to client', value,null)) "sqlnet_bytes_vector_to"	-- "sqlnet_bytes_vector_to_client"
from (
	select snap_id,instance_number inst
		,stat_name, value
	from dba_hist_sysstat
	where dbid = &DBID
		and snap_id between &SNAP_ID_MIN and &SNAP_ID_MAX
		--and snap_id = 920
		--and instance_number = 4
		and stat_name in (
			'Requests to/from client',
			'SQL*Net roundtrips to/from client',
			'bytes received via SQL*Net from client',
			'bytes sent via SQL*Net to client',
			'bytes via SQL*Net vector from client',
			'bytes via SQL*Net vector to client'
			)
	)
group by snap_id, inst
order by snap_id, inst;

spool off

-- ##############################################################################################
set termout on
prompt Extracting DB parameters...
set termout off
spool &SPOOL_FILE_NAME append;

prompt ------------------------- BEGIN-DATABASE-PARAMETERS -------------------------------------

column display_value format a50
set wrap off
REPHEADER PAGE LEFT '~~BEGIN-DATABASE-PARAMETERS~~'
REPFOOTER PAGE LEFT '~~END-DATABASE-PARAMETERS~~'

select o.INSTANCE_NUMBER, o.PARAMETER_NAME, o.VALUE
from DBA_HIST_PARAMETER o
where o.dbid = &DBID
	and o.snap_id = (select max(i.snap_id) from dba_hist_osstat i where i.dbid = o.dbid and i.instance_number = o.instance_number)
	and o.PARAMETER_NAME not in ('local_listener','service_names','remote_listener','db_domain','cluster_interconnects')
order by 1, 2;

spool off

-- ##############################################################################################
--
-- The snap_timezone column in the dba_hist_snapshot table was introduced in 11.2.0.2
--
set termout on
prompt Extracting DB AWR snapshots timezone information...
set termout off
spool &SPOOL_FILE_NAME append;

prompt ------------------------- BEGIN-SNAP-HISTORY-TZ ------------------------------------------

REPHEADER OFF
REPFOOTER OFF

define SNAP_HISTORY_QUERY = ' '
column :SNAP_HISTORY_QUERY_1 new_value SNAP_HISTORY_QUERY noprint
variable SNAP_HISTORY_QUERY_1 varchar2(4000)

begin
	if :DB_VERSION_1 >= 11.2 then
		:SNAP_HISTORY_QUERY_1 := q'! snap,end_time,inst,minutes_diff_from_utc
		from (
			SELECT s.snap_id AS snap
				,TO_CHAR(s.end_interval_time, 'YYYY/MM/DD HH24:MI') AS end_time
				,s.instance_number AS inst
				,EXTRACT(HOUR FROM s.snap_timezone) * 60 + EXTRACT(MINUTE FROM s.snap_timezone) AS minutes_diff_from_utc
			FROM dba_hist_snapshot s
			WHERE s.dbid = &DBID
				AND s.snap_id BETWEEN &SNAP_ID_MIN and &SNAP_ID_MAX
			)
		ORDER BY snap, end_time, inst !';
	else
		:SNAP_HISTORY_QUERY_1 := q'! 'column not in this version' from dual !';
	end if;
end;
/

select :SNAP_HISTORY_QUERY_1 from dual;

REPHEADER PAGE LEFT '~~BEGIN-SNAP-HISTORY-TZ~~'
REPFOOTER PAGE LEFT '~~END-SNAP-HISTORY-TZ~~'
select &SNAP_HISTORY_QUERY ;

spool off

-- ##############################################################################################
set termout on
prompt Extracting DB sessions..
set termout off
spool &SPOOL_FILE_NAME append;

prompt ------------------------- BEGIN-AVERAGE-ACTIVE-SESSIONS ----------------------------------

REPHEADER PAGE LEFT '~~BEGIN-AVERAGE-ACTIVE-SESSIONS~~'
REPFOOTER PAGE LEFT '~~END-AVERAGE-ACTIVE-SESSIONS~~'
column wait_class format a20

select snap_id,
	wait_class,
	round (sum (pSec), 2) avg_sess
from
	(select snap_id,
		wait_class,
		p_tmfg / 1000000 / ela pSec
	from
		(select (cast (s.end_interval_time as date) - cast (s.begin_interval_time as date)) * 24 *
			3600 ela,
			s.snap_id,
			wait_class,
			e.event_name,
			case when s.begin_interval_time = s.startup_time
				-- compare to e.time_waited_micro_fg for 10.2?
				then e.&T_WAITED_MICRO_COL
				ELSE e.&T_WAITED_MICRO_COL - lag (e.&T_WAITED_MICRO_COL) over (partition BY
					event_id, e.dbid, e.instance_number, s.startup_time order by e.snap_id)
			END p_tmfg
		FROM dba_hist_snapshot s,
			dba_hist_system_event e
		WHERE s.dbid = e.dbid
			AND s.dbid = to_number(&DBID)
			AND e.dbid = to_number(&DBID)
			AND s.instance_number = e.instance_number
			AND s.snap_id = e.snap_id
			AND s.snap_id BETWEEN to_number(&SNAP_ID_MIN) and to_number(&SNAP_ID_MAX)
			AND e.snap_id BETWEEN to_number(&SNAP_ID_MIN) and to_number(&SNAP_ID_MAX)
			AND e.wait_class != 'Idle'
		UNION ALL
		select (cast (s.end_interval_time as date) - cast (s.begin_interval_time as date)) * 24 *
			3600 ela,
			s.snap_id,
			t.stat_name wait_class,
			t.stat_name event_name,
			case when s.begin_interval_time = s.startup_time
				then t.value
				else t.value - lag (value) over (partition by stat_id, t.dbid, t.instance_number,
					s.startup_time order by t.snap_id)
			end p_tmfg
		from dba_hist_snapshot s,
			dba_hist_sys_time_model t
		where s.dbid = t.dbid
			and s.dbid = to_number(&DBID)
			and s.instance_number = t.instance_number
			and s.snap_id = t.snap_id
			and s.snap_id between to_number(&SNAP_ID_MIN) and to_number(&SNAP_ID_MAX)
			and t.snap_id between to_number(&SNAP_ID_MIN) and to_number(&SNAP_ID_MAX)
			and t.stat_name = 'DB CPU'
		)
	where p_tmfg is not null
)
GROUP BY snap_id,
	wait_class
ORDER BY snap_id,
	wait_class;

spool off

-- ##############################################################################################
set termout on
prompt Extracting Histogram by Wait Event...
set termout off
spool &SPOOL_FILE_NAME append;

prompt ------------------------- BEGIN-IO-WAIT-HISTOGRAM ----------------------------------------

REPHEADER OFF
REPFOOTER OFF

define HISTOGRAM_QUERY = ' '
column :HISTOGRAM_QUERY_1 new_value HISTOGRAM_QUERY noprint
variable HISTOGRAM_QUERY_1 varchar2(4000)

begin
	if :DB_VERSION_1 >= 11.1 then
		:HISTOGRAM_QUERY_1 := q'! snap_id,wait_class,event_name,wait_time_milli,sum(wait_count) wait_count
		from (
			SELECT s.snap_id,
				wait_class,
				h.event_name,
				wait_time_milli,
				CASE WHEN s.begin_interval_time = s.startup_time
					THEN h.wait_count
					ELSE h.wait_count - lag (h.wait_count) over (partition BY
						event_id,wait_time_milli, h.dbid, h.instance_number, s.startup_time order by h.snap_id)
				END wait_count
			FROM dba_hist_snapshot s,
				DBA_HIST_event_histogram h
			WHERE s.dbid = h.dbid
				AND s.dbid = &DBID
				AND s.instance_number = h.instance_number
				AND s.snap_id = h.snap_id
				AND s.snap_id BETWEEN &SNAP_ID_MIN and &SNAP_ID_MAX
				and event_name in ('cell single block physical read','cell list of blocks physical read','cell multiblock physical read',
					'db file sequential read','db file scattered read',
					'log file parallel write','log file sync','free buffer wait')
			)
		where wait_count > 0
		group by snap_id,wait_class,event_name,wait_time_milli
		order by snap_id,event_name,wait_time_milli !';
	else
		:HISTOGRAM_QUERY_1 := q'! 'table not in this version' from dual !';
	end if;

end;
/

select :HISTOGRAM_QUERY_1 from dual;

REPHEADER PAGE LEFT '~~BEGIN-IO-WAIT-HISTOGRAM~~'
REPFOOTER PAGE LEFT '~~END-IO-WAIT-HISTOGRAM~~'
COLUMN EVENT_NAME FORMAT A37
select &HISTOGRAM_QUERY ;


spool off

-- ##############################################################################################
set termout on
prompt Extracting IO segment statistics by object type...
set termout off
spool &SPOOL_FILE_NAME append;

prompt ------------------------- BEGIN-IO-OBJECT-TYPE -------------------------------------------

REPHEADER PAGE LEFT '~~BEGIN-IO-OBJECT-TYPE~~'
REPFOOTER PAGE LEFT '~~END-IO-OBJECT-TYPE~~'

column object_type format a15

select s.snap_id,regexp_replace(o.OBJECT_TYPE,'^(TABLE|INDEX).*','\1') OBJECT_TYPE,
	round((sum(s.LOGICAL_READS_DELTA)* &DB_BLOCK_SIZE)/1024/1024/1024,1) logical_read_gb,
	round((sum(s.PHYSICAL_READS_DELTA)* &DB_BLOCK_SIZE)/1024/1024/1024,1) physical_read_gb,
	round((sum(s.PHYSICAL_WRITES_DELTA)* &DB_BLOCK_SIZE)/1024/1024/1024,1) physical_write_gb,
	round((sum(s.SPACE_ALLOCATED_DELTA)/1024/1024/1024),1) GB_ADDED
from
	DBA_HIST_SEG_STAT_OBJ o,
	DBA_HIST_SEG_STAT s
	where o.dbid = s.dbid
		and o.ts# = s.ts#
		and o.obj# = s.obj#
		and o.dataobj# = s.dataobj#
		and o.dbid = &DBID
		and s.snap_id between &SNAP_ID_MIN and &SNAP_ID_MAX
		and OBJECT_TYPE != 'UNDEFINED'
group by s.snap_id,regexp_replace(o.OBJECT_TYPE,'^(TABLE|INDEX).*','\1')
order by snap_id,object_type;

spool off

-- ##############################################################################################
set termout on
prompt Extracting IO statistics by function...
set termout off
spool &SPOOL_FILE_NAME append;

prompt ------------------------- BEGIN-IOSTAT-BY-FUNCTION ---------------------------------------

REPHEADER OFF
REPFOOTER OFF

define IOSTAT_FN_QUERY = ' '
column :IOSTAT_FN_QUERY_1 new_value IOSTAT_FN_QUERY noprint
variable IOSTAT_FN_QUERY_1 varchar2(4000)

begin
	if :DB_VERSION_1 >= 11.1 then
		:IOSTAT_FN_QUERY_1 := q'! snap_id,
			function_name,
			SUM(sm_r_reqs) sm_r_reqs,
			SUM(sm_w_reqs) sm_w_reqs,
			SUM(lg_r_reqs) lg_r_reqs,
			SUM(lg_w_reqs) lg_w_reqs
		FROM
			(SELECT s.snap_id ,
				s.instance_number ,
				s.dbid ,
				FUNCTION_NAME,
				CASE
					WHEN s.begin_interval_time = s.startup_time
					THEN NVL(fn.SMALL_READ_REQS,0)
					ELSE NVL(fn.SMALL_READ_REQS,0) - lag(NVL(fn.SMALL_READ_REQS,0),1) over (partition BY fn.FUNCTION_NAME , fn.instance_number , fn.dbid , s.startup_time order by fn.snap_id)
				END sm_r_reqs,
				CASE
					WHEN s.begin_interval_time = s.startup_time
					THEN NVL(fn.SMALL_WRITE_REQS,0)
					ELSE NVL(fn.SMALL_WRITE_REQS,0) - lag(NVL(fn.SMALL_WRITE_REQS,0),1) over (partition BY fn.FUNCTION_NAME , fn.instance_number , fn.dbid , s.startup_time order by fn.snap_id)
				END sm_w_reqs,
				CASE
					WHEN s.begin_interval_time = s.startup_time
					THEN NVL(fn.LARGE_READ_REQS,0)
					ELSE NVL(fn.LARGE_READ_REQS,0) - lag(NVL(fn.LARGE_READ_REQS,0),1) over (partition BY fn.FUNCTION_NAME , fn.instance_number , fn.dbid , s.startup_time order by fn.snap_id)
				END lg_r_reqs,
				CASE
					WHEN s.begin_interval_time = s.startup_time
					THEN NVL(fn.LARGE_WRITE_REQS,0)
					ELSE NVL(fn.LARGE_WRITE_REQS,0) - lag(NVL(fn.LARGE_WRITE_REQS,0),1) over (partition BY fn.FUNCTION_NAME , fn.instance_number , fn.dbid , s.startup_time order by fn.snap_id)
				END lg_w_reqs
			FROM dba_hist_snapshot s ,
				DBA_HIST_IOSTAT_FUNCTION fn
			WHERE s.dbid = fn.dbid
				AND s.dbid = &DBID
				AND s.snap_id BETWEEN &SNAP_ID_MIN and &SNAP_ID_MAX
				AND s.instance_number = fn.instance_number
				AND s.snap_id = fn.snap_id
			)
		GROUP BY snap_id,
			function_name
			having SUM(sm_r_reqs) is not null
		order by snap_id !';
	else
		:IOSTAT_FN_QUERY_1 := q'! 'table not in this version' from dual !';
	end if;
end;
/

select :IOSTAT_FN_QUERY_1 from dual;

REPHEADER PAGE LEFT '~~BEGIN-IOSTAT-BY-FUNCTION~~'
REPFOOTER PAGE LEFT '~~END-IOSTAT-BY-FUNCTION~~'

column function_name format a22
select &IOSTAT_FN_QUERY ;

spool off

-- ##############################################################################################
set termout on
prompt Extracting Waits by event...
set termout off
spool &SPOOL_FILE_NAME append;

prompt ------------------------- BEGIN-TOP-N-TIMED-EVENTS ---------------------------------------

REPHEADER PAGE LEFT '~~BEGIN-TOP-N-TIMED-EVENTS~~'
REPFOOTER PAGE LEFT '~~END-TOP-N-TIMED-EVENTS~~'

column event_name format a60

select snap_id,
	wait_class,
	event_name,
	pctdbt,
	total_time_s
from
	(select a.snap_id,
		wait_class,
		event_name,
		b.dbt,
		round(sum(a.ttm) /b.dbt*100,2) pctdbt,
		sum(a.ttm) total_time_s,
		dense_rank() over (partition by a.snap_id order by sum(a.ttm)/b.dbt*100 desc nulls last) rnk
	from
		(select snap_id,
			wait_class,
			event_name,
			ttm
		from
			(select
				/*+ qb_name(systemevents) */
				(cast (s.end_interval_time as date) - cast (s.begin_interval_time as date)) * 24 * 3600 ela,
				s.snap_id,
				wait_class,
				e.event_name,
				case
					when s.begin_interval_time = s.startup_time
					then e.time_waited_micro
					else e.time_waited_micro - lag (e.time_waited_micro ) over (partition by e.instance_number,e.event_name order by e.snap_id)
				end ttm
			from dba_hist_snapshot s,
				dba_hist_system_event e
			where s.dbid = e.dbid
				and s.dbid = &DBID
				and s.instance_number = e.instance_number
				and s.snap_id = e.snap_id
				and s.snap_id between &SNAP_ID_MIN and &SNAP_ID_MAX
				and e.wait_class != 'Idle'
			union all
			select
				/*+ qb_name(dbcpu) */
				(cast (s.end_interval_time as date) - cast (s.begin_interval_time as date)) * 24 * 3600 ela,
				s.snap_id,
				t.stat_name wait_class,
				t.stat_name event_name,
				case
					when s.begin_interval_time = s.startup_time
					then t.value
					else t.value - lag (t.value ) over (partition by s.instance_number order by s.snap_id)
				end ttm
			from dba_hist_snapshot s,
				dba_hist_sys_time_model t
			where s.dbid = t.dbid
				and s.dbid = &DBID
				and s.instance_number = t.instance_number
				and s.snap_id = t.snap_id
				and s.snap_id between &SNAP_ID_MIN and &SNAP_ID_MAX
				and t.stat_name = 'DB CPU'
			)
		) a,
		(select snap_id,
			sum(dbt) dbt
		from
			(select
				/*+ qb_name(dbtime) */
				s.snap_id,
				t.instance_number,
				t.stat_name nm,
				case
					when s.begin_interval_time = s.startup_time
					then t.value
					else t.value - lag (t.value ) over (partition by s.instance_number order by s.snap_id)
				end dbt
			from dba_hist_snapshot s,
				dba_hist_sys_time_model t
			where s.dbid = t.dbid
				and s.dbid = &DBID
				and s.instance_number = t.instance_number
				and s.snap_id = t.snap_id
				and s.snap_id between &SNAP_ID_MIN and &SNAP_ID_MAX
				and t.stat_name = 'DB time'
				order by s.snap_id,
				s.instance_number
			)
		group by snap_id
		having sum(dbt) > 0
		) b
	where a.snap_id = b.snap_id
	group by a.snap_id,
		a.wait_class,
		a.event_name,
		b.dbt
	)
where pctdbt > 0
	and rnk <= 5
order by snap_id,
	pctdbt desc;

REPHEADER OFF
REPFOOTER OFF

spool off

-- ##############################################################################################
set termout on
prompt Extracting Host IO statistics...
set termout off
spool &SPOOL_FILE_NAME append;

prompt ------------------------- BEGIN-SYSSTAT --------------------------------------------------

REPHEADER PAGE LEFT '~~BEGIN-SYSSTAT~~'
REPFOOTER PAGE LEFT '~~END-SYSSTAT~~'

column event_name format a60

select SNAP_ID,
	max(decode(event_name,'cell flash cache read hits', event_val_diff,null)) "cell_flash_hits",
	max(decode(event_name,'physical read total IO requests', event_val_diff,null)) "read_iops",
	round(max(decode(event_name,'physical read total bytes', event_val_diff,null))/1024/1024,1) "read_mb",
	round(max(decode(event_name,'physical read total bytes optimized', event_val_diff,null))/1024/1024,1) "read_mb_opt",
	round(max(decode(event_name,'cell physical IO interconnect bytes', event_val_diff,null))/1024/1024,1) "cell_int_mb",
	round(max(decode(event_name,'cell physical IO interconnect bytes returned by smart scan', event_val_diff,null))/1024/1024,1) "cell_int_ss_mb",
	max(decode(event_name,'EHCC Conventional DMLs', event_val_diff,null)) "ehcc_con_dmls"
from
	(select snap_id,
		event_name,
		round(sum(val_per_s),1) event_val_diff
	from
		(select snap_id,
			instance_number,
			event_name,
			event_val_diff,
			(event_val_diff/ela) val_per_s
		from
			(select (cast (s.end_interval_time as date) - cast (s.begin_interval_time as date)) * 24 * 3600 ela,
				s.snap_id,
				s.instance_number,
				t.stat_name wait_class,
				t.stat_name event_name,
				case
					when s.begin_interval_time = s.startup_time
					then t.value
					else t.value - lag (value) over (partition by stat_id, t.dbid, t.instance_number, s.startup_time order by t.snap_id)
				end event_val_diff
			from dba_hist_snapshot s,
				dba_hist_sysstat t
			where s.dbid = t.dbid
				and s.dbid = &DBID
				and s.instance_number = t.instance_number
					and s.snap_id = t.snap_id
				and s.snap_id between &SNAP_ID_MIN and &SNAP_ID_MAX
				and t.snap_id between &SNAP_ID_MIN and &SNAP_ID_MAX
				and t.stat_name in (
					'cell flash cache read hits',
					'physical read total IO requests',
					'cell physical IO bytes saved by storage index',
					'EHCC Conventional DMLs',
					'cell physical IO interconnect bytes',
					'cell physical IO interconnect bytes returned by smart scan',
					'physical read total bytes',
					'physical read total bytes optimized'
					)
			)
		where event_val_diff is not null
		)
	group by snap_id,
		event_name
	)
group by snap_id
order by SNAP_ID asc;

spool off

-- ##############################################################################################
set termout on
prompt Extracting Segment IO historical statistics...
set termout off
spool &SPOOL_FILE_NAME append;

prompt ------------------------- BEGIN-SEGMENT-IO -----------------------------------------------

REPHEADER PAGE LEFT '~~BEGIN-SEGMENT-IO~~'
REPFOOTER PAGE LEFT '~~END-SEGMENT-IO~~'

define segment_io_schema_exclusions = "'SYS','SYSTEM','SYSMAN','OUTLN','DBSNMP','DIP','EXFSYS','MDSYS','ORACLE_OCM','ORDPLUGINS','ORDSYS','WMSYS','XDB'"

with
	v_uptime as (
		select CASE WHEN :DB_VERSION_1 > 11.2
				THEN /*+ MATERIALIZE NO_MERGE PARALLEL(&PARALELLISM_DEGREE) */ count(1)
				ELSE count(1)
				END as inst_cnt
			,to_char(systimestamp at time zone 'UTC', 'YYYY/MON/DD HH24:MI:SS') as report_time_utc
			,to_char(min(i.startup_time), 'YYYY/MON/DD HH24:MI:SS') as startup_time
			,trunc(min(sysdate - i.startup_time) * 24 * 60 *60) as uptime_sec
		from gv$instance i, gv$database d
		where i.inst_id = d.inst_id)
	,v_segstats as (
		select CASE WHEN :DB_VERSION_1 > 11.2
				THEN /*+ MATERIALIZE NO_MERGE PARALLEL(&PARALELLISM_DEGREE) */ round(segs.bytes /1024 /1024 /1024, 4)
				ELSE round(segs.bytes /1024 /1024 /1024, 4)
				END as partition_size_gb
			,round(sum(segs.bytes /1024 /1024 /1024) over(partition by segs.owner, segs.segment_type, segs.segment_name), 3) as seg_size_gb
			,case when segs.segment_name is not null then physical_reads else 0 end as seg_physical_reads
			,case when segs.segment_name is not null then physical_writes else 0 end as seg_physical_writes
			,case when segs.segment_name is not null then physical_reads_direct else 0 end as seg_physical_reads_direct
			,case when segs.segment_name is not null then physical_writes_direct else 0 end as seg_physical_writes_direct
			,sum(case when segs.segment_name is not null then physical_reads else 0 end) over () as seg_physical_reads_tot
			,sum(case when segs.segment_name is not null then physical_writes else 0 end) over () as seg_physical_writes_tot
			,sum(physical_reads)over ()as physical_reads_tot
			,sum(physical_writes) over ()as physical_writes_tot
			,case when segs.segment_name is not null then 1 else 0 end as segment_present_flg
			, vss.*
		from (
			select CASE WHEN :DB_VERSION_1 > 11.2
					THEN/*+ MATERIALIZE NO_MERGE PARALLEL(&PARALELLISM_DEGREE) */stats.owner
					ELSE stats.owner
					END as owner,
				stats.object_type,
				stats.object_name,
				stats.tablespace_name,
				stats.subobject_name,
				stats.statistic_name, stats.value
			from dba_tablespaces ts
				,gv$segment_statistics stats
			where stats.owner not in (&segment_io_schema_exclusions)
				and stats.tablespace_name= ts.tablespace_name
				and ts.contents <> 'TEMPORARY'
				)
		pivot (
			sum(value) for statistic_name in (
				'physical reads' as "PHYSICAL_READS",
				'physical reads direct'as "PHYSICAL_READS_DIRECT",
				'physical writes'as "PHYSICAL_WRITES",
				'physical writes direct' as "PHYSICAL_WRITES_DIRECT"
				)
			) vss
			,dba_segments segs
		where vss.subobject_name = segs.partition_name(+)
			and vss.tablespace_name = segs.tablespace_name (+)
			and vss.object_type = segs.segment_type(+)
			and vss.object_name = segs.segment_name(+)
			and vss.owner = segs.owner (+)
		--ORDER BY vss.owner, vss.object_type, vss.object_name, vss.subobject_name
		)
	,v_dbsize as (
		select CASE WHEN :DB_VERSION_1 > 11.2
				THEN /*+ MATERIALIZE NO_MERGE PARALLEL(&PARALELLISM_DEGREE) */ round(sum(bytes / 1024 /1024 /1024), 3)
				ELSE round(sum(bytes / 1024 /1024 /1024), 3)
				END as db_size_gb
		from dba_segments)
	,v_diskdfalloc as (
		select CASE WHEN :DB_VERSION_1 > 11.2
				THEN /*+ MATERIALIZE NO_MERGE PARALLEL(&PARALELLISM_DEGREE) */ round(sum(bytes) / 1024 / 1024 /1024, 3)
				ELSE round(sum(bytes) / 1024 / 1024 /1024, 3)
				END as db_disk_space_alloc_gb
		from dba_data_files)
	,v_disktempalloc as (
		select CASE WHEN :DB_VERSION_1 > 11.2
				THEN /*+ MATERIALIZE NO_MERGE PARALLEL(&PARALELLISM_DEGREE) */ round(sum(bytes) /1024 /1024 /1024, 3)
				ELSE round(sum(bytes) /1024 /1024 /1024, 3)
				END as db_temp_space_alloc_gb
		from dba_temp_files)
	select v.*
		,decode(v.seg_physical_io_tot, 0, 0, round((v.seg_physical_io_running / (v.seg_physical_io_tot)) * 100, 5)) as run_seg_phys_io_pct_of_tot
		,decode(v.physical_io_tot, 0, 0, round((v.physical_io_running / (v.physical_io_tot)) * 100, 5)) as run_physcial_io_pct_of_tot
		,count(1) over() as rows_tot
	from (
		select CASE WHEN :DB_VERSION_1 > 11.2
				THEN /*+ MATERIALIZE NO_MERGE ORDERED USE_HASH(stats) PARALLEL(&PARALELLISM_DEGREE) */ stats.owner
				ELSE stats.owner
				END as owner
			,stats.object_name
			,stats.object_type
			,stats.subobject_name
			,stats.tablespace_name
			,sum(stats.partition_size_gb) over (order by stats.physical_reads + stats.physical_writes desc, rownum) as partition_size_gb_running
			,stats.partition_size_gb
			,stats.seg_size_gb
			,db_size_gb
			,db_disk_space_alloc_gb
			,db_temp_space_alloc_gb
			,stats.seg_physical_reads, stats.seg_physical_writes
			,stats.seg_physical_reads + stats.seg_physical_writes as seg_physical_io
			,sum( stats.seg_physical_reads + stats.seg_physical_writes) over (order by stats.seg_physical_reads + stats.seg_physical_writes desc, rownum) as seg_physical_io_running
			,stats.seg_physical_reads_tot + stats.seg_physical_writes_tot as seg_physical_io_tot
			,stats.physical_reads, stats.physical_writes
			,stats.physical_reads + stats.physical_writes as physical_io
			,sum( stats.physical_reads + stats.physical_writes) over (order by stats.physical_reads + stats.physical_writes desc, rownum) as physical_io_running
			,stats.physical_reads_tot + stats.physical_writes_tot as physical_io_tot
			,stats.physical_reads_direct, stats.physical_writes_direct
			,stats.seg_physical_reads_direct, stats.seg_physical_writes_direct
			,inst_cnt, startup_time, report_time_utc, uptime_sec, stats.segment_present_flg
		from v_uptime
			,v_dbsize
			,v_diskdfalloc
			,v_disktempalloc
			,v_segstats stats
		) v
	where rownum <= 1 or decode(v.seg_physical_io_tot, 0, 0, round((v.seg_physical_io_running / (v.seg_physical_io_tot)) * 100, 3)) < 101
	order by seg_physical_io desc;

spool off

-- ##############################################################################################
set termout on
prompt Extracting SQL statements...
set termout off
spool &SPOOL_FILE_NAME append;

prompt ------------------------- BEGIN-TOP-SQL-SUMMARY ------------------------------------------

REPHEADER PAGE LEFT '~~BEGIN-TOP-SQL-SUMMARY~~'
REPFOOTER PAGE LEFT '~~END-TOP-SQL-SUMMARY~~'

select * from (
	select substr(regexp_replace(s.module,'^(.+?)@.+$','\1'),1,30) module,s.action,s.sql_id,
		decode(t.command_type,11,'ALTERINDEX',15,'ALTERTABLE',170,'CALLMETHOD',9,'CREATEINDEX',1,'CREATETABLE',
			7,'DELETE',50,'EXPLAIN',2,'INSERT',26,'LOCKTABLE',47,'PL/SQLEXECUTE',
			3,'SELECT',6,'UPDATE',189,'UPSERT') command_name,
		PARSING_SCHEMA_NAME,
		dense_rank() over (order by sum(EXECUTIONS_DELTA) desc ) exec_rank,
		dense_rank() over (order by sum(ELAPSED_TIME_DELTA) desc ) elap_rank,
		dense_rank() over (order by sum(BUFFER_GETS_DELTA) desc ) log_reads_rank,
		dense_rank() over (order by sum(disk_reads_delta) desc ) phys_reads_rank,
		sum(EXECUTIONS_DELTA) execs,
		sum(ELAPSED_TIME_DELTA) elap,
		sum(BUFFER_GETS_DELTA) log_reads,
		round(sum(disk_reads_delta * &DB_BLOCK_SIZE)/1024/1024/1024) phy_read_gb,
		count(distinct plan_hash_value) plan_count,
		sum(px_servers_execs_delta) px_servers_execs
	from dba_hist_sqlstat s,dba_hist_sqltext t
	where s.dbid = &DBID
		and s.snap_id between &SNAP_ID_MIN and &SNAP_ID_MAX
		and s.dbid = t.dbid
		and s.sql_id = t.sql_id
		and PARSING_SCHEMA_NAME not in ('SYS','DBSNMP','SYSMAN')
	group by s.module,s.action,s.sql_id,t.command_type,PARSING_SCHEMA_NAME)
where elap_rank <= &SQL_TOP_N
	or phys_reads_rank <= &SQL_TOP_N
	or log_reads_rank <= &SQL_TOP_N
	or exec_rank <= &SQL_TOP_N
order by elap_rank asc nulls last;

spool off

-- ##############################################################################################
set termout on
prompt Extracting SQL statements by snapshot...
set termout off
spool &SPOOL_FILE_NAME append;

prompt ------------------------- BEGIN-TOP-SQL-BY-SNAPID ----------------------------------------

REPHEADER PAGE LEFT '~~BEGIN-TOP-SQL-BY-SNAPID~~'
REPFOOTER PAGE LEFT '~~END-TOP-SQL-BY-SNAPID~~'

column parsing_schema_name format a32
column module format a33
column action format a33

select * from (
	select s.snap_id,PARSING_SCHEMA_NAME,PLAN_HASH_VALUE plan_hash,substr(regexp_replace(s.module,'^(.+?)@.+$','\1'),1,30) module,
		substr(s.action,1,30) action,
		s.sql_id,
		decode(t.command_type,11,'ALTERINDEX',15,'ALTERTABLE',170,'CALLMETHOD',9,'CREATEINDEX',1,'CREATETABLE',
			7,'DELETE',50,'EXPLAIN',2,'INSERT',26,'LOCKTABLE',47,'PL/SQLEXECUTE',
			3,'SELECT',6,'UPDATE',189,'UPSERT') command_name,sum(EXECUTIONS_DELTA) execs,sum(BUFFER_GETS_DELTA) buffer_gets,sum(ROWS_PROCESSED_DELTA) rows_proc,
		round(sum(CPU_TIME_DELTA)/1000000,1) cpu_t_s,round(sum(ELAPSED_TIME_DELTA)/1000000,1) elap_s,
		round(sum(disk_reads_delta * &DB_BLOCK_SIZE)/1024/1024,1) read_mb,round(sum(IOWAIT_DELTA)/1000000,1) io_wait,
		dense_rank() over (partition by s.snap_id order by sum(ELAPSED_TIME_DELTA) desc ) elap_rank,
		case when max(PLAN_HASH_VALUE) = lag(max(PLAN_HASH_VALUE), 1, 0) over (partition by s.sql_id order by s.snap_id asc)
			or lag(max(PLAN_HASH_VALUE), 1, 0) over (partition by s.sql_id order by s.snap_id asc) = 0 then 0
			when count(distinct PLAN_HASH_VALUE) > 1 then 1 else 1 end plan_change,
			count(distinct PLAN_HASH_VALUE) over (partition by s.snap_id,s.sql_id ) plans,
			round(sum(disk_reads_delta * &DB_BLOCK_SIZE)/1024/1024/1024) phy_read_gb,
			sum(s.px_servers_execs_delta) px_servers_execs,
			round(sum(DIRECT_WRITES_DELTA * &DB_BLOCK_SIZE)/1024/1024/1024) direct_w_gb,
			sum(IOWAIT_DELTA) as iowait_time,
			sum(DISK_READS_DELTA) as PIO
	from dba_hist_sqlstat s,dba_hist_sqltext t
	where s.dbid = &DBID
		and s.dbid = t.dbid
		and s.sql_id = t.sql_id
		and s.snap_id between &SNAP_ID_MIN and &SNAP_ID_MAX
		and PARSING_SCHEMA_NAME not in ('SYS','DBSNMP','SYSMAN')
	group by s.snap_id, PLAN_HASH_VALUE,t.command_type,PARSING_SCHEMA_NAME,s.module,s.action, s.sql_id)
where elap_rank <= &SQL_TOP_N
order by snap_id,elap_rank asc nulls last;

spool off

-- ##############################################################################################
set termout on
prompt Extracting Row counts...
set termout off
spool &SPOOL_FILE_NAME append;
set timing off

prompt ------------------------- BEGIN-DIAGNOSTICS-ROW-COUNTS ------------------------------------

REPHEADER PAGE LEFT '~~BEGIN-DIAGNOSTICS-ROW-COUNTS~~'
REPFOOTER PAGE LEFT '~~END-DIAGNOSTICS-ROW-COUNTS~~'

select (select count('x') from dba_hist_sysmetric_summary
		where dbid = &DBID and snap_id between to_number(&SNAP_ID_MIN) and to_number(&SNAP_ID_MAX))
	as dba_hist_sysm_summ_rows,
	(select count('x') from dba_hist_sysstat
		where dbid = &DBID and snap_id between to_number(&SNAP_ID_MIN) and to_number(&SNAP_ID_MAX))
	as dba_hist_sysstat_rows,
	(select count('x') from dba_hist_parameter
		where dbid = &DBID and snap_id between to_number(&SNAP_ID_MIN) and to_number(&SNAP_ID_MAX))
	as dba_hist_parameter_rows,
	(select count('x') from dba_hist_snapshot
		where dbid = &DBID and snap_id between to_number(&SNAP_ID_MIN) and to_number(&SNAP_ID_MAX))
	as dba_hist_snapshot_rows,
	(select count('x') from dba_hist_system_event
		where dbid = &DBID and snap_id between to_number(&SNAP_ID_MIN) and to_number(&SNAP_ID_MAX))
	as dba_hist_system_event_rows,
	(select count('x') from dba_hist_sys_time_model
		where dbid = &DBID and snap_id between to_number(&SNAP_ID_MIN) and to_number(&SNAP_ID_MAX))
	as dba_hist_sys_time_model_rows,
	(select count('x') from dba_hist_seg_stat_obj
		where dbid = &DBID)
	as dba_hist_seg_stat_obj_rows,
	(select count('x') from dba_hist_iostat_function
		where dbid = &DBID and snap_id between to_number(&SNAP_ID_MIN) and to_number(&SNAP_ID_MAX))
	as dba_hist_iostat_function_rows,
	(select count('x') from dba_hist_tablespace
		where dbid = &DBID)
	as dba_hist_tablespace_rows,
	(select count('x') from dba_hist_seg_stat
		where dbid = &DBID and snap_id between to_number(&SNAP_ID_MIN) and to_number(&SNAP_ID_MAX))
	as dba_hist_seg_stat_rows,
	(select count('x') from dba_hist_tbspc_space_usage
		where dbid = &DBID and snap_id between to_number(&SNAP_ID_MIN) and to_number(&SNAP_ID_MAX))
	as dba_hist_tbspc_space_rows,
	(select count('x') from dba_hist_sqlstat
		where dbid = &DBID and snap_id between to_number(&SNAP_ID_MIN) and to_number(&SNAP_ID_MAX))
	as dba_hist_sqlstat_rows,
	(select count('x') from dba_hist_sqltext
		where dbid = &DBID)
	as dba_hist_sqltext_rows
from dual;


REPHEADER OFF
REPFOOTER OFF
TIMING STOP
spool off

set termout on
prompt
prompt Completed Extract Script!
prompt
prompt Collection File : &SPOOL_FILE_NAME
prompt
prompt --------------------------------------------------------------------------------

alter session set workarea_size_policy = AUTO;

exit
