-- complain if script is sourced in psql, rather than via CREATE EXTENSION
--\echo Use "CREATE EXTENSION pgtelemetry" to load this file. \quit

-- filter non-backend connections from pg_stat_activity
create view client_stat_activity as select * from pg_stat_activity where backend_type = 'client backend';

-- disk space
CREATE VIEW relation_total_size AS
select c.oid, c.oid::regclass as relation, pg_total_relation_size(c.oid) as inclusive_bytes,
       pg_size_pretty(pg_total_relation_size(c.oid)) as inclusive_size,
       pg_relation_size(c.oid) as exclusive_bytes,
       pg_size_pretty(pg_relation_size(c.oid)) as exclusive_size
  from pg_class c
  join pg_namespace n ON c.relnamespace = n.oid
 WHERE relkind = 'r'
       and n.nspname not in ('pg_toast', 'pg_catalog', 'information_schema');

COMMENT ON VIEW relation_total_size IS
$$
This view provides basic information on relation size.  Catalogs and tables
in the information schema are exclused, as are TOAST tables.

The inclusive metrics show the relation along with indexes and TOAST.  The
exclusiove metrics show without these things.  The bytes metrics are intended
for graph drawing, while the sizes are there for administrators who want to
quickly query this information and make decisions.
$$;

CREATE VIEW catalog_total_size AS
select c.oid, c.oid::regclass as relation, pg_total_relation_size(c.oid) as inclusive_bytes,
       pg_size_pretty(pg_total_relation_size(c.oid)) as inclusive_size,
       pg_relation_size(c.oid) as exclusive_bytes,
       pg_size_pretty(pg_relation_size(c.oid)) as exclusive_size
  from pg_class c
  join pg_namespace n ON c.relnamespace = n.oid
 WHERE relkind = 'r'
       and n.nspname in ('pg_catalog', 'information_schema');

COMMENT ON VIEW relation_total_size IS
$$
This view provides basic information on relation size in PostgreSQL system
tables (those in pg_catalog and information_schema).

The inclusive metrics show the relation along with indexes and TOAST.  The
exclusiove metrics show without these things.  The bytes metrics are intended
for graph drawing, while the sizes are there for administrators who want to
quickly query this information and make decisions.
$$;

-- biggest indexes

CREATE VIEW index_size AS
select c.oid, c.oid::regclass as index,
       pg_relation_size(c.oid) as bytes,
       pg_size_pretty(pg_relation_size(c.oid)) as size
  from pg_class c
  join pg_namespace n ON c.relnamespace = n.oid
 WHERE relkind = 'i'
       and n.nspname not in ('pg_toast', 'pg_catalog', 'information_schema');

COMMENT ON VIEW index_size IS
$$
This table is most useful in tracking down questions of bloat, fill factor, and
performance of GIN indexes among other things.
$$;

-- Tables by size  (TOAST)

CREATE VIEW relation_toast_size AS
select c.oid, c.oid::regclass as relation,
       pg_relation_size(t.oid) as exclusive_bytes,
       pg_size_pretty(pg_relation_size(t.oid)) as exclusive_size
  from pg_class c
  join pg_class t ON t.relname = 'pg_toast_' || c.oid::text
  join pg_namespace n ON c.relnamespace = n.oid;

COMMENT ON VIEW relation_toast_size IS
$$
This measures the amount of space in a relation's TOAST tables.  These are
populated when data exceeds what can be reasonably stored inline in the main
heap pages.  You would expect to see this non-zero where you have large fields
being stored, particularly arrays of composite types.

Performance-wise moving data to TOAST improves sequential scans where the data
is not required (count(*) for example) at the cost of making the data that has
been moved far more expensive to retrieve and process.
$$;

-- tablespaces size

CREATE VIEW tablespace_size AS
select spcname as name, pg_tablespace_size(oid) as bytes,
       pg_size_pretty(pg_tablespace_size(oid)) as size
  from pg_tablespace;

COMMENT ON VIEW tablespace_size IS
$$
This provides database-cluster-wide statistics on disk usage by tablespace.

Note that tablespaces and databases are orthogonal.  Typically if you are
running out of disk space, you want to check this one first, then database_size
and then the size of the relations in the largest database in that order.
$$;

-- database size

CREATE VIEW database_size AS
SELECT datname as name, pg_database_size(oid) as bytes,
       pg_size_pretty(pg_database_size(oid)) as size
  FROM pg_database;

comment on view database_size is
$$
This provides cluser-wide size statistics of databases.
$$;

-- connections by application_name

CREATE VIEW connections_by_application AS
select application_name, count(*)
  from pg_stat_activity group by application_name;

