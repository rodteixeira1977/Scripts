-- This script generates AWR reports for the peak time over the past back_days (defaulted to 7 days). 
-- Dated July 2024
-- Author: Yuan Yao
CREATE OR REPLACE DIRECTORY tmp AS '/tmp/';
 
DECLARE
    back_days NUMBER := 7; -- Customize the number of back days here
    peak_id NUMBER;
    my_dbid NUMBER;
    today VARCHAR2(30);
    awr_dir VARCHAR2(40) := 'TMP';
    awr_file UTL_FILE.FILE_TYPE;
    awr_file_name VARCHAR2(60);
BEGIN
    -- Get the peak snap_id
    SELECT snap_id
    INTO peak_id
    FROM (
        SELECT snap_id, average, end_time
        FROM dba_hist_sysmetric_summary
        WHERE average = (SELECT MAX(average)
                         FROM dba_hist_sysmetric_summary
                         WHERE metric_name = 'Average Active Sessions'
                           AND end_time > SYSDATE - back_days)
    )
    WHERE ROWNUM = 1;
 
    -- Get the DBID
    SELECT dbid
    INTO my_dbid
    FROM v$database;
 
    -- Get the current date and time
    SELECT TO_CHAR(SYSDATE, 'YYYY_MON_DD_HH24_MI')
    INTO today
    FROM dual;
 
    -- Loop through each instance in the RAC environment
    FOR instance_rec IN (SELECT instance_number, instance_name FROM gv$instance) LOOP
        awr_file_name := 'awr_' || today || '_inst' || instance_rec.instance_number || '.html';
        awr_file := UTL_FILE.FOPEN(awr_dir, awr_file_name, 'w');
 
        -- Generate the AWR report in HTML format for each instance
        FOR curr_awr IN (
            SELECT output
            FROM TABLE(dbms_workload_repository.awr_report_html(
                my_dbid,
                instance_rec.instance_number,
                peak_id - 1, peak_id,
                0))
        )
        LOOP
            UTL_FILE.PUT_LINE(awr_file, curr_awr.output);
        END LOOP;
 
        UTL_FILE.FCLOSE(awr_file);
    END LOOP;
 
EXCEPTION
    WHEN OTHERS THEN
        IF UTL_FILE.IS_OPEN(awr_file) THEN
            UTL_FILE.FCLOSE(awr_file);
        END IF;
        RAISE;
END;
/