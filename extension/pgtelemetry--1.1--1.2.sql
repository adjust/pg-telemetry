create view client_stat_activity as select * from pg_stat_activity where backend_type = 'client backend';
-- the following functions and views needs to be recreated
-- in order to delete three obsolete functions they used to reference.

create or replace function wal_telemetry_create_or_select_record()
returns pg_telemetry_wal_log language plpgsql as
$$
declare log_entry pg_telemetry_wal_log;
begin
    if pg_is_in_recovery() then
       select * into log_entry from pg_telemetry_wal_log order by run_time desc limit 1;
    else
       insert into pg_telemetry_wal_log
       select extract('epoch' from now()), now(),
                   pg_current_wal_lsn() as wal_location
       returning * into log_entry;
    end if;
    return log_entry;
end;
$$;

create or replace view replication_slot_lag as
select slot_name, slot_type, active, restart_lsn, to_jsonb(s) as full_data,
       now() as querytime, case when pg_is_in_recovery()
                                then pg_last_wal_replay_lsn()
                                else pg_current_wal_lsn() end
                           as pg_current_xlog_location,
       case when pg_is_in_recovery() then null::int
            else pg_current_wal_lsn() - restart_lsn end
       as current_lag_bytes
  from pg_replication_slots s
 order by s.slot_name;

create or replace function wal_telemetry_create_or_select_record()
returns pg_telemetry_wal_log language plpgsql as
$$
declare log_entry pg_telemetry_wal_log;
begin
    if pg_is_in_recovery() then
       select * into log_entry from pg_telemetry_wal_log order by run_time desc limit 1;
    else
       insert into pg_telemetry_wal_log
       select extract('epoch' from now()), now(),
                   pg_current_wal_lsn() as wal_location
       returning * into log_entry;
    end if;
    return log_entry;
end;
$$;

drop function is_replica();
drop function if exists pg_current_xlog_location();
drop function if exists pg_last_xlog_replay_location();

create or replace view connections_by_ip_source as
select client_addr, count(*) from client_stat_activity
 group by client_addr;

-- count client backends waiting on a lock for more than given number of seconds
create or replace function count_waiting_on_locks_more_than_seconds(int default 300)
returns bigint
as
$$
select count(1)
 from pg_locks
 join  @extschema@.client_stat_activity using(pid)
where granted = 'f' and
      extract('epoch' from now() - query_start) > $1;
$$ language sql;
comment on function count_waiting_on_locks_more_than_seconds is
$$
this function provides the number of client backend processes waiting on a lock
for more than given number of seconds (5 minutes if not supplied). can be used to spot
locking conflicts.
$$;