comment on view connections_by_application is
$$
This gives you the number of connections (cluster-wide) by application name.

By default the application name is the program name that connected to the db.
$$;

-- connections by state

CREATE VIEW connections_by_state AS
select case when wait_event is null then state else 'waiting' end as state,
       count(*)
  from pg_stat_activity group by 1;

CREATE VIEW waiting_queries_reason_details AS
select wait_event_type, wait_event, count(*) from pg_stat_activity
 WHERE wait_event is not null
 GROUP BY wait_event_type, wait_event;


comment on view connections_by_state is
$$
This gives you the number of connections (cluster-wide) by state (active, idle,
idle in transaction, etc).  If the query is active but is waiting on a lock or
latch, we change this to 'waiting.'
$$;


-- connections by ip address source

CREATE VIEW connections_by_ip_source as
SELECT client_addr,
       count(*) as count,
       count(*) filter(where state = 'active') as active_count,
       count(*) filter(where state = 'idle in transaction' or state = 'idle in transaction (aborted)') as idle_in_transaction_count,
       count(*) filter(where state = 'idle') as idle_count
       from  @extschema@.client_stat_activity
 GROUP BY client_addr;

comment on view connections_by_ip_source is
$$
This is a cluster-wide breakdown of connections by IP source.  Between this and
the applicaiton_name it is a good indication of where server laod is coming from
as well as porblems like connection handle leaks.
$$;

-- table access stats
-- longest-running active queries

CREATE VIEW longest_running_active_queries AS
select application_name, state, wait_event_type, wait_event, query, pid,
       client_addr,
       age(now(), query_start) as running_for
  from pg_stat_activity where state = 'active'
 ORDER BY age(now(), query_start) desc;

comment on view longest_running_active_queries is
$$
This view is intended to be typically used by administrators in determining
which queries to focus on.  However it can be used for reporting and alerting
as well.
$$;

-- waiting connections

CREATE VIEW waiting_connections_by_event_type AS
select wait_event_type, count(*) from pg_stat_activity
 WHERE wait_event is not null
 GROUP BY wait_event_type;

comment on view waiting_connections_by_event_type is
$$
This view provides basic, cluster-global, statistics on why queries are waiting
on other queries.
$$;

-- locks by type

CREATE VIEW locks_by_type AS
SELECT locktype, count(*) from pg_locks
 GROUP BY locktype;

COMMENT ON VIEW locks_by_type is
$$
This view provides cluster-wide statistics on what sorts of locks are present.

These incude advisory locks, relation, tuple, transaction id, etc.  This can be
helpful in determining where the locks are coming from.
$$;

-- locks by mode
CREATE VIEW locks_by_mode AS
SELECT mode, count(*) from pg_locks
 GROUP BY mode;

COMMENT ON view locks_by_mode is
$$
This view provides cluster-wide statistics on locks by lock mode (access share
vs exclusive for example).  Combined with the locks_by_type view, this view
provides a some opportunities to spot locking problems.
$$;

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
This function provides the number of client backend processes waiting on a lock
for more than given number of seconds (5 minutes if not supplied). Can be used to spot
locking conflicts.
$$;


CREATE VIEW tuple_access_stats AS
select schemaname, relname,
       seq_scan, seq_tup_read,
       idx_scan, idx_tup_fetch,
       n_tup_ins, n_tup_upd, n_tup_del, n_tup_hot_upd, n_live_tup, n_dead_tup,
       n_mod_since_analyze
  FROM pg_stat_user_tables;

comment on view tuple_access_stats is
$$
This view provides statistcs for scans (index and sequential) along with
numbers of tuples updated through various means.  It allows you to get a pretty
good idea of where you may need indexes or where IO-related problems may be
coming from.
$$;

-- autovacuum stats
CREATE VIEW autovacuum_stats AS
select schemaname, relname,
       last_vacuum,
       extract (epoch from age(now(), last_vacuum)) as age_last_vacuum,
       vacuum_count,
       last_autovacuum,
       extract (epoch from age(now(), last_autovacuum)) as age_last_autovacuum,
       autovacuum_count,
       last_analyze,
       extract (epoch from age(now(), last_analyze)) as age_last_analyze,
       analyze_count,
       last_autoanalyze,
       extract (epoch from age(now(), last_autoanalyze)) as age_last_autoanalyze,
       autoanalyze_count
  FROM pg_stat_user_tables;

comment on view autovacuum_stats is
$$
This provides basic metrics per table in the current database for when
autovacuum and analyze were last run (as well as manual maintenance).
$$;

-- query stats

-- call, time, rows

DO
$$
DECLARE
    total_time TEXT;
