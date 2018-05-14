-- Vacuum progress
CREATE FUNCTION vacuum_progress() RETURNS table(
  datid oid, datname name, schemaname name,
  relname name, phase text, heap_blks_total bigint,
  heap_blks_scanned bigint, heap_blks_vacuumed bigint, index_vacuum_count bigint,
  max_dead_tuples bigint, num_dead_tuples bigint)
LANGUAGE plpgsql as $$
begin
  if exists(select 1 from pg_settings where name = 'server_version_num' and setting::numeric >= 100000) then
    return query select
                   p.datid,
                   p.datname,
                   n.nspname,
                   c.relname,
                   p.phase,
                   p.heap_blks_total,
                   p.heap_blks_scanned,
                   p.heap_blks_vacuumed,
                   p.index_vacuum_count,
                   p.max_dead_tuples,
                   p.num_dead_tuples
                 from pg_stat_progress_vacuum p
                   left join pg_class c on c.oid = p.relid
                   left join pg_namespace n on n.oid = c.relnamespace;
  end if;

  return;
end;
$$;
