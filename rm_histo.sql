Rem
Rem $Header: tkmain_6/tkin/sql/rm_histo.sql bsprunt_rmaudit/3 2014/06/03 14:07:29 bsprunt Exp $
Rem
Rem rm_histo.sql
Rem
Rem Copyright (c) 2014, Oracle and/or its affiliates. All rights reserved.
Rem
Rem    NAME
Rem      rm_histo.sql - create Resource Manager HISTOgram.
Rem
Rem    DESCRIPTION
Rem      This script creates one of several histograms of the count of running
Rem      and/or runnable VTs managed by Resource Manager.  Samples from the
Rem      Active Session History are used to create the histograms.
Rem
Rem    NOTES
Rem      
Rem    MODIFIED   (MM/DD/YY)
Rem    bsprunt     04/17/14 - Created
Rem

set echo off
set feedback 1
set numwidth 10
set linesize 300
set trimspool on
set tab off
set pagesize 100
set verify off
set serveroutput on;
set serveroutput on format wrapped;

prompt
prompt ###############################################################################################
prompt # This script creates two types of histograms.  The "load" histograms show the number of
prompt # sessions that are either running (on CPU) or waiting for CPU (under the event resmgr:cpu
prompt # quantum).  The load histograms provide a description of the CPU demand.  The "wait load"
prompt # histograms show the number of sessions that are waiting for CPU.  Both types of histograms
prompt # are created from Active Session History samples.
prompt # 
prompt # Histogram types:
prompt #   1: load (sessions on CPU or waiting for CPU)
prompt #   2: load by consumer group
prompt #   3: load by container (must be run within the ROOT container in a CDB)
prompt #   4: wait load (sessions waiting for CPU)
prompt #   5: wait load by consumer group
prompt #   6: wait load by container (must be run within the ROOT container in a CDB)
prompt

-- prompt the user for the histogram type
--
accept histo_type char default '1' prompt 'Enter histogram type: [1]: '

-- display the current time
--
select to_char(sysdate, 'YYYY-MM-DD HH24:MI') "CURRENT_TIME" from dual;

-- prompt the user for the start_time and end_time for the histogram
--
accept start_time char default '-1hr' prompt 'Enter start_time (YYYY-MM-DD HH24:MI | -NNNmin | -NNNhr) [-1hr]: '
accept end_time   char default '0min' prompt 'Enter   end_time (YYYY-MM-DD HH24:MI | -NNNmin | -NNNhr) [0min]: '

-- create the selected histogram
--
declare

  i                          simple_integer := 0;

  -- these are used for the histogram bucket configuration
  --
  cpu_count                  simple_integer := 0;
  bucket_min                 simple_integer := 0;
  bucket_max                 simple_integer := 0;
  num_buckets                simple_integer := 0;

  -- these are used to indicate the ASH sample source and the set
  -- ASH samples to use for the histogram
  --
  min_vdollar_ash_time       date;
  min_dba_hist_ash_time      date;
  relative_minutes           varchar2(64);
  relative_hours             varchar2(64);
  histo_start_time           date;
  histo_end_time             date;
  histo_interval             interval day (3) to second;
  use_vdollar_ash            simple_integer := 0;
  use_dba_hist_ash           simple_integer := 0;
  sample_source_message      varchar2(512);

  -- these are used to indicate whether to create a load histogram
  -- (where both include_rng and include_rbl are 1) or to create
  -- a wait load histogram (where include_rng is 0 and include_rbl
  -- is 1)
  --
  include_rng                simple_integer := 0;
  include_rbl                simple_integer := 0;

  instance_name              varchar2(256);
  database_description       varchar2(256);

$IF DBMS_DB_VERSION.VERSION >= 12
$THEN
  is_cdb                   varchar2(16);
  current_container_name   varchar2(256);
$END

  message                    varchar2(512);

begin

  -- get the instance name
  --
  select upper(sys_context('USERENV','INSTANCE_NAME')) into instance_name from dual;

$IF DBMS_DB_VERSION.VERSION >= 12
$THEN
  -- determine if we are a CDB (if we are, get the container name) and create
  -- the database description string
  --
  select cdb into is_cdb from v$database;
  if (upper(is_cdb) = 'YES')
  then
    select upper(sys_context ('USERENV', 'CON_NAME')) into current_container_name from dual;
    database_description := current_container_name || ', ' || instance_name;
  else
    database_description := instance_name;
  end if;  
$ELSE
  database_description := instance_name;
