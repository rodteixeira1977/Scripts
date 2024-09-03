	REM This script is to find load average from time model tables.
REM  Need more work since this  can use  analytic functions
REM Colsep is set to |
set colsep "|"
SELECT beg.begin_interval_time,
  (end1.VALUE-beg.VALUE)/
   (
    EXTRACT (DAY   FROM  (end1.begin_interval_time-beg.begin_interval_time))*3600*24 +
    EXTRACT (HOUR   FROM  (end1.begin_interval_time-beg.begin_interval_time))*3600 +
    EXTRACT (MINUTE FROM  (end1.begin_interval_time-beg.begin_interval_time))*60 +
    EXTRACT (SECOND FROM  (end1.begin_interval_time-beg.begin_interval_time)) 
    ) /1000000  cpu_load
 FROM
( SELECT systime.*, snaps.begin_interval_time 
  FROM DBA_HIST_SYS_TIME_MODEL systime  , DBA_HIST_SNAPSHOT snaps 
  WHERE stat_id=2748282437
  AND  systime.snap_id =snaps.snap_id ) beg,
( SELECT systime.*, snaps.begin_interval_time 
  FROM DBA_HIST_SYS_TIME_MODEL systime  , DBA_HIST_SNAPSHOT snaps 
  WHERE stat_id=2748282437
  AND  systime.snap_id =snaps.snap_id ) end1
WHERE beg.snap_id=end1.snap_id-1  
--AND TO_NUMBER( TO_CHAR(beg.begin_interval_time,'HH24') ) BETWEEN 10 AND 17
ORDER BY 1
/



REM

ith stats as (
select begin_interval_time, instance_number, snap_id,
   case when stat_name='DB CPU' then
      value - lag(value,1,0) over( partition by stat_id, dbid, instance_number ,startup_time order by snap_id )
    end dbcpu,
   case when stat_name='DB time' then
      value - lag(value,1,0) over( partition by stat_id, dbid, instance_number ,startup_time order by snap_id )
    end dbtime,
   case when stat_name='background elapsed time' then
      value - lag(value,1,0) over( partition by stat_id, dbid, instance_number ,startup_time order by snap_id )
    end dbbgela,
   case when stat_name='background cpu time' then
      value - lag(value,1,0) over( partition by stat_id, dbid, instance_number ,startup_time order by snap_id )
    end dbbgcpu
from
(
select h.begin_interval_time, s.snap_id, s.dbid, s.instance_number, s.stat_id, s.stat_name, value, startup_time
  FROM DBA_HIST_SYS_TIME_MODEL s  , DBA_HIST_SNAPSHOT h
where
  s.instance_number = h.instance_number and
  s.snap_id = h.snap_id and
  s.dbid = h.dbid and
  s.stat_name in ('DB time','DB CPU','background elapsed time','background cpu time') and
  h.begin_interval_time > sysdate -1
  order by stat_id, instance_number,snap_id
 )
)
select  begin_interval_time, instance_number, max(dbcpu), max(dbtime),max(dbbgela),max(dbbgcpu)
  from stats
group by begin_interval_time, instance_number
order by instance_number, begin_interval_time
/
