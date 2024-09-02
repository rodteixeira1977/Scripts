/************************************************************************************************************************************
 *	Name		: zdlra_usage.sql
 *	Author		: David Robbins, Principal Solutions Engineer - Oracle Corporation
 *	Version		: 6.1.1 -(12-Jul-2024)
 *	Purpose		: Script to gather space utilization information from a ZDLRA.
 ************************************************************************************************************************************
 *	Disclaimer:
 *	-----------
 *	Although this program has been tested and used successfully, it is not supported by Oracle Support Services.
 *	It has been tested internally, however, and works as documented. We do not guarantee that it will work for you,
 *	so be sure to test it in your environment before relying on it.  We do not clam any responsibility for any problems
 *	and/or damage caused by this program.  This program comes "as is" and any use of this program is at your own risk!!
 *	Proofread this script before using it! Due to the differences in the way text editors, e-mail packages and operating systems
 *	handle text formatting (spaces, tabs and carriage returns).
 ************************************************************************************************************************************
 *	Usage:
 *	------
 *	Run as RASYS on the ZDLRA database from /radump directory. 
 *	Send the output file to your Oracle Solutions Engineer. 
 *	Remove both the script and output file from the ZDLRA.
 *
 *	This script only queries the catalog database. It does NOT make any changes.
 *
 *	This script can take about 15 minutes to run on a large ZDLRA catalog.
 *
 * 	Change Log:
 * 	-----------
 *  6.1.1 12-JUL-2024 DaveR -   Added nls_numeric_characters = ". " to handle data where the host uses "," as the decimal character.
 *
 * 	6.1.0 13-May-2024 DaveR -	Implemented bulk collection for redo queries to avoid running the RC view queries for each database in the loop.
 *								This was a signficant performance enhancement.
 *
 * 	6.0.0 26-Apr-2024 DaveR -	Added formatting to allow the output file to be read by the zdlra_sizing spreadsheet, as well as zdlra_usage.
 *								Added additional fields, including Compliance Window.
 *								Calculates total L1 and Redo usage, in addition to average daily usage.
 *								Added mask support to allow customers to mask the DBID and DB_UNIQUE_NAME.
 *								Separated Section Sizes script into its own script. 
 ***************************************************************************************************************************************/
 
--Set the decimal character to ".". This allows the output data to load into the spreadsheet correctly from systems that use "," as the decimal character.  
ALTER SESSION SET nls_numeric_characters = ". ";

SET ECHO OFF
SET TERMOUT OFF
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINES 3200 TRIMSPOOL ON
SET FEEDBACK OFF

COLUMN ra_name NEW_VALUE myra_name
SELECT SYS_CONTEXT('USERENV', 'DB_NAME') AS ra_name 
  FROM dual;

SPOOL &myra_name._usage.lst