$END

  -- get the cpu count
  --
  select value into cpu_count from v$parameter where name like 'cpu_count';

  -- determine the histogram bucket configuration
  --
  num_buckets := 8;
  bucket_min := 0;
  if ('&&histo_type' = '1' or '&&histo_type' = '2' or '&&histo_type' = '3') -- this is "load" histogram
  then
    -- setup the histogram bucket range to go from at least 0 to (2 * cpu_count)
    if (cpu_count >= 4)
    then
      bucket_max := (cpu_count - MOD(cpu_count, 4)) * 2;
    else
      bucket_max := 8;
    end if;
  elsif ('&&histo_type' = '4' or '&&histo_type' = '5' or '&&histo_type' = '6') -- this is a "wait load" histogram
  then
    -- setup the histogram bucket range to go from at least 0 to cpu_count
    -- (this is done by using code similar to the code above for a "load" histogram,
    -- but the cpu_count value is divided by 2)
    if ((cpu_count / 2) >= 4)
    then
      bucket_max := ((cpu_count / 2) - MOD((cpu_count / 2), 4)) * 2;
    else
      bucket_max := 8;
    end if;
  else
    -- unexpected histogram configuration
    DBMS_OUTPUT.put_line(CHR(10) || 'ERROR: Unexpected histogram configuration, aborting.');
    GOTO finish;
  end if;

  -- get the histo_start_time
  --
  if (instr('&&start_time', 'min') != 0)
  then
    relative_minutes := substr(trim('&&start_time'), 1, instr(trim('&&start_time'), 'min')-1);
    if (LENGTH(TRIM(TRANSLATE(relative_minutes, ' +-.0123456789', ' '))) is not null)
    then
      DBMS_OUTPUT.put_line(CHR(10) || 'ERROR: Invalid format for relative minutes: ''&&start_time''');
      GOTO finish;
    end if;
    select sysdate + to_number(relative_minutes) / (24*60) into histo_start_time from dual;
  elsif (instr('&&start_time', 'hr') != 0)
  then
    relative_hours := substr(trim('&&start_time'), 1, instr(trim('&&start_time'), 'hr')-1);
    if (LENGTH(TRIM(TRANSLATE(relative_hours, ' +-.0123456789', ' '))) is not null)
    then
      DBMS_OUTPUT.put_line(CHR(10) || 'ERROR: Invalid format for relative hours: ''&&start_time''');
      GOTO finish;
    end if;
    select sysdate + to_number(relative_hours) / (24) into histo_start_time from dual;
  else
    begin
      histo_start_time := to_date('&&start_time', 'YYYY-MM-DD HH24:MI');
    exception
      when others then
      DBMS_OUTPUT.put_line(CHR(10) || 'ERROR: Invalid date format: ''&&start_time''');
      GOTO finish;
    end;
  end if;

  -- get the histo_end_time
  --
  if (instr('&&end_time', 'min') != 0)
  then
    relative_minutes := substr(trim('&&end_time'), 1, instr(trim('&&end_time'), 'min')-1);
    if (LENGTH(TRIM(TRANSLATE(relative_minutes, ' +-.0123456789', ' '))) is not null)
    then
      DBMS_OUTPUT.put_line(CHR(10) || 'ERROR: Invalid format for relative minutes: ''&&end_time''');
      GOTO finish;
    end if;
    select sysdate + to_number(relative_minutes) / (24*60) into histo_end_time from dual;
  elsif (instr('&&end_time', 'hr') != 0)
  then
    relative_hours := substr(trim('&&end_time'), 1, instr(trim('&&end_time'), 'hr')-1);
    if (LENGTH(TRIM(TRANSLATE(relative_hours, ' +-.0123456789', ' '))) is not null)
    then
      DBMS_OUTPUT.put_line(CHR(10) || 'ERROR: Invalid format for relative hours: ''&&end_time''');
      GOTO finish;
    end if;
    select sysdate + to_number(relative_hours) / (24) into histo_end_time from dual;
  else
    begin
      histo_end_time := to_date('&&end_time', 'YYYY-MM-DD HH24:MI');
    exception
      when others then
      DBMS_OUTPUT.put_line(CHR(10) || 'ERROR: Invalid date format: ''&&end_time''');
      GOTO finish;
    end;
  end if;

  -- check histogram sample time range
  --
  if (histo_start_time >= histo_end_time)
  then
    DBMS_OUTPUT.put_line(CHR(10) || 'ERROR: start_time (' || to_char(histo_start_time, 'YYYY-MM-DD HH24:MI') ||
                         ') is the same as or later than end_time (' || to_char(histo_end_time, 'YYYY-MM-DD HH24:MI') || ').');
    GOTO finish;
  end if;

  -- determine the histogram interval
  --
  histo_interval := (histo_end_time - histo_start_time) day to second;

  -- determine which ASH table to use and, as appropriate, update the histo_start_time
  --
  select min(sample_time) into min_vdollar_ash_time from v$active_session_history;
  select min(sample_time) into min_dba_hist_ash_time from dba_hist_active_sess_history;
  if ((min_vdollar_ash_time is not null) and (histo_start_time > min_vdollar_ash_time))
  then
    -- v$active_session_history has samples that go all the way back to the
    -- histo_start_time, so use samples from v$active_session_history
    use_vdollar_ash := 1;
    use_dba_hist_ash := 0;
  elsif ((min_dba_hist_ash_time is not null) and (histo_start_time > min_dba_hist_ash_time))
  then
    -- v$active_session_history does not have samples that go all the way back to the
    -- histo_start_time but dba_hist_active_sess_history does, so use samples from
    -- dba_hist_active_sess_history
    use_vdollar_ash := 0;
    use_dba_hist_ash := 1;
  else
    -- neither v$active_session_history nor dba_hist_active_sess_history has samples
    -- that go all the way back to the specified histo_start_time, so determine which
    -- sample source has the oldest, non-null sample time, use its samples, and update
    -- the histo_start_time accordingly
    if ((min_vdollar_ash_time is not null) and (min_dba_hist_ash_time is not null))
    then
      if (min_vdollar_ash_time < min_dba_hist_ash_time)
      then
        -- v$active_session_history has the oldest, minimum sample date,
        -- so use samples from v$active_session_history
        use_vdollar_ash := 1;
        use_dba_hist_ash := 0;
        histo_start_time := min_vdollar_ash_time;
      else
        -- dba_hist_active_sess_history has the oldest, minimum sample date,
        -- so use samples from dba_hist_active_sess_history
        use_vdollar_ash := 0;
        use_dba_hist_ash := 1;
        histo_start_time := min_dba_hist_ash_time;
      end if;
    else
      if (min_vdollar_ash_time is not null)
      then
        -- v$active_session_history has the oldest, non-null minimum sample date,
        -- so use samples from v$active_session_history
        use_vdollar_ash := 1;
        use_dba_hist_ash := 0;
        histo_start_time := min_vdollar_ash_time;
      elsif (min_dba_hist_ash_time is not null)
      then
        -- dba_hist_active_sess_history has the oldest, non-null minimum sample date,
        -- so use samples from dba_hist_active_sess_history
        use_vdollar_ash := 0;
        use_dba_hist_ash := 1;
        histo_start_time := min_dba_hist_ash_time;
      else
        -- neither sample source has any samples yet, print an error message and exit
        --
        DBMS_OUTPUT.put_line(CHR(10) || 'ERROR: No ASH samples are available yet.');
        GOTO finish;
      end if;
    end if;
  end if;

  -- create the sample-source message
  --
  if (use_vdollar_ash = 1)
  then
    sample_source_message := '#   sample source: v$active_session_history (1 sample per second)';
  else
    sample_source_message := '#   sample source: dba_hist_active_sess_history (1 sample per 10 seconds)';
  end if;
  sample_source_message := sample_source_message || CHR(10) ||
                           '#   start time:    ' ||
                           to_char(histo_start_time, 'YYYY-MM-DD HH24:MI') || CHR(10) ||
                           '#   end time:      ' ||
                           to_char(histo_end_time, 'YYYY-MM-DD HH24:MI') || CHR(10) ||
                           '#   duration:      ' ||
                           extract(day from histo_interval) || ', ' ||
                           ltrim(to_char(extract(hour from histo_interval), '00')) || ':' ||
                           ltrim(to_char(extract(minute from histo_interval), '00')) ||
                           ' (days, HH:MM)' || CHR(10) ||
                           '#' || CHR(10) ||
                           '#   cpu_count = ' || cpu_count;

  -- configure include_rng and include_rbl and then jump to the appropriate section
  -- to create the desired histogram
  --
  begin
    if ('&&histo_type' = '1')    -- load histogram
    then
      include_rng := 1;
      include_rbl := 1;
      GOTO create_histogram;
    elsif ('&&histo_type' = '2') -- load histogram by cg
    then
      include_rng := 1;
      include_rbl := 1;
      GOTO create_histogram_by_cg;
