col data for a10;
set lines 400;
col 01 for a4;
col 02 for a4;
col 03 for a4;
col 04 for a4;
col 05 for a4;
col 06 for a4;
col 07 for a4;
col 08 for a4;
col 09 for a4;
col 10 for a4;
col 11 for a4;
col 12 for a4;
col 13 for a4;
col 14 for a4;
col 15 for a4;
col 16 for a4;
col 17 for a4;
col 18 for a4;
col 19 for a4;
col 20 for a4;
col 21 for a4;
col 22 for a4;
col 23 for a4;
col 24 for a4;
col TOTAL for a5;
set pages 1000
COMPUTE AVG OF TOTAL ON REPORT
COMPUTE AVG OF 01        ON REPORT
COMPUTE AVG OF 02        ON REPORT
COMPUTE AVG OF 03        ON REPORT
COMPUTE AVG OF 04        ON REPORT
COMPUTE AVG OF 05        ON REPORT
COMPUTE AVG OF 06        ON REPORT
COMPUTE AVG OF 07        ON REPORT
COMPUTE AVG OF 08        ON REPORT
COMPUTE AVG OF 09        ON REPORT
COMPUTE AVG OF 10        ON REPORT
COMPUTE AVG OF 11        ON REPORT
COMPUTE AVG OF 12        ON REPORT
COMPUTE AVG OF 13        ON REPORT
COMPUTE AVG OF 14        ON REPORT
COMPUTE AVG OF 15        ON REPORT
COMPUTE AVG OF 16        ON REPORT
COMPUTE AVG OF 17        ON REPORT
COMPUTE AVG OF 18        ON REPORT
COMPUTE AVG OF 19        ON REPORT
COMPUTE AVG OF 20        ON REPORT
COMPUTE AVG OF 21        ON REPORT
COMPUTE AVG OF 22        ON REPORT
COMPUTE AVG OF 23        ON REPORT
select to_char(first_time,'yyyymmdd') Data,
decode(sum(decode(to_char(first_time,'hh24'),'00',1,0)),0,'-',sum(decode(to_char(first_time,'hh24'),'00',1,0))) "01",
decode(sum(decode(to_char(first_time,'hh24'),'01',1,0)),0,'-',sum(decode(to_char(first_time,'hh24'),'01',1,0))) "02",
decode(sum(decode(to_char(first_time,'hh24'),'02',1,0)),0,'-',sum(decode(to_char(first_time,'hh24'),'02',1,0))) "03",
decode(sum(decode(to_char(first_time,'hh24'),'03',1,0)),0,'-',sum(decode(to_char(first_time,'hh24'),'03',1,0))) "04",
decode(sum(decode(to_char(first_time,'hh24'),'04',1,0)),0,'-',sum(decode(to_char(first_time,'hh24'),'04',1,0))) "05",
decode(sum(decode(to_char(first_time,'hh24'),'05',1,0)),0,'-',sum(decode(to_char(first_time,'hh24'),'05',1,0))) "06",
decode(sum(decode(to_char(first_time,'hh24'),'06',1,0)),0,'-',sum(decode(to_char(first_time,'hh24'),'06',1,0))) "07",
decode(sum(decode(to_char(first_time,'hh24'),'07',1,0)),0,'-',sum(decode(to_char(first_time,'hh24'),'07',1,0))) "08",
decode(sum(decode(to_char(first_time,'hh24'),'08',1,0)),0,'-',sum(decode(to_char(first_time,'hh24'),'08',1,0))) "09",
decode(sum(decode(to_char(first_time,'hh24'),'09',1,0)),0,'-',sum(decode(to_char(first_time,'hh24'),'09',1,0))) "10",
decode(sum(decode(to_char(first_time,'hh24'),'10',1,0)),0,'-',sum(decode(to_char(first_time,'hh24'),'10',1,0))) "11",
decode(sum(decode(to_char(first_time,'hh24'),'11',1,0)),0,'-',sum(decode(to_char(first_time,'hh24'),'11',1,0))) "12",
decode(sum(decode(to_char(first_time,'hh24'),'12',1,0)),0,'-',sum(decode(to_char(first_time,'hh24'),'12',1,0))) "13",
decode(sum(decode(to_char(first_time,'hh24'),'13',1,0)),0,'-',sum(decode(to_char(first_time,'hh24'),'13',1,0))) "14",
decode(sum(decode(to_char(first_time,'hh24'),'14',1,0)),0,'-',sum(decode(to_char(first_time,'hh24'),'14',1,0))) "15",
decode(sum(decode(to_char(first_time,'hh24'),'15',1,0)),0,'-',sum(decode(to_char(first_time,'hh24'),'15',1,0))) "16",
decode(sum(decode(to_char(first_time,'hh24'),'16',1,0)),0,'-',sum(decode(to_char(first_time,'hh24'),'16',1,0))) "17",
decode(sum(decode(to_char(first_time,'hh24'),'17',1,0)),0,'-',sum(decode(to_char(first_time,'hh24'),'17',1,0))) "18",
decode(sum(decode(to_char(first_time,'hh24'),'18',1,0)),0,'-',sum(decode(to_char(first_time,'hh24'),'18',1,0))) "19",
decode(sum(decode(to_char(first_time,'hh24'),'19',1,0)),0,'-',sum(decode(to_char(first_time,'hh24'),'19',1,0))) "20",
decode(sum(decode(to_char(first_time,'hh24'),'20',1,0)),0,'-',sum(decode(to_char(first_time,'hh24'),'20',1,0))) "21",
decode(sum(decode(to_char(first_time,'hh24'),'21',1,0)),0,'-',sum(decode(to_char(first_time,'hh24'),'21',1,0))) "22",
decode(sum(decode(to_char(first_time,'hh24'),'22',1,0)),0,'-',sum(decode(to_char(first_time,'hh24'),'22',1,0))) "23",
decode(sum(decode(to_char(first_time,'hh24'),'23',1,0)),0,'-',sum(decode(to_char(first_time,'hh24'),'23',1,0))) "24",
decode(count(*),0,'-',count(*)) "TOTAL",
round((count(*) * (select * from (select bytes/1024/1024/1024 from v$log group by bytes) where rownum <=1))) GB
from v$log_history
group by to_char(first_time,'yyyymmdd')
order by 1 desc;