DECLARE

	--When set to TRUE, the dbid and db_unique_name will be masked in the output file.
	--The db_key will not be masked, and can be provided to the customer to reference a specific database.
	--The customer can query the RA_DATABASE view to match the db_key to the database.
	--Without the RMAN catalog, the db_key cannot be matched to any database. It only has meaning within the catalog.
	mask					CONSTANT	 BOOLEAN := FALSE;

	--Max number of days to include in the average calculations for L1 and Redo backups.
	--Reduce it, if database characteristics have recently changed, and sizing should be based only on more recent days.
	days_included			CONSTANT NUMBER := 30;

	-- The delimitter can be changed as needed. However, do not use a comma. 
	-- The data can have embedded commas in it.
	D					   CONSTANT	CHAR := '|';  --Output file delimitter

	-------------------------------------------
	--DO NOT MODIFY VARIABLES BELOW THIS LINE--
	-------------------------------------------

	-- Script Version
	version				CONSTANT	VARCHAR2(20) := '6.1.1 - 12-JUL-2024';

	-- Script timing variables
	begin_time						DATE;
	end_time						DATE;
	total_secs						NUMBER := 0;

	--Calalog Info Variables
	cat_dbname					VARCHAR2(30);
	cat_host					VARCHAR2(30);
	cat_schema					VARCHAR2(30);
	cat_version					VARCHAR2(30);
 
	TYPE cv_typ IS REF CURSOR;
	TYPE rep_typ IS RECORD (replication_server_name		VARCHAR2(128),
							replication_server_state	VARCHAR2(21),
							protection_policy			VARCHAR2(128),
							rep_server_connect_name		VARCHAR2(128),
							proxy_http_address			VARCHAR2(519),
							proxy_timeout				NUMBER,
							sbt_library_name			VARCHAR2(128),
							sbt_library_parms			VARCHAR2(1024),
							attribute_name				VARCHAR2(128),
							attribute_parms				VARCHAR2(1024),
							wallet_path					VARCHAR2(512),
							wallet_alias				VARCHAR2(512),
							server_host					CLOB,
							max_streams					NUMBER,
							read_only					VARCHAR2(3),
							request_only				VARCHAR2(3),
							store_and_forward			VARCHAR2(3));

	cv		cv_typ;
	rep_tab	rep_typ;

	-- Cursor for building the redo log collection
	CURSOR c_brl IS
		WITH db_key_list AS
			(SELECT DISTINCT db_key 
			   FROM rc_backup_redolog
			)
		   , bs_key_list AS
			(SELECT db_key AS db_key
				  , MIN(bs_key) AS min_bs_key
				  , MAX(bs_key) AS max_bs_key
				  , MIN(first_time) AS min_first_time
				  , MAX(next_time) AS max_first_time
				  , MAX(next_time) - MIN(first_time) AS brl_days_included
			  FROM rc_backup_redolog
			 WHERE first_time >= SYSDATE - days_included
			 GROUP BY db_key
			)
		   , daily_avg AS
			(SELECT rcbsd.db_key AS db_key
				  , SUM(rcbsd.original_input_bytes) / MAX(bs_key_list.brl_days_included) AS avg_original_input_bytes
				  , SUM(rcbsd.output_bytes) / MAX(bs_key_list.brl_days_included) AS avg_output_bytes
			   FROM rc_backup_set_details rcbsd
				  , rc_backup_piece rcbp 
				  , bs_key_list 
			  WHERE rcbsd.bs_key = rcbp.bs_key
				AND rcbsd.db_key = bs_key_list.db_key
				AND rcbsd.backup_type = 'L' 
				AND rcbp.ba_access = 'Local'
				AND rcbp.status = 'A'
				AND rcbsd.bs_key BETWEEN bs_key_list.min_bs_key AND bs_key_list.max_bs_key
			 GROUP BY rcbsd.db_key
			)
		   , total_redo AS
			(SELECT rcbsd.db_key AS db_key 
				  , SUM(rcbsd.original_input_bytes) AS original_input_bytes
				  , SUM(rcbsd.output_bytes) AS output_bytes
			   FROM rc_backup_set_details rcbsd 
					,rc_backup_piece rcbp
			  WHERE rcbsd.bs_key = rcbp.bs_key
				AND rcbsd.backup_type = 'L' 
				AND rcbp.ba_access = 'Local'
				AND rcbp.status = 'A'
			 GROUP BY rcbsd.db_key
			)
		SELECT db_key_list.db_key
			 , total_redo.original_input_bytes
			 , total_redo.output_bytes
			 , daily_avg.avg_original_input_bytes
			 , daily_avg.avg_output_bytes
			 , bs_key_list.brl_days_included
		  FROM bs_key_list 
			 , daily_avg
			 , total_redo
			, db_key_list
		 WHERE db_key_list.db_key = bs_key_list.db_key (+)
		   AND db_key_list.db_key = daily_avg.db_key (+)
		   AND db_key_list.db_key = total_redo.db_key (+)
		;

	TYPE tab_brl IS TABLE OF c_brl%ROWTYPE;

	brl tab_brl;

	-- Pre-v21 replication cursor
	c_pre_v21_rep					   VARCHAR2(4000) := 'SELECT NVL(replication_server_name, ''No Replication Servers'') AS replication_server_name
																 ,replication_server_state
																 ,protection_policy
																 ,rep_server_connect_name
																 ,proxy_http_address
																 ,proxy_timeout
																 ,sbt_library_name
																 ,sbt_library_parms
																 ,attribute_name
																 ,attribute_parms
																 ,wallet_path
																 ,wallet_alias
																 ,server_host
																 ,max_streams
																 ,''N/A'' AS read_only
																 ,''N/A'' AS request_only
																 ,''N/A'' AS store_and_forward
															 FROM ra_replication_server RIGHT OUTER JOIN dual ON 1 = 1
															ORDER BY replication_server_name';

	-- V21 replication cursor
	c_v21_rep						   VARCHAR2(4000) := 'SELECT NVL(ra_replication_config.replication_server_name, ''No Replication Servers'') AS replication_server_name
																 ,ra_replication_config.replication_server_state
																 ,ra_replication_policy.policy_name AS protection_policy
																 ,ra_replication_config.catalog_owner AS rep_server_connect_name
																 ,ra_replication_config.proxy_http_address
																 ,ra_replication_config.proxy_timeout
																 ,ra_replication_config.sbt_library_name
																 ,ra_replication_config.sbt_library_parms
																 ,ra_replication_config.attribute_name
																 ,ra_replication_config.attribute_parms
																 ,ra_replication_config.wallet_path
																 ,ra_replication_config.wallet_alias
																 ,ra_replication_config.server_host
																 ,ra_replication_config.max_streams
																 ,ra_replication_policy.read_only
																 ,ra_replication_policy.request_only
																 ,ra_replication_policy.store_and_forward
															FROM ra_replication_config RIGHT OUTER JOIN ra_replication_policy ON ra_replication_config.replication_server_key = ra_replication_policy.replication_server_key
																					   RIGHT OUTER JOIN dual ON 1 = 1
														   ORDER BY ra_replication_config.replication_server_name';

	--Database Details Variables

	l0_db_bytes					NUMBER;
	l0_db_uncomp_bytes			NUMBER;
	l0_comp_ratio				NUMBER;

	l1_df_bytes					NUMBER;
	l1_df_uncomp_bytes			NUMBER;
	l1_avg_df_bytes				NUMBER;
	l1_avg_df_uncomp_bytes		NUMBER;
	l1_tot_db_bytes				NUMBER;
	l1_tot_db_uncomp_bytes		NUMBER;
	l1_avg_db_bytes				NUMBER;
	l1_avg_db_uncomp_bytes		NUMBER;
	l1_loop_cnt					NUMBER;
	l1_days_included			NUMBER;
	l1_comp_ratio				NUMBER;

	db_comp_ratio				NUMBER;

	redo_min_time				DATE;
	redo_max_time				DATE;
	redo_min_bs_key				NUMBER;
	redo_max_bs_key				NUMBER;
	redo_bytes					NUMBER;
	redo_uncomp_bytes			NUMBER;
	redo_tot_bytes				NUMBER;
	redo_tot_uncomp_bytes		NUMBER;
	redo_avg_bytes				NUMBER;
	redo_avg_uncomp_bytes		NUMBER;
	redo_input_bytes			NUMBER;
	redo_output_bytes			NUMBER;
	redo_days_included			NUMBER;
	redo_comp_ratio				NUMBER;

	rr_low_time					VARCHAR2(11);
	rr_high_time				VARCHAR2(11);
	rr_gaps						NUMBER;

	-- Determine if this is a pre V21.1 RA. 
	-- The RA_REPLICATION_SERVER view does not exist in V21.1 and later.
	FUNCTION is_pre_v21 RETURN BOOLEAN IS
		n VARCHAR2(1);
	BEGIN
		SELECT 'x'
		  INTO n 
		  FROM all_views
		 WHERE view_name = 'RA_REPLICATION_SERVER'
		;

		RETURN TRUE;
	EXCEPTION
		WHEN OTHERS THEN
			RETURN FALSE;
	END is_pre_v21;

