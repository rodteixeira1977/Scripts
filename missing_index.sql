# Missing index
# If you want to be more precise in your analyze you can limit the list to table containing more than a defined number of rows by adding the dba_tables table and filter on the num_rows column.
#

select * from (
  select 'the column ' || c.name || ' of the table ' || us.name || '.' || o.name || ' was used ' || u.equality_preds || ' times in an equality predicate and ' || u.equijoin_preds || ' times in an equijoin predicate and is not indexed' as colum_to_index
  from sys.col_usage$ u,
       sys.obj$ o,
       sys.col$ c,
       sys.user$ us
  where u.obj# = o.obj#
  and   u.obj# = c.obj#
  and   us.user# = o.owner#
  and   u.intcol# = c.col#
  and   us.name='&SCHEMA_NAME'
  and   c.name not in (select column_name from dba_ind_columns where index_owner ='&SCHEMA_NAME')
  and   (u.equality_preds > 100 OR u.equijoin_preds > 100)
  order by u.equality_preds+u.equijoin_preds desc)
WHERE rownum <11;
