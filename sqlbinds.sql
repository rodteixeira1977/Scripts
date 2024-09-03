-- Copyright 2018 Tanel Poder. All rights reserved. More info at http://tanelpoder.com
-- Licensed under the Apache License, Version 2.0. See LICENSE.txt for terms & conditions.

prompt Show captured binds from V$SQL_BIND_CAPTURE...

COL sqlbinds_name HEAD NAME FOR A15
COL value_string  FOR A100
COL value_anydata FOR A100
COL sqlbinds_pos  HEAD POS FOR 9999
COL sqlbinds_chld HEAD CHLD FOR 9999
COL sqlbinds_datatype HEAD DATATYPE FOR A15
BREAK ON sqlbinds_chld SKIP 1

SELECT
--  ADDRESS         parent_cursor
--  SQL_ID              
  CHILD_NUMBER    sqlbinds_chld    
, POSITION        sqlbinds_pos       
, NAME            sqlbinds_name              
--, DUP_POSITION        
--, DATATYPE            
, DATATYPE_STRING sqlbinds_datatype 
, CHARACTER_SID       
, MAX_LENGTH          
, PRECISION           
, SCALE               
, VALUE_STRING        
, WAS_CAPTURED        
, LAST_CAPTURED       
, VALUE_ANYDATA  
FROM
  v$sql_bind_capture c
WHERE
    sql_id like '&1'
AND child_number like '&2'
AND (c.name like '&3' escape '\' OR REGEXP_LIKE(name, '&3', 'i'))
ORDER BY
     address
  ,  sql_id
  , child_number
  , position
/