/*
	--Uncomment for testing
	PROCEDURE Pv(n IN VARCHAR2, v IN NUMBER) IS
	BEGIN
		dbms_output.Put_line(n || '=' || v);
	END Pv;
*/

--
--Database Details Section
--
BEGIN
	--Get the begin time of the script
	SELECT SYSDATE
	  INTO begin_time
	  FROM dual;

	--Get the catalog information		
		SELECT SYS_CONTEXT('userenv','db_name')
			 , SYS_CONTEXT('userenv', 'server_host')
			 , SYS_CONTEXT('userenv', 'session_user')
		  INTO cat_dbname
			 , cat_host
			 , cat_schema
		FROM dual
		;

	-- Get the catalog version
	SELECT MAX(version) 
	  INTO cat_version
	  FROM rcver
	;

	-- Build the redo log collection 1 time; then use it for each database within the outer loop below.
	
	-- This method is much faster than querying the RC views for each database in the loop.
	BEGIN
		OPEN c_brl;
		FETCH c_brl BULK COLLECT INTO brl;
		CLOSE c_brl;
	EXCEPTION
		WHEN OTHERS THEN
			DBMS_OUTPUT.PUT_LINE('No BRL');
	END;

	--Output version header
		DBMS_OUTPUT.PUT_LINE('********* Start of ZDLRA Usage(6.x) ****************');

	--Output column headers
	DBMS_OUTPUT.PUT(D||'DB UNIQUE NAME');
	DBMS_OUTPUT.PUT(D||'DBID');
	DBMS_OUTPUT.PUT(D||'DBKEY');
	DBMS_OUTPUT.PUT(D||'CREATION DATE');
	DBMS_OUTPUT.PUT(D||'STATE');
	DBMS_OUTPUT.PUT(D||'POLICY NAME');
	DBMS_OUTPUT.PUT(D||'SPACE USAGE (GB)');
	DBMS_OUTPUT.PUT(D||'RECOVERY WINDOW SPACE (GB)');
	DBMS_OUTPUT.PUT(D||'DISK RESERVED SPACE (GB)');
	DBMS_OUTPUT.PUT(D||'PCT RWS/RESERVED SPACE');
	DBMS_OUTPUT.PUT(D||'FREEABLE SPACE (GB)');
	DBMS_OUTPUT.PUT(D||'RECOVERY WINDOW COMPLIANCE (D)');
	DBMS_OUTPUT.PUT(D||'RECOVERY WINDOW GOAL (D)');
	DBMS_OUTPUT.PUT(D||'RESTORE WINDOW (D)');
	DBMS_OUTPUT.PUT(D||'MINIMUM RECOVERY NEEDED (D)');
	DBMS_OUTPUT.PUT(D||'RESTORE RANGE LOW DATE');
	DBMS_OUTPUT.PUT(D||'RESTORE RANGE HIGH DATE');
	DBMS_OUTPUT.PUT(D||'RESTORE RANGE GAPS');
	DBMS_OUTPUT.PUT(D||'DB SIZE (GB)');
	DBMS_OUTPUT.PUT(D||'L0 SIZE (GB)');
	DBMS_OUTPUT.PUT(D||'L0 UNCOMP SIZE (GB)');
	DBMS_OUTPUT.PUT(D||'L0 COMP RATIO');
	DBMS_OUTPUT.PUT(D||'L1 TOTAL SIZE (GB)');
	DBMS_OUTPUT.PUT(D||'L1 TOTAL UNCOMP SIZE (GB)');
	DBMS_OUTPUT.PUT(D||'L1 DAILY SIZE (GB)');
	DBMS_OUTPUT.PUT(D||'L1 DAILY UNCOMP SIZE (GB)');
	DBMS_OUTPUT.PUT(D||'L1 COMP RATIO');
	DBMS_OUTPUT.PUT(D||'L1 DAYS INCLUDED');
	DBMS_OUTPUT.PUT(D||'COMBINED L0/L1 COMP RATIO');
	DBMS_OUTPUT.PUT(D||'TOTAL REDO (GB)');
	DBMS_OUTPUT.PUT(D||'TOTAL UNCOMP REDO (GB)');
	DBMS_OUTPUT.PUT(D||'DAILY REDO (GB)');
	DBMS_OUTPUT.PUT(D||'DAILY UNCOMP REDO (GB)');
	DBMS_OUTPUT.PUT(D||'REDO DAYS INCLUDED');
	DBMS_OUTPUT.PUT(D||'REDO COMP RATIO');
	DBMS_OUTPUT.PUT(D||'DEDUPLICATION FACTOR');
	DBMS_OUTPUT.PUT(D||'BACKUP OPTIMIZATION');
	DBMS_OUTPUT.PUT(D||'REAL TIME REDO');
	DBMS_OUTPUT.NEW_LINE;

	FOR db_rec IN ( SELECT db.db_id
						 , db_key
						 , db.curr_dbinc_key
						 , db.reg_db_unique_name
						 , TO_CHAR(ra_d.creation_time, 'DD-MON-YYYY') AS creation_date
						 , ra_d.state
						 , ra_d.policy_name
						 , ROUND(ra_d.space_usage, 3) AS space_usage
						 , ROUND(ra_d.recovery_window_space, 3) AS recovery_window_space
						 , ROUND(ra_d.disk_reserved_space, 3) AS disk_reserved_space
						 , ROUND(ra_d.recovery_window_space / ra_d.disk_reserved_space, 3) AS pct_rs_used_by_rws
						 , ROUND(ra_d.space_usage - ra_d.recovery_window_space, 3) AS freeable_space
						 , EXTRACT (DAY FROM ra_d.recovery_window_compliance) AS recovery_window_compliance																														 
						 , EXTRACT (DAY FROM ra_d.recovery_window_goal) AS recovery_window_goal
						 , EXTRACT (DAY FROM ra_d.restore_window) AS restore_window
						 , EXTRACT (DAY FROM ra_d.minimum_recovery_needed) AS minimum_recovery_needed
						 , ROUND(ra_d.size_estimate, 3) AS size_estimate
						 , ROUND(ra_d.deduplication_factor, 1) AS deduplication_factor
						 , nzdl_active
					  FROM db JOIN odb USING (db_key)
							  JOIN ra_database ra_d USING (db_key)
				  ORDER BY db.reg_db_unique_name
				  )

	LOOP
		l0_db_bytes				:= 0;
		l0_db_uncomp_bytes		:= 0;
		l0_comp_ratio			:= 1;

		l1_tot_db_bytes			:= 0;
		l1_tot_db_uncomp_bytes	:= 0;
		l1_avg_db_bytes			:= 0;
		l1_avg_db_uncomp_bytes	:= 0;
		l1_comp_ratio			:= 1;
		l1_days_included		:= 1;

		redo_avg_bytes			:= 0;
		redo_avg_uncomp_bytes	:= 0;
		redo_bytes				:= 0;
		redo_uncomp_bytes		:= 0;
		redo_comp_ratio			:= 1;
		redo_input_bytes		:= 0;
		redo_output_bytes		:= 0;
		redo_tot_bytes			:= 0;
		redo_tot_uncomp_bytes	:= 0;

		-- For each datafile in the current incarnation
		FOR df_rec IN ( SELECT df_key
							 , block_size
						  FROM df
						 WHERE dbinc_key = db_rec.curr_dbinc_key
					  )
		LOOP
			l1_loop_cnt				:= 1;
			l1_df_bytes				:= 0;
			l1_df_uncomp_bytes		:= 0;
			l1_avg_df_bytes			:= 0;
			l1_avg_df_uncomp_bytes	:= 0;

			--
			--Begin L0 Section
			--

			-- For the latest Virtualized Level 0 backup
			FOR vbdf_rec_level0_outer IN ( SELECT df_key
												, MAX(ckp_scn) AS max_ckp_scn
											 FROM vbdf
											WHERE df_key = df_rec.df_key
											  AND state = 1
											  AND dfblocks IS NOT NULL
										 GROUP BY df_key
										 )
			LOOP
				-- Get the size in compressed bytes and estimate the size of the encrypted file as well
				FOR vbdf_rec_level0 IN ( SELECT ckp_scn
											  , NVL(dfbytes, 0) AS dfbytes
											  , NVL(df_rec.block_size * dfblocks, 0) AS est_encrypt_df_size_level0
										   FROM vbdf
										  WHERE df_key = vbdf_rec_level0_outer.df_key
											AND ckp_scn = vbdf_rec_level0_outer.max_ckp_scn
											AND state = 1
									   )
				LOOP
					l0_db_bytes			:= l0_db_bytes + vbdf_rec_level0.dfbytes;
					l0_db_uncomp_bytes	:= l0_db_uncomp_bytes + vbdf_rec_level0.est_encrypt_df_size_level0;
				END LOOP;
			END LOOP;

			--Calculate L0 compression ratio. Avoid divide by 0.
			IF l0_db_bytes > 0
			THEN
				l0_comp_ratio := ROUND(l0_db_uncomp_bytes / l0_db_bytes , 3);
			END IF;

			--
			--End L0 Section
			--

			--
			--Begin L1 Section
			--

			--Incremental Level 1
			--Now get up to last days_included virtual backups for the datafile

			FOR vbdf_rec_level1 IN ( SELECT DISTINCT df_key
												   , ckp_scn
												FROM vbdf
											   WHERE df_key = df_rec.df_key
												 AND state = 1
												 AND dfblocks IS NOT NULL
											ORDER BY ckp_scn DESC
								   )
			LOOP
				-- get the size in compressed bytes and estimate the size of the encrypted file as well
				FOR level1_rec IN ( SELECT NVL(newblk_bytes, 0) AS l1_bytes
										 , NVL((newblk_bytes / (dfbytes / dfblocks)) * df_rec.block_size, 0) AS l1_uncomp_bytes
									  FROM vbdf
									 WHERE df_key = vbdf_rec_level1.df_key
									   AND ckp_scn = vbdf_rec_level1.ckp_scn
									   AND state = 1
								  )
				LOOP
					l1_tot_db_bytes			:= l1_tot_db_bytes + level1_rec.l1_bytes;
					l1_tot_db_uncomp_bytes	:= l1_tot_db_uncomp_bytes + level1_rec.l1_uncomp_bytes;

					--Only include the specified most recent days in the daily average
					IF l1_loop_cnt <= days_included
					THEN
						l1_avg_df_bytes			:= l1_avg_df_bytes + level1_rec.l1_bytes;
						l1_avg_df_uncomp_bytes	:= l1_avg_df_uncomp_bytes + level1_rec.l1_uncomp_bytes;
						IF l1_days_included <= l1_loop_cnt
						THEN
							l1_days_included := l1_loop_cnt;
						END IF;
					END IF;
				END LOOP;
				l1_loop_cnt := l1_loop_cnt + 1;
			END LOOP;
			l1_avg_db_bytes		:= l1_avg_db_bytes + l1_avg_df_bytes;
			l1_avg_db_uncomp_bytes := l1_avg_db_uncomp_bytes + l1_avg_df_uncomp_bytes;
		END LOOP;

		--Calculate the daily average L1 size over the past days included
		l1_avg_db_bytes		:= l1_avg_db_bytes / l1_days_included;
		l1_avg_db_uncomp_bytes := l1_avg_db_uncomp_bytes / l1_days_included;

		--Calculate L1 compression ratio. Avoid divide by 0.
		IF l1_tot_db_bytes > 0
		THEN
			l1_comp_ratio := ROUND(l1_tot_db_uncomp_bytes / l1_tot_db_bytes , 3);
		END IF;

		--
		--End L1 Section
		--

		--Caclulate the average db compression ratio (L0 + L1 combined)
		IF l0_db_bytes + l1_tot_db_bytes > 0
		THEN
			db_comp_ratio := (l0_db_uncomp_bytes + l1_tot_db_uncomp_bytes) / (l0_db_bytes + l1_tot_db_bytes);
		ELSE
			db_comp_ratio := 1;
		END IF;

		--
		--Begin Redo Section
		--

		FOR i IN brl.FIRST..brl.LAST LOOP 
			IF brl(i).db_key = db_rec.db_key
			THEN
				redo_tot_uncomp_bytes	:= NVL(brl(i).original_input_bytes,0);
				redo_tot_bytes			:= NVL(brl(i).output_bytes,0);
				redo_avg_uncomp_bytes	:= NVL(brl(i).avg_original_input_bytes,0);
				redo_avg_bytes			:= NVL(brl(i).avg_output_bytes,0);
				redo_days_included		:= NVL(brl(i).brl_days_included,0);
				EXIT;
			END IF;
		END LOOP;

		--Calculate the compression ratio				
		IF redo_tot_bytes > 0
		THEN
			redo_comp_ratio := ROUND(redo_tot_uncomp_bytes / redo_tot_bytes , 3);
		END IF;

		--
		--End Redo Section
		--

		--Get the RESTORE RANGE
		SELECT TO_CHAR(TRUNC(MIN(low_time)), 'DD-MON-YYYY')
			, TO_CHAR(TRUNC(MAX(high_time)), 'DD-MON-YYYY')
			, COUNT(*) - 1 
		 INTO rr_low_time
			, rr_high_time
			, rr_gaps
		 FROM ra_restore_range
		WHERE db_key = db_rec.db_key;

		--Output data row

		--Mask the dbid and db_unique_name, if customer requested.
		IF mask
		THEN
			db_rec.db_id := 0;
			db_rec.reg_db_unique_name := '######';
		END IF;

		DBMS_OUTPUT.PUT(D||db_rec.reg_db_unique_name);
		DBMS_OUTPUT.PUT(D||db_rec.db_id);
		DBMS_OUTPUT.PUT(D||db_rec.db_key);
		DBMS_OUTPUT.PUT(D||db_rec.creation_date);
		DBMS_OUTPUT.PUT(D||db_rec.state);
		DBMS_OUTPUT.PUT(D||db_rec.policy_name);
		DBMS_OUTPUT.PUT(D||db_rec.space_usage);
		DBMS_OUTPUT.PUT(D||db_rec.recovery_window_space);
		DBMS_OUTPUT.PUT(D||db_rec.disk_reserved_space);
		DBMS_OUTPUT.PUT(D||db_rec.pct_rs_used_by_rws);
		DBMS_OUTPUT.PUT(D||db_rec.freeable_space);
		DBMS_OUTPUT.PUT(D||db_rec.recovery_window_compliance);
		DBMS_OUTPUT.PUT(D||db_rec.recovery_window_goal);
		DBMS_OUTPUT.PUT(D||db_rec.restore_window);
		DBMS_OUTPUT.PUT(D||db_rec.minimum_recovery_needed);
		DBMS_OUTPUT.PUT(D||rr_low_time);
		DBMS_OUTPUT.PUT(D||rr_high_time);
		DBMS_OUTPUT.PUT(D||rr_gaps);
		DBMS_OUTPUT.PUT(D||db_rec.size_estimate);
		DBMS_OUTPUT.PUT(D||ROUND(l0_db_bytes / POWER(1024, 3), 3));
		DBMS_OUTPUT.PUT(D||ROUND(l0_db_uncomp_bytes / POWER(1024, 3), 3));
		DBMS_OUTPUT.PUT(D||ROUND(l0_comp_ratio, 3));
		DBMS_OUTPUT.PUT(D||ROUND(l1_tot_db_bytes / POWER(1024, 3), 3));
		DBMS_OUTPUT.PUT(D||ROUND(l1_tot_db_uncomp_bytes / POWER(1024, 3), 3));
		DBMS_OUTPUT.PUT(D||ROUND(l1_avg_db_bytes / POWER(1024, 3), 3));
		DBMS_OUTPUT.PUT(D||ROUND(l1_avg_db_uncomp_bytes / POWER(1024, 3), 3));
		DBMS_OUTPUT.PUT(D||ROUND(l1_comp_ratio, 3));
		DBMS_OUTPUT.PUT(D||ROUND(l1_days_included, 3));
		DBMS_OUTPUT.PUT(D||ROUND(db_comp_ratio, 3));
		DBMS_OUTPUT.PUT(D||ROUND(redo_tot_bytes / POWER(1024, 3), 3));
		DBMS_OUTPUT.PUT(D||ROUND(redo_tot_uncomp_bytes / POWER(1024, 3), 3));
		DBMS_OUTPUT.PUT(D||ROUND(redo_avg_bytes / POWER(1024, 3), 3));
		DBMS_OUTPUT.PUT(D||ROUND(redo_avg_uncomp_bytes / POWER(1024, 3), 3));
		DBMS_OUTPUT.PUT(D||ROUND(redo_days_included, 3));
		DBMS_OUTPUT.PUT(D||ROUND(redo_comp_ratio, 3));
		DBMS_OUTPUT.PUT(D||db_rec.deduplication_factor);
		DBMS_OUTPUT.PUT(D||ROUND(TO_NUMBER(1 - (l0_db_uncomp_bytes / POWER(1024, 3) / db_rec.size_estimate)), 3));
		DBMS_OUTPUT.PUT(D||db_rec.nzdl_active);

		DBMS_OUTPUT.NEW_LINE;
	END LOOP;
	DBMS_OUTPUT.PUT(CHR(10));

	--
	--End Database Details
	--

	--
	--Begin ZDLRA Storage Location
	--

	--Output column headers
	DBMS_OUTPUT.PUT(   'STORAGE LOCATION');
	DBMS_OUTPUT.PUT(D||'DISK GROUPS');
	DBMS_OUTPUT.PUT(D||'TOTAL SPACE (GB)');
	DBMS_OUTPUT.PUT(D||'USED SPACE (GB)');
	DBMS_OUTPUT.PUT(D||'FREE SPACE (GB)');
	DBMS_OUTPUT.PUT(D||'FREE SPACE GOAL (GB)');
	DBMS_OUTPUT.PUT(D||'SYSTEM PURGING SPACE (GB)');
	DBMS_OUTPUT.PUT(D||'UNRESERVED SPACE (GB)');
	DBMS_OUTPUT.PUT(D||'AUTOTUNE SPACE LIMIT (GB)');
	DBMS_OUTPUT.NEW_LINE;

	FOR s IN (SELECT name AS storage_location
				   , disk_groups
				   , ROUND(total_space, 3) AS total_space_gb
				   , ROUND(used_space, 3) AS used_space_gb
				   , ROUND(freespace, 3) AS freespace_gb
				   , ROUND(freespace_goal,3) AS freespace_goal_gb
				   , ROUND(system_purging_space,3) AS system_purging_space_gb
				   , ROUND(unreserved_space,3) AS unreserved_space_gb
				   , ROUND(autotune_space_limit,3) AS autotune_space_limit_gb
				FROM ra_storage_location
			  ORDER BY name
			 )
	LOOP
		--Output data row
		DBMS_OUTPUT.PUT(   s.storage_location);
		DBMS_OUTPUT.PUT(D||s.disk_groups);
		DBMS_OUTPUT.PUT(D||s.total_space_gb);
		DBMS_OUTPUT.PUT(D||s.used_space_gb);
		DBMS_OUTPUT.PUT(D||s.freespace_gb);
		DBMS_OUTPUT.PUT(D||s.freespace_goal_gb);
		DBMS_OUTPUT.PUT(D||s.system_purging_space_gb);
		DBMS_OUTPUT.PUT(D||s.unreserved_space_gb);
		DBMS_OUTPUT.PUT(D||s.autotune_space_limit_gb);
		DBMS_OUTPUT.NEW_LINE;
	END LOOP;
	DBMS_OUTPUT.PUT(CHR(10));

	--
	--End ZDLRA Storage Location
	--

	--
	--Begin ZDLRA Policies
	--

	--Output column headers
	DBMS_OUTPUT.PUT(   'POLICY NAME');
	DBMS_OUTPUT.PUT(D||'DESCRIPTION');
	DBMS_OUTPUT.PUT(D||'RECOVERY WINDOW COMPLIANCE');
	DBMS_OUTPUT.PUT(D||'RECOVERY WINDOW GOAL');
	DBMS_OUTPUT.PUT(D||'MAX RETENTION WINDOW');
	DBMS_OUTPUT.PUT(D||'RECOVERY WINDOW SBT');
	DBMS_OUTPUT.PUT(D||'UNPROTECTED WINDOW');
	DBMS_OUTPUT.PUT(D||'ALLOW BACKUP DELETION');
	DBMS_OUTPUT.PUT(D||'AUTOTUNE RESERVED SPACE');
	DBMS_OUTPUT.PUT(D||'LOG COMPRESSION ALGORITHM');
	DBMS_OUTPUT.PUT(D||'PROT KEY'); 
	DBMS_OUTPUT.PUT(D||'SL NAME');
	DBMS_OUTPUT.PUT(D||'SL KEY');
	DBMS_OUTPUT.PUT(D||'POLLING NAME');
	DBMS_OUTPUT.PUT(D||'GUARANTEED COPY');
	DBMS_OUTPUT.PUT(D||'REPLICATION SERVER LIST');
	DBMS_OUTPUT.PUT(D||'STORE AND FORWARD');
	DBMS_OUTPUT.PUT(D||'KEEP COMPLIANCE');
	DBMS_OUTPUT.NEW_LINE;

	FOR p IN (SELECT policy_name
				   , description
				   , prot_key 
				   , sl_name
				   , sl_key
				   , polling_name
				   , EXTRACT(DAY FROM recovery_window_goal) AS recovery_window_goal
				   , EXTRACT(DAY FROM max_retention_window) AS max_retention_window
				   , EXTRACT(DAY FROM recovery_window_sbt) AS recovery_window_sbt
				   , CASE 
						 WHEN unprotected_window IS NULL THEN ''
						 ELSE EXTRACT(DAY FROM unprotected_window) * 24 + EXTRACT(HOUR FROM unprotected_window)||' Hours '||EXTRACT(SECOND FROM unprotected_window)||' Seconds' 
					 END AS unprotected_window
				   , guaranteed_copy
				   , replication_server_list
				   , allow_backup_deletion
				   , store_and_forward
				   , autotune_reserved_space
				   , log_compression_algorithm
				   , EXTRACT(DAY FROM recovery_window_compliance) AS recovery_window_compliance
				   , keep_compliance
				FROM ra_protection_policy
			  ORDER BY policy_name
			 )
	LOOP
		--Output data row
		DBMS_OUTPUT.PUT(   p.policy_name);
		DBMS_OUTPUT.PUT(D||p.description);
		DBMS_OUTPUT.PUT(D||p.recovery_window_compliance);
		DBMS_OUTPUT.PUT(D||p.recovery_window_goal);
		DBMS_OUTPUT.PUT(D||p.max_retention_window);
		DBMS_OUTPUT.PUT(D||p.recovery_window_sbt);
		DBMS_OUTPUT.PUT(D||p.unprotected_window);
		DBMS_OUTPUT.PUT(D||p.allow_backup_deletion);
		DBMS_OUTPUT.PUT(D||p.autotune_reserved_space);
		DBMS_OUTPUT.PUT(D||p.log_compression_algorithm);
		DBMS_OUTPUT.PUT(D||p.prot_key); 
		DBMS_OUTPUT.PUT(D||p.sl_name);
		DBMS_OUTPUT.PUT(D||p.sl_key);
		DBMS_OUTPUT.PUT(D||p.polling_name);
		DBMS_OUTPUT.PUT(D||p.guaranteed_copy);
		DBMS_OUTPUT.PUT(D||p.replication_server_list);
		DBMS_OUTPUT.PUT(D||p.store_and_forward);
		DBMS_OUTPUT.PUT(D||p.keep_compliance);
		DBMS_OUTPUT.NEW_LINE;
	END LOOP;
	DBMS_OUTPUT.PUT(CHR(10));

	--
	--End ZDLRA Policies
	--

	--
	--Begin ZDLRA Replication
	--

	--Output column headers
	DBMS_OUTPUT.PUT(   'REPLICATION SERVER NAME');
	DBMS_OUTPUT.PUT(D||'REPLICATION SERVER STATE');
	DBMS_OUTPUT.PUT(D||'PROTECTION POLICY');
	DBMS_OUTPUT.PUT(D||'REP SERVER CONNECT NAME');
	DBMS_OUTPUT.PUT(D||'PROXY HTTP ADDRESS');
	DBMS_OUTPUT.PUT(D||'PROXY TIMEOUT');
	DBMS_OUTPUT.PUT(D||'SBT LIBRARY NAME');
	DBMS_OUTPUT.PUT(D||'SBT LIBRARY PARMS');
	DBMS_OUTPUT.PUT(D||'ATTRIBUTE NAME');
	DBMS_OUTPUT.PUT(D||'ATTRIBUTE PARMS');
	DBMS_OUTPUT.PUT(D||'WALLET PATH');
	DBMS_OUTPUT.PUT(D||'WALLET ALIAS');
	DBMS_OUTPUT.PUT(D||'SERVER HOST');   
	DBMS_OUTPUT.PUT(D||'MAX STREAMS');
	DBMS_OUTPUT.PUT(D||'READ ONLY');
	DBMS_OUTPUT.PUT(D||'REQUEST ONLY');
	DBMS_OUTPUT.PUT(D||'STORE AND FORWARD');
	DBMS_OUTPUT.NEW_LINE;

	IF is_pre_v21
	THEN
		OPEN cv FOR c_pre_v21_rep;
	ELSE
		OPEN cv FOR c_v21_rep;
	END IF;

	LOOP
		FETCH cv INTO rep_tab;
		EXIT WHEN cv%NOTFOUND;

		--Output data row
		DBMS_OUTPUT.PUT(   rep_tab.replication_server_name);
		DBMS_OUTPUT.PUT(D||rep_tab.replication_server_state);
		DBMS_OUTPUT.PUT(D||rep_tab.protection_policy);
		DBMS_OUTPUT.PUT(D||rep_tab.rep_server_connect_name);
		DBMS_OUTPUT.PUT(D||rep_tab.proxy_http_address);
		DBMS_OUTPUT.PUT(D||rep_tab.proxy_timeout);
		DBMS_OUTPUT.PUT(D||rep_tab.sbt_library_name);
		DBMS_OUTPUT.PUT(D||rep_tab.sbt_library_parms);
		DBMS_OUTPUT.PUT(D||rep_tab.attribute_name);
		DBMS_OUTPUT.PUT(D||rep_tab.attribute_parms);
		DBMS_OUTPUT.PUT(D||rep_tab.wallet_path);
		DBMS_OUTPUT.PUT(D||rep_tab.wallet_alias);
		DBMS_OUTPUT.PUT(D||REPLACE(rep_tab.server_host, D, ':'));   
		DBMS_OUTPUT.PUT(D||rep_tab.max_streams);
		DBMS_OUTPUT.PUT(D||rep_tab.read_only);
		DBMS_OUTPUT.PUT(D||rep_tab.request_only);
		DBMS_OUTPUT.PUT(D||rep_tab.store_and_forward);
		DBMS_OUTPUT.NEW_LINE;
	END LOOP;
	CLOSE cv;
	DBMS_OUTPUT.PUT(CHR(10));

	--
	--End ZDLRA Replication
	--

	--
	--Begin ZDLRA Copy-to-Tape
	--

	--RA_SBT_LIBRARY
	--Output column headers
	DBMS_OUTPUT.PUT(   'LIB_NAME');
	DBMS_OUTPUT.PUT(D||'LIB_KEY');
	DBMS_OUTPUT.PUT(D||'DRIVES');
	DBMS_OUTPUT.PUT(D||'RESTORE_DRIVES');
	DBMS_OUTPUT.PUT(D||'PARMS');
	DBMS_OUTPUT.PUT(D||'SEND');
	DBMS_OUTPUT.PUT(D||'STATUS');
	DBMS_OUTPUT.NEW_LINE;

	FOR r IN (SELECT lib_name
				   , lib_key
				   , drives 
				   , restore_drives   
				   , parms
				   , send		 
				   , status  
				FROM (SELECT NVL(lib_name, 'No SBT Libraries') AS lib_name 
						   , lib_key
						   , drives 
						   , restore_drives   
						   , parms
						   , send		 
						   , status  
						FROM ra_sbt_library RIGHT OUTER JOIN dual ON 1 = 1
					   )
				WHERE lib_name NOT LIKE 'REP$%'
			  ORDER BY lib_name
			 )
	LOOP
		--Output data row
		DBMS_OUTPUT.PUT(   r.lib_name);
		DBMS_OUTPUT.PUT(D||r.lib_key);
		DBMS_OUTPUT.PUT(D||r.drives);
		DBMS_OUTPUT.PUT(D||r.restore_drives);
		DBMS_OUTPUT.PUT(D||r.parms);
		DBMS_OUTPUT.PUT(D||r.send);
		DBMS_OUTPUT.PUT(D||r.status);
		DBMS_OUTPUT.NEW_LINE;
	END LOOP;
	DBMS_OUTPUT.PUT(CHR(10));

	--RA_SBT_ATTRIBUTE_SET
	--Output column headers
	DBMS_OUTPUT.PUT(   'ATTRIBUTE_SET_NAME');
	DBMS_OUTPUT.PUT(D||'ATTRIBUTE_SET_KEY');
	DBMS_OUTPUT.PUT(D||'LIB_NAME');
	DBMS_OUTPUT.PUT(D||'STREAMS');
	DBMS_OUTPUT.PUT(D||'POOLID');
	DBMS_OUTPUT.PUT(D||'PARMS');
	DBMS_OUTPUT.PUT(D||'SEND');
	DBMS_OUTPUT.NEW_LINE;

	FOR r IN (SELECT attribute_set_name 
				   , attribute_set_key
				   , lib_name 
				   , streams   
				   , poolid
				   , parms		 
				   , send  
				 FROM (SELECT NVL(attribute_set_name, 'No SBT Attribute Sets') AS attribute_set_name 
							, attribute_set_key
							, lib_name 
							, streams   
							, poolid
							, parms		 
							, send  
						 FROM ra_sbt_attribute_set RIGHT OUTER JOIN dual ON 1 = 1
					  )
				WHERE attribute_set_name NOT LIKE 'REP$%'
			  ORDER BY attribute_set_name
			 )
	LOOP
		--Output data row
		DBMS_OUTPUT.PUT(   r.attribute_set_name);
		DBMS_OUTPUT.PUT(D||r.attribute_set_key);
		DBMS_OUTPUT.PUT(D||r.lib_name);
		DBMS_OUTPUT.PUT(D||r.streams);
		DBMS_OUTPUT.PUT(D||r.poolid);
		DBMS_OUTPUT.PUT(D||r.parms);
		DBMS_OUTPUT.PUT(D||r.send);
		DBMS_OUTPUT.NEW_LINE;
	END LOOP;
	DBMS_OUTPUT.PUT(CHR(10));

	--RA_SBT_JOB
	--Output column headers
	DBMS_OUTPUT.PUT(   'TEMPLATE_NAME');
	DBMS_OUTPUT.PUT(D||'TEMPLATE_KEY');
	DBMS_OUTPUT.PUT(D||'ATTRIBUTE_SET_NAME');
	DBMS_OUTPUT.PUT(D||'LIB_NAME');
	DBMS_OUTPUT.PUT(D||'POLICY_NAME');
	DBMS_OUTPUT.PUT(D||'DB_KEY');
	DBMS_OUTPUT.PUT(D||'DB_UNIQUE_NAME');
	DBMS_OUTPUT.PUT(D||'BACKUP_TYPE');
	DBMS_OUTPUT.PUT(D||'FROM_TAG');
	DBMS_OUTPUT.PUT(D||'PRIORITY');
	DBMS_OUTPUT.PUT(D||'COPIES');
	DBMS_OUTPUT.PUT(D||'LAST_SCHEDULE_TIME');
	DBMS_OUTPUT.PUT(D||'WINDOW');
	DBMS_OUTPUT.PUT(D||'COMPRESSION_ALGORITHM');
	DBMS_OUTPUT.NEW_LINE;

	FOR r IN (SELECT template_name
				   , template_key
				   , attribute_set_name 
				   , lib_name   
				   , policy_name
				   , db_key 
				   , db_unique_name
				   , backup_type 
				   , from_tag 
				   , priority   
				   , copies
				   , last_schedule_time		 
				   , window  
				   , compression_algorithm 
				 FROM (SELECT NVL(template_name, 'No SBT Templates') AS template_name
							, template_key
							, attribute_set_name 
							, lib_name   
							, policy_name
							, db_key 
							, db_unique_name
							, backup_type 
							, from_tag 
							, priority   
							, copies
							, last_schedule_time		 
							, window  
							, compression_algorithm 
						 FROM ra_sbt_job RIGHT OUTER JOIN dual ON 1 = 1
					  )
				WHERE template_name NOT LIKE 'REP$%'
			  ORDER BY template_name
			 )
	LOOP
		--Output data row
		DBMS_OUTPUT.PUT(   r.template_name);
		DBMS_OUTPUT.PUT(D||r.template_key);
		DBMS_OUTPUT.PUT(D||r.attribute_set_name);
		DBMS_OUTPUT.PUT(D||r.lib_name);
		DBMS_OUTPUT.PUT(D||r.policy_name);
		DBMS_OUTPUT.PUT(D||r.db_key);
		DBMS_OUTPUT.PUT(D||r.db_unique_name);
		DBMS_OUTPUT.PUT(D||r.backup_type);
		DBMS_OUTPUT.PUT(D||r.from_tag);
		DBMS_OUTPUT.PUT(D||r.priority);
		DBMS_OUTPUT.PUT(D||r.copies);
		DBMS_OUTPUT.PUT(D||r.last_schedule_time);
		DBMS_OUTPUT.PUT(D||r.window);
		DBMS_OUTPUT.PUT(D||r.compression_algorithm);
		DBMS_OUTPUT.NEW_LINE;
	END LOOP;
	DBMS_OUTPUT.PUT(CHR(10));

	--
	--End ZDLRA Copy-to-Tape
	--

	--Get the end time
	SELECT SYSDATE
	  INTO end_time	
	  FROM dual;

	--Calculate the elapsed seconds

	total_secs := (end_time - begin_time) * 24 * 60 * 60;

	--Output the Catalog and Timing Info
	DBMS_OUTPUT.PUT_LINE('~Catalog Database:      '||cat_dbname);
	DBMS_OUTPUT.PUT_LINE('~Catalog Host:          '||cat_host);
	DBMS_OUTPUT.PUT_LINE('~Catalog Schema:        '||cat_schema);
	DBMS_OUTPUT.PUT_LINE('~Catalog Version:       '||cat_version);
	DBMS_OUTPUT.PUT_LINE('~Begin Time:            '||TO_CHAR(begin_time, 'DD-MON-YYYY HH24:MI:SS'));
	DBMS_OUTPUT.PUT_LINE('~End Time:              '||TO_CHAR(end_time, 'DD-MON-YYYY HH24:MI:SS'));
	DBMS_OUTPUT.PUT_LINE('~Total Elapsed Seconds: '||ROUND(total_secs, 0));
	DBMS_OUTPUT.PUT_LINE('~Days Included:         '||days_included);
	DBMS_OUTPUT.PUT_LINE('~Script Version:        '||version);
END;
/
SPOOL OFF

EXIT
