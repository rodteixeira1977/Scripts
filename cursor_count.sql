select * from (
select inst_id,
       sid,
       user_name,
       count(1)
from   gv$open_cursor
group by inst_id, sid, user_name
order by count(1) desc )
where rownum < 10
/
