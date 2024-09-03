col owner for a15
col object_name for a30
col created for a20

select owner, object_name, object_type, created, status, to_char(last_ddl_time, 'dd-mm-yyyy hh24:mi:ss')last_ddl_time 
from dba_objects where object_name=upper('&name_obj');

