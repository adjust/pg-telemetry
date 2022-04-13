-- WAL telemetry

create or replace function wal_telemetry_create_or_select_record()
returns pg_telemetry_wal_log language plpgsql as
$$
declare log_entry pg_telemetry_wal_log;
begin
    if pg_is_in_recovery() then
       select * into log_entry from pg_telemetry_wal_log order by run_time desc limit 1;
    else
       delete from pg_telemetry_wal_log where timestamp < (current_timestamp - interval '1 month');
       insert into pg_telemetry_wal_log
       select extract('epoch' from now()), now(),
                   pg_current_wal_lsn() as wal_location
       returning * into log_entry;
    end if;
    return log_entry;
end;
$$;
