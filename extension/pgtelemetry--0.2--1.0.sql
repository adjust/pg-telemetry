
create function wal_telemetry_create_or_select_record()
returns pg_telemetry_wal_log language plpgsql as
$$
declare log_entry pg_telemetry_wal_log;
begin
    if pg_is_in_recovery() then
       select * into log_entry from pg_telemetry_wal_log order by current_epoch desc limit 1;
    else
       insert into pg_telemetry_wal_log
       select extract('epoch' from now()), now(),
                   pg_current_xlog_location() end as wal_location
       WHERE NOT is_replica()
       returning * into log_entry;
    end if;
    return log_entry;
end;
$$;

create function wal_telemetry() returns table (
   current_epoch numeric, last_epoch numeric, secs_elapsed numeric,
   current_lsn pg_lsn, last_lsn pg_lsn, bytes_elapsed numeric,
   bytes_per_sec numeric
) language sql as $$
WITH insert_record AS 
   select c.run_time as current_epoch, l.run_time as last_epoch,
          c.run_time - l.run_time as secs_elapsed,
          c.lsn as current_lsn, l.lsn as last_lsn,
          c.lsn - l.lsn as bytes_elapsed,
          (c.lsn - l.lsn)::numeric / (c.run_time - l.run_time) as bytes_per_sec
     FROM wal_telemetry_create_or_select_record() c,
  lateral (select * from pg_telemetry_wal_log where run_time < c.run_time
            order by run_time desc limit 1) l;
$$ set search_path from current;

select wal_telemetry();

CREATE VIEW waiting_queries_reason_details AS
select wait_event_type, wait_event, count(*) from pg_stat_activity
 WHERE wait_event is not null
 GROUP BY wait_event_type, wait_event;`
