create or replace function vacuum_progress()
  returns table
  (
    datname               name,
    schemaname            name,
    relname               name,
    phase                 text,
    heap_blks_total       int8,
    heap_blks_scanned     int8,
    heap_blks_vacuumed    int8,
    index_vacuum_count    int8,
    max_dead_tuples       int8,
    num_dead_tuples       int8
  )
  language plpgsql stable as
$fnc$
begin
  /* too lazy to check which version of pg the view was added in, so
   * just check if its there and return null if its not
   */
  if exists (select from pg_class c where c.relnamespace='pg_catalog'::regnamespace and c.relname = 'pg_stat_progress_vacuum') then
    return query
      select
          v.datname,
          c.relnamespace::regnamespace::name as schemaname,
          c.relname,
          v.phase,
          v.heap_blks_total,
          v.heap_blks_scanned,
          v.heap_blks_vacuumed,
          v.index_vacuum_count,
          v.max_dead_tuples,
          v.num_dead_tuples
        from pg_stat_progress_vacuum v
          left join pg_class c on c.oid=v.relid;
  end if;

  return;
end;
$fnc$;
