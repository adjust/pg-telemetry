-- version compatibility
do $d$ begin
if current_setting('server_version_num')::int < 100000 then
   CREATE FUNCTION pg_current_xlog_location() RETURNS pg_lsn language sql as $$
       select pg_current_wal_lsn();
   $$;
   CREATE FUNCTION pg_last_xlog_replay_location() returns pg_lsn language sql as $$
       select pg_last_wal_replay_lsn();
   $$;
   -- filter out all non-backend connections
   create view client_stat_activity as select * from pg_stat_activity where backend_type = 'client backend';
else
  -- in pre PostgreSQL 10 we only need to filter out autovacuum workers;
  -- however, there is no backend_type field, so we had to rely on the query text.
   create view client_stat_activity as select * from pg_stat_activity where query not like 'autovacuum:%';
end if;
end;$d$ language plpgsql;


create or replace view lock_queue_size_five_minutes_wait as
select count(1) from pg_locks join client_stat_activity using(pid)
where granted = 'f' and extract('epoch' from now() - query_start) > 300;

CREATE OR REPLACE VIEW connections_by_ip_source as
SELECT client_addr, count(*) from client_stat_activity
 GROUP BY client_addr;

create or replace function wal_telemetry_create_or_select_record()
returns pg_telemetry_wal_log language plpgsql as
$$
declare log_entry pg_telemetry_wal_log;
begin
    if is_replica() then
       select * into log_entry from pg_telemetry_wal_log order by run_time desc limit 1;
    else
       insert into pg_telemetry_wal_log
       select extract('epoch' from now()), now(),
                   pg_current_xlog_location() as wal_location
       returning * into log_entry;
    end if;
    return log_entry;
end;
$$;

CREATE OR REPLACE VIEW replication_slot_lag as
SELECT slot_name, slot_type, active, restart_lsn, to_jsonb(s) as full_data,
       now() as querytime, CASE WHEN is_replica()
                                THEN pg_last_xlog_replay_location()
                                ELSE pg_current_xlog_location() END
                           AS pg_current_xlog_location,
       CASE WHEN is_replica() THEN null::int
            ELSE pg_current_xlog_location() - restart_lsn END
       AS current_lag_bytes
  FROM pg_replication_slots s
 ORDER BY s.slot_name;