BEGIN
    /*
     * Starting with v1.8 pg_stat_statements defines two separate fields:
     * `total_exec_time` and `total_plan_time` (see documentation for details)
     * while older versions only have `total_time`.
     */
    IF EXISTS (
        SELECT attname FROM pg_attribute
        WHERE attrelid = 'pg_stat_statements'::regclass
        AND attname = 'total_exec_time')
    THEN
        total_time = 'total_exec_time + total_plan_time';
    ELSE
        total_time = 'total_time';
    END IF;

    EXECUTE format(
        $query$
            CREATE VIEW statement_query_rows_time AS
            SELECT datname, queryid, query, sum(calls) as calls,
                   sum(%s) as total_time, sum(rows) as rows
            FROM pg_stat_statements
            JOIN pg_database d ON d.oid = dbid
            GROUP BY datname, queryid, query
        $query$,
        total_time);
END
$$ LANGUAGE plpgsql;

comment on view statement_query_rows_time is
$$
This gives aggregated of stats for a given query (cluster-wide)
per query and database name.  This view provides high level timing and row
statistics.
$$;

-- buffers
CREATE VIEW statement_query_buffers AS
SELECT datname, queryid, query, sum(calls),
       sum(shared_blks_hit) as shared_blks_hit,
       sum(shared_blks_read) as shared_blks_read,
       sum(shared_blks_dirtied) as shared_blks_dirtied,
       sum(shared_blks_written) as shared_blks_written,
       sum(temp_blks_read) as tmp_blkd_read,
       sum(temp_blks_written) as tmp_blkd_written
  FROM pg_stat_statements
  JOIN pg_database d ON d.oid = dbid
 GROUP BY datname, queryid, query;

comment on view statement_query_buffers is
$$
This gives aggregated of stats for a given query (cluster-wide)
per query and database name.  This view provides low-level IO statistics.
$$;

-- WAL last state

CREATE TABLE pg_telemetry_wal_log (
   run_time numeric unique, -- epoch timestamp
   timestamp timestamp unique,
   lsn pg_lsn
);

COMMENT ON TABLE pg_telemetry_wal_log IS $$
This table logs the times and results of wal telemetry readings so that
deltas can be calculated.  At least one row must be present to get any useful
data out of the wal_telemetry() function at all.

If you get one telemetry entry a minute, over the course of a year you will get
just over half a million entries.  These are indexed on both epoch and timestamp
so access is not impaired, but if you want ot purge, be careful to leave at
least one entry at the end.

You can also process these as a time series using WINDOW functions like lag.
$$;

-- WAL telemetry

create function wal_telemetry_create_or_select_record()
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

create function wal_telemetry() returns table (
   current_epoch numeric, last_epoch numeric, secs_elapsed numeric,
   current_lsn pg_lsn, last_lsn pg_lsn, bytes_elapsed numeric,
   bytes_per_sec numeric
) language sql as $$
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

-- Replication slots

CREATE OR REPLACE VIEW replication_slot_lag as
SELECT slot_name, slot_type, active, restart_lsn, to_jsonb(s) as full_data,
       now() as querytime, CASE WHEN pg_is_in_recovery()
                                THEN pg_last_wal_replay_lsn()
                                ELSE pg_current_wal_lsn() END
                           AS pg_current_xlog_location,
       CASE WHEN pg_is_in_recovery() THEN null::int
            ELSE pg_current_wal_lsn() - restart_lsn END
       AS current_lag_bytes
  FROM pg_replication_slots s
 ORDER BY s.slot_name;

COMMENT ON VIEW replication_slot_lag IS
$$
This view monitors lag on downstream slots.  It compares the last sent wal
segment to the current known wal location.

For master database, the current wal location is self-explanatory.  For replicas
we use the last received WAL location instead.  Note that replicas can have
replication slots for downstream replication tracking.
$$;

create or replace function get_autovacuum_vacuum_info
(
      _except regclass[] default null,
  out queue_depth int8,
  out total_dead_tup int8
)
  returns record
  language plpgsql stable as
$fnc$
begin
  select
      count(*),
      sum(n_dead_tup)
      into queue_depth, total_dead_tup
    from
      pg_class c, --lateral
        pg_stat_get_dead_tuples(c.oid) n_dead_tup
    where
          coalesce(c.oid != any (_except), true)
      and n_dead_tup >
          coalesce((select option_value::int4 from pg_options_to_table(reloptions) where option_name = 'autovacuum_vacuum_threshold'), current_setting('autovacuum_vacuum_threshold')::int4)+
          reltuples*coalesce((select option_value::float4 from pg_options_to_table(reloptions) where option_name = 'autovacuum_vacuum_scale_factor'), current_setting('autovacuum_vacuum_scale_factor')::float4)
      and not exists (select from pg_options_to_table(reloptions) where option_name = 'autovacuum_enabled' and option_value::bool = false)
    ;
    return;
