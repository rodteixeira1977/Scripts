SELECT ARCH.INST_ID, ARCH.THREAD# "Thread", ARCH.SEQUENCE# "Last Sequence Received", APPL.SEQUENCE# "Last Sequence Applied", (ARCH.SEQUENCE# - APPL.SEQUENCE#) "Difference"
FROM
(SELECT INST_ID,THREAD# ,SEQUENCE# FROM GV$ARCHIVED_LOG WHERE (INST_ID,THREAD#,FIRST_TIME ) IN (SELECT INST_ID,THREAD#,MAX(FIRST_TIME) FROM gV$ARCHIVED_LOG GROUP BY INST_ID,THREAD#)) ARCH,
(SELECT INST_ID,THREAD# ,SEQUENCE# FROM GV$LOG_HISTORY WHERE (INST_ID,THREAD#,FIRST_TIME ) IN (SELECT INST_ID,THREAD#,MAX(FIRST_TIME) FROM gV$LOG_HISTORY GROUP BY INST_ID,THREAD#)) APPL
WHERE
ARCH.THREAD# = APPL.THREAD#
ORDER BY 1;
