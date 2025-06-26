-- Migration script from 1.6 to 1.7
-- Adds PG17-compatible version of vacuum_progress()
DROP FUNCTION IF EXISTS @extschema@.vacuum_progress();

CREATE OR REPLACE FUNCTION pgtelemetry.vacuum_progress()
RETURNS TABLE (
  datname text,
  schemaname text,
  relname text,
  phase text,
  heap_blks_total bigint,
  heap_blks_scanned bigint,
  heap_blks_vacuumed bigint,
  index_vacuum_count bigint,
  dead_info text
) AS $$
BEGIN
  IF current_setting('server_version_num')::int >= 170000 THEN
    RETURN QUERY
    SELECT
      v.datname,
      c.relnamespace::regnamespace::name,
      c.relname,
      v.phase,
      v.heap_blks_total,
      v.heap_blks_scanned,
      v.heap_blks_vacuumed,
      v.index_vacuum_count,
      FORMAT('dead_tuple_bytes=%s, num_dead_item_ids=%s',
              v.dead_tuple_bytes, v.num_dead_item_ids)
    FROM pg_stat_progress_vacuum v
    LEFT JOIN pg_class c ON c.oid = v.relid;
  ELSE
    RETURN QUERY
    SELECT
      v.datname,
      c.relnamespace::regnamespace::name,
      c.relname,
      v.phase,
      v.heap_blks_total,
      v.heap_blks_scanned,
      v.heap_blks_vacuumed,
      v.index_vacuum_count,
      FORMAT('max_dead_tuples=%s, num_dead_tuples=%s',
              v.max_dead_tuples, v.num_dead_tuples)
    FROM pg_stat_progress_vacuum v
    LEFT JOIN pg_class c ON c.oid = v.relid;
  END IF;
END;
$$ LANGUAGE plpgsql;
