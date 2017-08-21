
-- cheating but needed to make plans safe on replicas.
create function is_replica() returns bool language sql IMMUTABLE
AS $$
  select pg_is_in_recovery();
$$;
       
       
-- 9.6-compatibility for PostgreSQL 10 and above
do $d$ begin
if version() not like 'PostgreSQL 9.%' then
   CREATE FUNCTION pg_current_xlog_location() RETURNS pg_lsn language sql as $$
       select pg_current_wal_lsn();
   $$;
   CREATE FUNCTION pg_last_xlog_replay_location() returns pg_lsn language sql as $$
       select pg_last_wal_replay_lsn();
   $$;
end if;
end;$d$ language plpgsql;

create or replace function wal_telemetry() returns table (
   current_epoch numeric, last_epoch numeric, secs_elapsed numeric,
   current_lsn pg_lsn, last_lsn pg_lsn, bytes_elapsed numeric,
   bytes_per_sec numeric
) language sql as $$
WITH insert_record AS (
       insert into pg_telemetry_wal_log
       select extract('epoch' from now()), now(),
                   pg_current_xlog_location() as wal_location
       WHERE NOT is_replica()
       returning *
   ), current_record AS (
       select * from insert_record where not is_replica()
       UNION
       SELECT * from pg_telemetry_wal_log
       WHERE is_replica()
       order by run_time desc limit 1
   )
   select c.run_time as current_epoch, l.run_time as last_epoch,
          c.run_time - l.run_time as secs_elapsed,
          c.lsn as current_lsn, l.lsn as last_lsn,
          c.lsn - l.lsn as bytes_elapsed,
          (c.lsn - l.lsn)::numeric / (c.run_time - l.run_time) as bytes_per_sec
     FROM current_record c,
  lateral (select * from pg_telemetry_wal_log where run_time < c.run_time
            order by run_time desc limit 1) l;
$$ set search_path from current;

select wal_telemetry();

comment on function wal_telemetry() is $$
The wal_telemetry() function checks the current wal location and compares
with the last entry in the pg_telemetry_wal_log.  It then provides for you
both current and last data, and the differences between them.  These include
bytes elapsed and seconds elapsed, and bytes per sec.

The function is designed so that you can export delta information to a monitoring
solution such as munin or prometheus without the latter having to know anything
about lsn representation or losing information in the process.

On a replica this does not write to the table and measures deltas from the last
this was written on the master.
$$;