$IF DBMS_DB_VERSION.VERSION >= 12
$THEN
    elsif ('&&histo_type' = '3') -- load histogram by container
    then
      include_rng := 1;
      include_rbl := 1;
      GOTO create_histogram_by_container;
$END
    elsif ('&&histo_type' = '4') -- wait load histogram
    then
      include_rng := 0;
      include_rbl := 1;
      GOTO create_histogram;
    elsif ('&&histo_type' = '5') -- wait load histogram by cg
    then
      include_rng := 0;
      include_rbl := 1;
      GOTO create_histogram_by_cg;
$IF DBMS_DB_VERSION.VERSION >= 12
$THEN
    elsif ('&&histo_type' = '6') -- wait load histogram by container
    then
      include_rng := 0;
      include_rbl := 1;
      GOTO create_histogram_by_container;
$END
    else
      DBMS_OUTPUT.put_line(CHR(10) || 'ERROR: An unknown or unavailable histogram type was specified: ''' || '&&histo_type' || '''.');
      GOTO finish;
    end if;
  end;

  -- execution should not reach this point, but if it does...
  --
  GOTO finish;

  <<create_histogram>>

  declare

    sample_total             simple_integer := 0;
    include_zero_only_bucket simple_integer := 0;
    zero_waiting_count       simple_integer := 0;

    CURSOR histo_cur IS
      with     desired_ash_samples as
               (select    sample_id, consumer_group_id, session_state, event
                from      v$active_session_history
                where     use_vdollar_ash = 1
                          and sample_time >= histo_start_time and sample_time <= histo_end_time
                union all
                select    sample_id, consumer_group_id, session_state, event
                from      dba_hist_active_sess_history
                where     use_dba_hist_ash = 1
                          and sample_time >= histo_start_time and sample_time <= histo_end_time)
      select   *
      from     (select  bucket, bucket_count
                from    (select bucket, count(1) "BUCKET_COUNT"
                         from   (select width_bucket(sample_sum, bucket_min, bucket_max, num_buckets) "BUCKET"
                                 from   (select   sample_id,
                                                  sum(case when (include_rng = 1
                                                                 and consumer_group_id is not NULL
                                                                 and session_state='ON CPU'
                                                                 and nvl(event, 'ON CPU') = 'ON CPU')
                                                           or   (include_rbl = 1
                                                                 and consumer_group_id is not NULL
                                                                 and session_state='WAITING'
                                                                 and nvl(event, 'ON CPU') = 'resmgr:cpu quantum')
                                                           then 1
                                                           else 0
                                                      end) "SAMPLE_SUM"
                                         from     desired_ash_samples
                                         group by sample_id))
                         group by bucket order by bucket)
                 order by bucket)
      PIVOT(sum(bucket_count)
      FOR bucket in ('1' "BUCKET1", '2' "BUCKET2", '3' "BUCKET3", '4' "BUCKET4", '5' "BUCKET5",
                     '6' "BUCKET6", '7' "BUCKET7", '8' "BUCKET8", '9' "BUCKET9"));

  begin

    -- Should we include the extra, zero-only bucket?  This is included if this is a wait-load
    -- histogram and the each normal bucket has a range greater than 1.
    if (include_rng = 0 and include_rbl = 1 and bucket_max > num_buckets)
    then
      include_zero_only_bucket := 1;
    else
      include_zero_only_bucket := 0;
    end if;

    DBMS_OUTPUT.put_line('');
    DBMS_OUTPUT.put_line('###############################################################################################');
    if (include_rng = 1 and include_rbl = 1)
    then
      DBMS_OUTPUT.put_line('# LOAD HISTOGRAM FOR: ' || database_description);
      DBMS_OUTPUT.put_line('#');
      DBMS_OUTPUT.put_line('# The table below is a histogram of the total load managed by Resource Manager (i.e., the');
      DBMS_OUTPUT.put_line('# count of sessions running on CPU or waiting for CPU).  The percentage of the total samples');
      DBMS_OUTPUT.put_line('# is shown for each histogram bucket.');
    else
      DBMS_OUTPUT.put_line('# WAIT LOAD HISTOGRAM FOR: ' || database_description);
      DBMS_OUTPUT.put_line('#');
      DBMS_OUTPUT.put_line('# The table below is a histogram of the wait load managed by Resource Manager (i.e., the');
      DBMS_OUTPUT.put_line('# count of sessions waiting for CPU).  The percentage of the total samples is shown for each');
      DBMS_OUTPUT.put_line('# histogram bucket.');
    end if;
    DBMS_OUTPUT.put_line('#');
    DBMS_OUTPUT.put_line(sample_source_message);
    DBMS_OUTPUT.put_line('#');
    DBMS_OUTPUT.put_line('');
    if (include_rng = 1 and include_rbl = 1)
    then
      DBMS_OUTPUT.put_line('        --------------------------------------------------------------');
      DBMS_OUTPUT.put_line('        |     Number of sessions running on or waiting for CPU       |');
      DBMS_OUTPUT.put_line('        |                                                            |');
      DBMS_OUTPUT.put_line('        | Light <------------------- LOAD -------------------> Heavy |');
      DBMS_OUTPUT.put_line('        --------------------------------------------------------------');
    else
      if (include_zero_only_bucket = 1)
      then
        DBMS_OUTPUT.put_line('        ---------------------------------------------------------------------');
        DBMS_OUTPUT.put_line('        |                 Number of sessions waiting for CPU                |');
        DBMS_OUTPUT.put_line('        |                                                                   |');
        DBMS_OUTPUT.put_line('        | Light <-------------------- WAIT LOAD --------------------> Heavy |');
        DBMS_OUTPUT.put_line('        ---------------------------------------------------------------------');
      else
        DBMS_OUTPUT.put_line('        --------------------------------------------------------------');
        DBMS_OUTPUT.put_line('        |            Number of sessions waiting for CPU              |');
        DBMS_OUTPUT.put_line('        |                                                            |');
        DBMS_OUTPUT.put_line('        | Light <---------------- WAIT LOAD -----------------> Heavy |');
        DBMS_OUTPUT.put_line('        --------------------------------------------------------------');
      end if;
    end if;

    message := 'Total   ';
    i := bucket_min;
    while (i < num_buckets)
    loop
      if (include_zero_only_bucket = 1 and i = bucket_min)
      then
        message := message || lpad(0, 6) || ' ';
        message := message || lpad((((bucket_max - bucket_min) / num_buckets) * i) + 1, 6) || ' ';
      else
        message := message || lpad(((bucket_max - bucket_min) / num_buckets) * i, 6) || ' ';
      end if;
      i := i + 1;
    end loop;
    DBMS_OUTPUT.put_line(message);

    message := 'Samples ';
    i := bucket_min;
    while (i < num_buckets)
    loop
      if (include_zero_only_bucket = 1 and i = bucket_min)
      then
        message := message || lpad('<= ' || 0, 6) || ' ';
        message := message || lpad('<= ' || ((((bucket_max - bucket_min) / num_buckets) * (i + 1)) - 1 + 1), 6) || ' ';
      else
        message := message || lpad('<= ' || ((((bucket_max - bucket_min) / num_buckets) * (i + 1)) - 1), 6) || ' ';
      end if;
      i := i + 1;
    end loop;
    message := message || lpad('>= ' || bucket_max, 6);
    DBMS_OUTPUT.put_line(message);

    message := '------- ';
    i := bucket_min;
    while (i < num_buckets + 1)
    loop
      if (include_zero_only_bucket = 1 and i = bucket_min)
      then
        message := message || '------ ';
      end if;
      message := message || '------ ';
      i := i + 1;
    end loop;
    DBMS_OUTPUT.put_line(message);

    for histo_rec in histo_cur
    loop

      -- if we are including the zero-only bucket, create the count of samples
      -- where the sample_sum is zero
      if (include_zero_only_bucket = 1)
      then
        declare
          CURSOR zero_waiting_count_cur IS
            with     desired_ash_samples as
                     (select    sample_id, consumer_group_id, session_state, event
                      from      v$active_session_history
                      where     use_vdollar_ash = 1
                                and sample_time >= histo_start_time and sample_time <= histo_end_time
                      union all
                      select    sample_id, consumer_group_id, session_state, event
                      from      dba_hist_active_sess_history
                      where     use_dba_hist_ash = 1
                                and sample_time >= histo_start_time and sample_time <= histo_end_time)
            select   count(*)
            from     (select   ash.sample_id,
                               sum(case when (ash.consumer_group_id is not NULL
                                              and ash.session_state='WAITING'
                                              and nvl(ash.event, 'ON CPU') = 'resmgr:cpu quantum')
                                   then 1
                                   else 0
                                   end) "SAMPLE_SUM"
                      from     (select   sample_id, consumer_group_id, session_state, event
                                from     (select   a.sample_id, b.consumer_group_id,
                                                   '-' "EVENT", '-' "SESSION_STATE"
                                          from     (select distinct sample_id
                                                    from   desired_ash_samples) a,
                                                   (select distinct consumer_group_id
                                                    from   desired_ash_samples) b)
                                union all
                                select   sample_id, consumer_group_id, session_state, event
                                from     desired_ash_samples) ash,
                               dba_rsrc_consumer_groups cgs
                      where    ash.consumer_group_id is not null
                      group by ash.sample_id
                      order by ash.sample_id)
            where     sample_sum = 0;
  
        begin
          open  zero_waiting_count_cur;
          fetch zero_waiting_count_cur into zero_waiting_count;
          close zero_waiting_count_cur;
        end;
      end if;
  
      sample_total := 
        nvl(histo_rec.bucket1,0) + nvl(histo_rec.bucket2,0) +
        nvl(histo_rec.bucket3,0) + nvl(histo_rec.bucket4,0) +
        nvl(histo_rec.bucket5,0) + nvl(histo_rec.bucket6,0) +
        nvl(histo_rec.bucket7,0) + nvl(histo_rec.bucket8,0) +
        nvl(histo_rec.bucket9,0);
  
      if (sample_total != 0)
      then

        message := to_char(sample_total, 999999);

        if (include_zero_only_bucket = 1)
        then
          -- include the zero-only bucket and an adjusted value for bucket 1
          message := message || to_char(100.0 * zero_waiting_count / sample_total, '99999') || '%';
          message := message || to_char(100.0 * (nvl(histo_rec.bucket1,0) - zero_waiting_count) / sample_total, '99999') || '%';
        else
          -- exclude the zero-only bucket and only include the the value for bucket 1
          message := message || to_char(100.0 * nvl(histo_rec.bucket1,0) / sample_total, '99999') || '%';
        end if;

        message := message ||          
          to_char(100.0 * nvl(histo_rec.bucket2,0) / sample_total, '99999') || '%' ||
          to_char(100.0 * nvl(histo_rec.bucket3,0) / sample_total, '99999') || '%' ||
          to_char(100.0 * nvl(histo_rec.bucket4,0) / sample_total, '99999') || '%' ||
          to_char(100.0 * nvl(histo_rec.bucket5,0) / sample_total, '99999') || '%' ||
          to_char(100.0 * nvl(histo_rec.bucket6,0) / sample_total, '99999') || '%' ||
          to_char(100.0 * nvl(histo_rec.bucket7,0) / sample_total, '99999') || '%' ||
          to_char(100.0 * nvl(histo_rec.bucket8,0) / sample_total, '99999') || '%' ||
          to_char(100.0 * nvl(histo_rec.bucket9,0) / sample_total, '99999') || '%';
        DBMS_OUTPUT.put_line(message);

      end if;
    end loop;

  end;

  GOTO finish;

  <<create_histogram_by_cg>>

  declare

    cg_sample_total          simple_integer := 0;
    include_zero_only_bucket simple_integer := 0;
    cg_zero_waiting_count    simple_integer := 0;

    CURSOR histo_cur IS
      select   *
      from     (with     desired_ash_samples as
                         (select    sample_id, consumer_group_id, session_state, event
                          from      v$active_session_history
                          where     use_vdollar_ash = 1
                                    and sample_time >= histo_start_time and sample_time <= histo_end_time
                          union all
                          select    sample_id, consumer_group_id, session_state, event
                          from      dba_hist_active_sess_history
                          where     use_dba_hist_ash = 1
                                    and sample_time >= histo_start_time and sample_time <= histo_end_time)
                select   consumer_group, bucket, bucket_count
                from     (select   consumer_group, bucket, count(bucket) "BUCKET_COUNT"
                          from     (select consumer_group,
                                           width_bucket(sample_sum, bucket_min, bucket_max, num_buckets) "BUCKET"
                                    from    (select   consumer_group, sample_sum
                                             from     (select   substr(cgs.consumer_group,1,25) "CONSUMER_GROUP", ash.sample_id,
                                                                sum(case when (include_rng = 1
                                                                               and ash.consumer_group_id is not NULL
                                                                               and ash.session_state='ON CPU'
                                                                               and nvl(ash.event, 'ON CPU') = 'ON CPU')
                                                                         or   (include_rbl = 1
                                                                               and ash.consumer_group_id is not NULL
                                                                               and ash.session_state='WAITING'
                                                                               and nvl(ash.event, 'ON CPU') = 'resmgr:cpu quantum')
                                                                    then 1
                                                                    else 0
                                                                    end) "SAMPLE_SUM"
                                                       from     (select   sample_id, consumer_group_id, session_state, event
                                                                 from     (select   a.sample_id, b.consumer_group_id,
                                                                                    '-' "EVENT", '-' "SESSION_STATE"
                                                                           from     (select distinct sample_id
                                                                                     from   desired_ash_samples) a,
                                                                                    (select distinct consumer_group_id
                                                                                     from   desired_ash_samples) b)
                                                                 union all
                                                                 select   sample_id, consumer_group_id, session_state, event
                                                                 from     desired_ash_samples) ash,
                                                                dba_rsrc_consumer_groups cgs
                                                       where    ash.consumer_group_id is not null
                                                                and ash.consumer_group_id = cgs.consumer_group_id
                                                       group by cgs.consumer_group, ash.sample_id
                                                       order by cgs.consumer_group desc, ash.sample_id)))
                          group by consumer_group, bucket
                          order by consumer_group, bucket)
                order by consumer_group, bucket)
      PIVOT(sum(bucket_count)
      FOR bucket in ('1' "BUCKET1", '2' "BUCKET2", '3' "BUCKET3", '4' "BUCKET4", '5' "BUCKET5",
                     '6' "BUCKET6", '7' "BUCKET7", '8' "BUCKET8", '9' "BUCKET9"))
      order by consumer_group;

  begin

    -- Should we include the extra, zero-only bucket?  This is included if this is a wait-load
    -- histogram and the each normal bucket has a range greater than 1.
    if (include_rng = 0 and include_rbl = 1 and bucket_max > num_buckets)
    then
      include_zero_only_bucket := 1;
    else
      include_zero_only_bucket := 0;
    end if;

    DBMS_OUTPUT.put_line('');
    DBMS_OUTPUT.put_line('###############################################################################################');
    if (include_rng = 1 and include_rbl = 1)
    then
      DBMS_OUTPUT.put_line('# LOAD HISTOGRAM BY CONSUMER GROUP FOR: ' || database_description);
      DBMS_OUTPUT.put_line('#');
      DBMS_OUTPUT.put_line('# The table below is a histogram by consumer group of the total load managed by Resource');
      DBMS_OUTPUT.put_line('# Manager (i.e., the count of sessions running on CPU or waiting for CPU).  For each');
      DBMS_OUTPUT.put_line('# consumer group, the percentage of the total consumer group samples is shown for each');
      DBMS_OUTPUT.put_line('# histogram bucket.');
    else
      DBMS_OUTPUT.put_line('# WAIT LOAD HISTOGRAM BY CONSUMER GROUP FOR: ' || database_description);
      DBMS_OUTPUT.put_line('#');
      DBMS_OUTPUT.put_line('# The table below is a histogram by consumer group of the wait load managed by Resource');
      DBMS_OUTPUT.put_line('# Manager (i.e., the count of sessions waiting for CPU).  For each consumer group, the');
      DBMS_OUTPUT.put_line('# percentage of the total consumer group samples is shown for each histogram bucket.');
    end if;
    DBMS_OUTPUT.put_line('#');
    DBMS_OUTPUT.put_line(sample_source_message);
    DBMS_OUTPUT.put_line('#');
    DBMS_OUTPUT.put_line('');
    if (include_rng = 1 and include_rbl = 1)
    then
      DBMS_OUTPUT.put_line('                                 --------------------------------------------------------------');
      DBMS_OUTPUT.put_line('                                 |     Number of sessions running on or waiting for CPU       |');
      DBMS_OUTPUT.put_line('                                 |                                                            |');
      DBMS_OUTPUT.put_line('                                 | Light <------------------- LOAD -------------------> Heavy |');
      DBMS_OUTPUT.put_line('                                 --------------------------------------------------------------');
    else
      if (include_zero_only_bucket = 1)
      then
        DBMS_OUTPUT.put_line('                                 ---------------------------------------------------------------------');
        DBMS_OUTPUT.put_line('                                 |                 Number of sessions waiting for CPU                |');
        DBMS_OUTPUT.put_line('                                 |                                                                   |');
        DBMS_OUTPUT.put_line('                                 | Light <-------------------- WAIT LOAD --------------------> Heavy |');
        DBMS_OUTPUT.put_line('                                 ---------------------------------------------------------------------');
      else
        DBMS_OUTPUT.put_line('                                 --------------------------------------------------------------');
        DBMS_OUTPUT.put_line('                                 |            Number of sessions waiting for CPU              |');
        DBMS_OUTPUT.put_line('                                 |                                                            |');
        DBMS_OUTPUT.put_line('                                 | Light <---------------- WAIT LOAD -----------------> Heavy |');
        DBMS_OUTPUT.put_line('                                 --------------------------------------------------------------');
      end if;
    end if;

    message := '                         Total   ';
    i := bucket_min;
    while (i < num_buckets)
    loop
      if (include_zero_only_bucket = 1 and i = bucket_min)
      then
        message := message || lpad(0, 6) || ' ';
        message := message || lpad((((bucket_max - bucket_min) / num_buckets) * i) + 1, 6) || ' ';
      else
        message := message || lpad(((bucket_max - bucket_min) / num_buckets) * i, 6) || ' ';
      end if;
      i := i + 1;
    end loop;
    DBMS_OUTPUT.put_line(message);

    message := 'CONSUMER_GROUP           Samples ';
    i := bucket_min;
    while (i < num_buckets)
    loop
      if (include_zero_only_bucket = 1 and i = bucket_min)
      then
        message := message || lpad('<= ' || 0, 6) || ' ';
        message := message || lpad('<= ' || ((((bucket_max - bucket_min) / num_buckets) * (i + 1)) - 1 + 1), 6) || ' ';
      else
        message := message || lpad('<= ' || ((((bucket_max - bucket_min) / num_buckets) * (i + 1)) - 1), 6) || ' ';
      end if;
      i := i + 1;
    end loop;
    message := message || lpad('>= ' || bucket_max, 6);
    DBMS_OUTPUT.put_line(message);

    message := '------------------------ ------- ';
    i := bucket_min;
    while (i < num_buckets + 1)
    loop
      if (include_zero_only_bucket = 1 and i = bucket_min)
      then
        message := message || '------ ';
      end if;
      message := message || '------ ';
      i := i + 1;
    end loop;
    DBMS_OUTPUT.put_line(message);

    for histo_rec in histo_cur
    loop

      -- if we are including the zero-only bucket, create the count of samples for this consumer
      -- group where the sample_sum is zero
      if (include_zero_only_bucket = 1)
      then
        declare
          CURSOR cg_zero_waiting_count_cur IS
            with     desired_ash_samples as
                     (select    sample_id, consumer_group_id, session_state, event
                      from      v$active_session_history
                      where     use_vdollar_ash = 1
                                and sample_time >= histo_start_time and sample_time <= histo_end_time
                      union all
                      select    sample_id, consumer_group_id, session_state, event
                      from      dba_hist_active_sess_history
                      where     use_dba_hist_ash = 1
                                and sample_time >= histo_start_time and sample_time <= histo_end_time)
            select   count(*)
            from     (select   substr(cgs.consumer_group,1,25) "CONSUMER_GROUP", ash.sample_id,
                               sum(case when (ash.consumer_group_id is not NULL
                                              and ash.session_state='WAITING'
                                              and nvl(ash.event, 'ON CPU') = 'resmgr:cpu quantum')
                                   then 1
                                   else 0
                                   end) "SAMPLE_SUM"
                      from     (select   sample_id, consumer_group_id, session_state, event
                                from     (select   a.sample_id, b.consumer_group_id,
                                                   '-' "EVENT", '-' "SESSION_STATE"
                                          from     (select distinct sample_id
                                                    from   desired_ash_samples) a,
                                                   (select distinct consumer_group_id
                                                    from   desired_ash_samples) b)
                                union all
                                select   sample_id, consumer_group_id, session_state, event
                                from     desired_ash_samples) ash,
                               dba_rsrc_consumer_groups cgs
                      where    ash.consumer_group_id is not null
                               and ash.consumer_group_id = cgs.consumer_group_id
                      group by cgs.consumer_group, ash.sample_id
                      order by cgs.consumer_group desc, ash.sample_id)
            where     sample_sum = 0 and consumer_group = histo_rec.consumer_group;
  
        begin
          open cg_zero_waiting_count_cur;
          fetch cg_zero_waiting_count_cur into cg_zero_waiting_count;
          close cg_zero_waiting_count_cur;
        end;
      end if;
  
      cg_sample_total := 
        nvl(histo_rec.bucket1,0) + nvl(histo_rec.bucket2,0) +
        nvl(histo_rec.bucket3,0) + nvl(histo_rec.bucket4,0) +
        nvl(histo_rec.bucket5,0) + nvl(histo_rec.bucket6,0) +
        nvl(histo_rec.bucket7,0) + nvl(histo_rec.bucket8,0) +
        nvl(histo_rec.bucket9,0);
  
      if (cg_sample_total != 0)
      then

        message := rpad(histo_rec.consumer_group, 24) || to_char(cg_sample_total, 9999999);

        if (include_zero_only_bucket = 1)
        then
          -- include the zero-only bucket and an adjusted value for bucket 1
          message := message || to_char(100.0 * cg_zero_waiting_count / cg_sample_total, '99999') || '%';
          message := message || to_char(100.0 * (nvl(histo_rec.bucket1,0) - cg_zero_waiting_count) / cg_sample_total, '99999') || '%';
        else
          -- exclude the zero-only bucket and only include the the value for bucket 1
          message := message || to_char(100.0 * nvl(histo_rec.bucket1,0) / cg_sample_total, '99999') || '%';
        end if;

        message := message ||          
          to_char(100.0 * nvl(histo_rec.bucket2,0) / cg_sample_total, '99999') || '%' ||
          to_char(100.0 * nvl(histo_rec.bucket3,0) / cg_sample_total, '99999') || '%' ||
          to_char(100.0 * nvl(histo_rec.bucket4,0) / cg_sample_total, '99999') || '%' ||
          to_char(100.0 * nvl(histo_rec.bucket5,0) / cg_sample_total, '99999') || '%' ||
          to_char(100.0 * nvl(histo_rec.bucket6,0) / cg_sample_total, '99999') || '%' ||
          to_char(100.0 * nvl(histo_rec.bucket7,0) / cg_sample_total, '99999') || '%' ||
          to_char(100.0 * nvl(histo_rec.bucket8,0) / cg_sample_total, '99999') || '%' ||
          to_char(100.0 * nvl(histo_rec.bucket9,0) / cg_sample_total, '99999') || '%';
        DBMS_OUTPUT.put_line(message);

      end if;  

    end loop;

  end;
  GOTO finish;

$IF DBMS_DB_VERSION.VERSION >= 12
$THEN
  <<create_histogram_by_container>>

  declare

    container_sample_total    simple_integer := 0;
    include_zero_only_bucket  simple_integer := 0;
    container_zero_wt_cnt     simple_integer := 0;

    CURSOR histo_cur IS
      select   *
      from     (with     desired_ash_samples as
                         (select    con_id, sample_id, consumer_group_id, session_state, event
                          from      v$active_session_history
                          where     use_vdollar_ash = 1
                                    and sample_time >= histo_start_time and sample_time <= histo_end_time
                          union all
                          select    con_id, sample_id, consumer_group_id, session_state, event
                          from      dba_hist_active_sess_history
                          where     use_dba_hist_ash = 1
                                    and sample_time >= histo_start_time and sample_time <= histo_end_time)
                select   container, bucket, bucket_count
                from     (select    container, bucket, count(bucket) "BUCKET_COUNT"
                          from      (select container,
                                            width_bucket(sample_sum, bucket_min, bucket_max, num_buckets) "BUCKET"
                                     from    (select   container, sample_sum
                                              from     (select   substr(cons.name,1,25) "CONTAINER", ash.sample_id,
                                                                 sum(case when (include_rng = 1
                                                                                and ash.consumer_group_id is not NULL
                                                                                and ash.session_state='ON CPU'
                                                                                and nvl(ash.event, 'ON CPU') = 'ON CPU')
                                                                          or   (include_rbl = 1
                                                                                and ash.consumer_group_id is not NULL
                                                                                and ash.session_state='WAITING'
                                                                                and nvl(ash.event, 'ON CPU') = 'resmgr:cpu quantum')
                                                                     then 1
                                                                     else 0
                                                                     end) "SAMPLE_SUM"
                                                        from     (select   sample_id, con_id, consumer_group_id, session_state, event
                                                                  from     (select   a.sample_id, b.con_id, 0 "CONSUMER_GROUP_ID",
                                                                                     '-' "EVENT", '-' "SESSION_STATE"
                                                                            from     (select distinct sample_id
                                                                                      from   desired_ash_samples) a,
                                                                                     (select distinct con_id
                                                                                      from   desired_ash_samples) b)
                                                                  union all
                                                                  select   sample_id, con_id, consumer_group_id, session_state, event
                                                                  from     desired_ash_samples) ash,
                                                                           v$containers cons
                                                        where    ash.consumer_group_id is not null
                                                                 and ash.con_id = cons.con_id
                                                        group by cons.name, ash.sample_id
                                                        order by cons.name desc, ash.sample_id)))
                          group by container, bucket
                          order by container, bucket)
                order by container, bucket)
      PIVOT(sum(bucket_count)
      FOR bucket in ('1' "BUCKET1", '2' "BUCKET2", '3' "BUCKET3", '4' "BUCKET4", '5' "BUCKET5",
                     '6' "BUCKET6", '7' "BUCKET7", '8' "BUCKET8", '9' "BUCKET9"))
      order by container;

  begin

    -- make sure we are in a CDB
    --
    if (upper(is_cdb) != 'YES')
    then
      DBMS_OUTPUT.put_line(CHR(10) || 'ERROR: A container histogram was requested, but this is not a container database.');
      GOTO finish;
    end if;

    -- make sure we are running in the ROOT container
    --
    if (upper(current_container_name) != 'CDB$ROOT')
    then
      DBMS_OUTPUT.put_line(CHR(10) || 'ERROR: A container histogram was requested, but the current container is not CDB$ROOT.');
      GOTO finish;
    end if;

    -- Should we include the extra, zero-only bucket?  This is included if this is a wait-load
    -- histogram and the each normal bucket has a range greater than 1.
    if (include_rng = 0 and include_rbl = 1 and bucket_max > num_buckets)
    then
      include_zero_only_bucket := 1;
    else
      include_zero_only_bucket := 0;
    end if;

    DBMS_OUTPUT.put_line('');
    DBMS_OUTPUT.put_line('###############################################################################################');
    if (include_rng = 1 and include_rbl = 1)
    then
      DBMS_OUTPUT.put_line('# LOAD HISTOGRAM BY CONTAINER FOR: ' || instance_name);
      DBMS_OUTPUT.put_line('#');
      DBMS_OUTPUT.put_line('# The table below is a histogram by container of the total load managed by Resource');
      DBMS_OUTPUT.put_line('# Manager (i.e., the count of sessions running on CPU or waiting for CPU).  For each,');
      DBMS_OUTPUT.put_line('# container the percentage of the total container samples is shown for each histogram.');
      DBMS_OUTPUT.put_line('# bucket.');
    else
      DBMS_OUTPUT.put_line('# WAIT LOAD HISTOGRAM BY CONTAINER FOR: ' || instance_name);
      DBMS_OUTPUT.put_line('#');
      DBMS_OUTPUT.put_line('# The table below is a histogram by container of the wait load managed by Resource');
      DBMS_OUTPUT.put_line('# Manager (i.e., the count of sessions waiting for CPU).  For each container, the');
      DBMS_OUTPUT.put_line('# percentage of the total container samples is shown for each histogram bucket.');
    end if;
    DBMS_OUTPUT.put_line('#');
    DBMS_OUTPUT.put_line(sample_source_message);
    DBMS_OUTPUT.put_line('#');
    DBMS_OUTPUT.put_line('');
    if (include_rng = 1 and include_rbl = 1)
    then
      DBMS_OUTPUT.put_line('                                 --------------------------------------------------------------');
      DBMS_OUTPUT.put_line('                                 |     Number of sessions running on or waiting for CPU       |');
      DBMS_OUTPUT.put_line('                                 |                                                            |');
      DBMS_OUTPUT.put_line('                                 | Light <------------------- LOAD -------------------> Heavy |');
      DBMS_OUTPUT.put_line('                                 --------------------------------------------------------------');
    else
      if (include_zero_only_bucket = 1)
      then
        DBMS_OUTPUT.put_line('                                 ---------------------------------------------------------------------');
        DBMS_OUTPUT.put_line('                                 |                 Number of sessions waiting for CPU                |');
        DBMS_OUTPUT.put_line('                                 |                                                                   |');
        DBMS_OUTPUT.put_line('                                 | Light <-------------------- WAIT LOAD --------------------> Heavy |');
        DBMS_OUTPUT.put_line('                                 ---------------------------------------------------------------------');
      else
        DBMS_OUTPUT.put_line('                                 --------------------------------------------------------------');
        DBMS_OUTPUT.put_line('                                 |            Number of sessions waiting for CPU              |');
        DBMS_OUTPUT.put_line('                                 |                                                            |');
        DBMS_OUTPUT.put_line('                                 | Light <---------------- WAIT LOAD -----------------> Heavy |');
        DBMS_OUTPUT.put_line('                                 --------------------------------------------------------------');
      end if;
    end if;

    message := '                         Total   ';
    i := bucket_min;
    while (i < num_buckets)
    loop
      if (include_zero_only_bucket = 1 and i = bucket_min)
      then
        message := message || lpad(0, 6) || ' ';
        message := message || lpad((((bucket_max - bucket_min) / num_buckets) * i) + 1, 6) || ' ';
      else
        message := message || lpad(((bucket_max - bucket_min) / num_buckets) * i, 6) || ' ';
      end if;
      i := i + 1;
    end loop;
    DBMS_OUTPUT.put_line(message);

    message := 'CONTAINER                Samples ';
    i := bucket_min;
    while (i < num_buckets)
    loop
      if (include_zero_only_bucket = 1 and i = bucket_min)
      then
        message := message || lpad('<= ' || 0, 6) || ' ';
        message := message || lpad('<= ' || ((((bucket_max - bucket_min) / num_buckets) * (i + 1)) - 1 + 1), 6) || ' ';
      else
        message := message || lpad('<= ' || ((((bucket_max - bucket_min) / num_buckets) * (i + 1)) - 1), 6) || ' ';
      end if;
      i := i + 1;
    end loop;
    message := message || lpad('>= ' || bucket_max, 6);
    DBMS_OUTPUT.put_line(message);

    message := '------------------------ ------- ';
    i := bucket_min;
    while (i < num_buckets + 1)
    loop
      if (include_zero_only_bucket = 1 and i = bucket_min)
      then
        message := message || '------ ';
      end if;
      message := message || '------ ';
      i := i + 1;
    end loop;
    DBMS_OUTPUT.put_line(message);

    for histo_rec in histo_cur
    loop

      -- if we are including the zero-only bucket, create the count of samples for this
      -- container where the sample_sum is zero
      if (include_zero_only_bucket = 1)
      then
        declare
          CURSOR container_zero_wt_cnt_cur IS
            with     desired_ash_samples as
                     (select    con_id, sample_id, consumer_group_id, session_state, event
                      from      v$active_session_history
                      where     use_vdollar_ash = 1
                                and sample_time >= histo_start_time and sample_time <= histo_end_time
                      union all
                      select    con_id, sample_id, consumer_group_id, session_state, event
                      from      dba_hist_active_sess_history
                      where     use_dba_hist_ash = 1
                                and sample_time >= histo_start_time and sample_time <= histo_end_time)
            select   count(*)
            from     (select   substr(cons.name,1,25) "CONTAINER", ash.sample_id,
                               sum(case when (ash.consumer_group_id is not NULL
                                              and ash.session_state='WAITING'
                                              and nvl(ash.event, 'ON CPU') = 'resmgr:cpu quantum')
                                   then 1
                                   else 0
                                   end) "SAMPLE_SUM"
                      from     (select   sample_id, con_id, consumer_group_id, session_state, event
                                from     (select   a.sample_id, b.con_id, 0 "CONSUMER_GROUP_ID",
                                                   '-' "EVENT", '-' "SESSION_STATE"
                                          from     (select distinct sample_id
                                                    from   desired_ash_samples) a,
                                                   (select distinct con_id
                                                    from   desired_ash_samples) b)
                                union all
                                select   sample_id, con_id, consumer_group_id, session_state, event
                                from     desired_ash_samples) ash,
                               v$containers cons
                      where    ash.consumer_group_id is not null
                               and ash.con_id = cons.con_id
                      group by cons.name, ash.sample_id
                      order by cons.name desc, ash.sample_id)
            where     sample_sum = 0 and container = histo_rec.container;
  
        begin
          open container_zero_wt_cnt_cur;
          fetch container_zero_wt_cnt_cur into container_zero_wt_cnt;
          close container_zero_wt_cnt_cur;
        end;
      end if;
  
      container_sample_total := 
        nvl(histo_rec.bucket1,0) + nvl(histo_rec.bucket2,0) +
        nvl(histo_rec.bucket3,0) + nvl(histo_rec.bucket4,0) +
        nvl(histo_rec.bucket5,0) + nvl(histo_rec.bucket6,0) +
        nvl(histo_rec.bucket7,0) + nvl(histo_rec.bucket8,0) +
        nvl(histo_rec.bucket9,0);
  
      if (container_sample_total != 0)
      then

        message := rpad(histo_rec.container, 24) || to_char(container_sample_total, 9999999);

        if (include_zero_only_bucket = 1)
        then
          -- include the zero-only bucket and an adjusted value for bucket 1
          message := message || to_char(100.0 * container_zero_wt_cnt / container_sample_total, '99999') || '%';
          message := message || to_char(100.0 * (nvl(histo_rec.bucket1,0) - container_zero_wt_cnt) / container_sample_total, '99999') || '%';
        else
          -- exclude the zero-only bucket and only include the the value for bucket 1
          message := message || to_char(100.0 * nvl(histo_rec.bucket1,0) / container_sample_total, '99999') || '%';
        end if;

        message := message ||          
          to_char(100.0 * nvl(histo_rec.bucket2,0) / container_sample_total, '99999') || '%' ||
          to_char(100.0 * nvl(histo_rec.bucket3,0) / container_sample_total, '99999') || '%' ||
          to_char(100.0 * nvl(histo_rec.bucket4,0) / container_sample_total, '99999') || '%' ||
          to_char(100.0 * nvl(histo_rec.bucket5,0) / container_sample_total, '99999') || '%' ||
          to_char(100.0 * nvl(histo_rec.bucket6,0) / container_sample_total, '99999') || '%' ||
          to_char(100.0 * nvl(histo_rec.bucket7,0) / container_sample_total, '99999') || '%' ||
          to_char(100.0 * nvl(histo_rec.bucket8,0) / container_sample_total, '99999') || '%' ||
          to_char(100.0 * nvl(histo_rec.bucket9,0) / container_sample_total, '99999') || '%';
        DBMS_OUTPUT.put_line(message);

      end if;  
    end loop;

  end;
  GOTO finish;
$END

  <<finish>>
  NULL;

end;
/