end;
$fnc$;

create or replace function get_autovacuum_analyze_info
(
      _except regclass[] default array['pg_catalog.pg_statistic'],
  out queue_depth int8,
  out total_mod_since_analyze int8
)
  returns record
  language plpgsql stable as
$fnc$
begin
  select
      count(*),
      sum(n_mod_since_analyze)
      into queue_depth, total_mod_since_analyze
    from
      pg_class c,
        pg_stat_get_mod_since_analyze(c.oid) n_mod_since_analyze
    where
          c.relnamespace != 'pg_toast'::regnamespace
      and coalesce(c.oid != any (_except), true)
      and n_mod_since_analyze >
          coalesce((select option_value::int4 from pg_options_to_table(reloptions) where option_name = 'autovacuum_analyze_threshold'), current_setting('autovacuum_analyze_threshold')::int4)+
            reltuples*coalesce((select option_value::float4 from pg_options_to_table(reloptions) where option_name = 'autovacuum_analyze_scale_factor'), current_setting('autovacuum_analyze_scale_factor')::float4)
      and not exists (select from pg_options_to_table(reloptions) where option_name = 'autovacuum_enabled' and option_value::bool = false)
    ;
    return;
end;
$fnc$;

create or replace function @extschema@.vacuum_progress()
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
    dead_info             text
  )
  language plpgsql stable as
$fnc$
begin
  if exists (select from pg_class c where c.relnamespace='pg_catalog'::regnamespace and c.relname = 'pg_stat_progress_vacuum') then
    if current_setting('server_version_num')::int >= 170000 then
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
          format('dead_tuple_bytes=%s, num_dead_item_ids=%s',
                 v.dead_tuple_bytes, v.num_dead_item_ids)
        from pg_stat_progress_vacuum v
        left join pg_class c on c.oid = v.relid;
    else
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
          format('max_dead_tuples=%s, num_dead_tuples=%s',
                 v.max_dead_tuples, v.num_dead_tuples)
        from pg_stat_progress_vacuum v
        left join pg_class c on c.oid = v.relid;
    end if;
  end if;

  return;
end;
$fnc$;

create table @extschema@.long_running_query_rules
(
  priority                  int4,
  application_name_ilike    text,
  usename                   name,
  state                     text,
  alert_threshold           interval not null,
  active_since              timestamptz,
  active_until              timestamptz,
  created_at                timestamptz default now(),
  comment                   text
);

insert into @extschema@.long_running_query_rules(priority, application_name_ilike, usename, state, alert_threshold)
  values
  (0, 'pg\_dump%', null, null, interval'6 hours'), -- pg_dump 6 hours
  (0, 'pg2ch', null, null, interval'3 hours'), -- pg2ch 3 hours
  (100, null, null, 'idle in transaction', interval'5 minutes'), -- any idle transaction 5 minutes
  (100, null, null, 'idle in transaction (aborted)', interval'5 minutes'), -- same as above, except one of the statements in the transaction caused an error
  (1000, null, null, null, interval'1 hour'); -- anything else 1 hour


create or replace view @extschema@.long_running_queries
(
    current_state_duration,
    query_duration,
    pid,
    is_slave,
    application_name,
    username,
    database,
    backend_type,
    client_addr,
    state,
    wait_event,
    wait_event_type,
    query
) as
select
        now() - p.state_change as current_state_duration,
        now() - p.query_start as query_duration,
        p.pid,
        pg_is_in_recovery() as is_slave,
        p.application_name,
        p.usename,
        p.datname as database,
        p.backend_type,
        p.client_addr,
        p.state,
        p.wait_event,
        p.wait_event_type,
        p.query
    from pg_catalog.pg_stat_activity p,
        lateral
        (
            select
                    alert_threshold,
                    active_since,
                    active_until,
                    state
                from @extschema@.long_running_query_rules l
                where
                        coalesce(p.application_name ilike l.application_name_ilike, true)
                    and coalesce(p.usename = l.usename, true)
                    and coalesce(p.state = l.state, true)
                    and coalesce(now() >= l.active_since, true)
                    and coalesce(now() <= l.active_until, true)
                order by priority asc
                limit 1
        ) l
    where
            p.state != 'idle'
        and backend_type = 'client backend'
        and ((l.state is NOT NULL and age(now(), state_change) > l.alert_threshold)
          or (l.state is NULL and age(now(), query_start) > l.alert_threshold))
    order by current_state_duration desc;
