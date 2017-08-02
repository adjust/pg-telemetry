
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

-- biggest indexes

CREATE VIEW index_size AS
select c.oid, c.oid::regclass as index,
       pg_relation_size(c.oid) as bytes,
       pg_size_pretty(pg_relation_size(c.oid)) as size
  from pg_class c
  join pg_namespace n ON c.relnamespace = n.oid
 WHERE relkind = 'i' 
       and n.nspname not in ('pg_toast', 'pg_catalog', 'information_schema');

-- Tables by size  (TOAST)

CREATE VIEW relation_toast_size AS
select c.oid, c.oid::regclass as relation,
       pg_relation_size(t.oid) as exclusive_bytes,
       pg_size_pretty(pg_relation_size(t.oid)) as exclusive_size
  from pg_class c
  join pg_class t ON t.relname = 'pg_toast_' || c.oid::text
  join pg_namespace n ON c.relnamespace = n.oid;



-- tablespaces size

CREATE VIEW tablespace_size AS
select spcname as name, pg_tablespace_size(oid) as bytes, 
       pg_size_pretty(pg_tablespace_size(oid)) as size
  from pg_tablespace;

-- database size

CREATE VIEW database_size AS
SELECT datname as name, pg_database_size(oid) as bytes,
       pg_size_pretty(pg_database_size(oid)) as size
  FROM pg_database;

-- connections by application_name

CREATE VIEW connections_by_application AS
select application_name, count(*)
  from pg_stat_activity group by application_name;

-- connections by state

CREATE VIEW connections_by_state AS
select case when wait_event is null then state else 'waiting' end as state,
       count(*) 
  from pg_stat_activity group by 1;

-- longest-running active queries

CREATE VIEW longest_running_active_queries AS
select application_name, state, wait_event_type, wait_event, query, pid, 
       client_addr,
       age(now(), query_start) as running_for
  from pg_stat_activity where state = 'active'
 ORDER BY age(now(), query_start) desc;

-- waiting connections

CREATE VIEW waiting_connections_by_event_type AS
select wait_event_type, count(*) from pg_stat_activity
 WHERE wait_event is not null
 GROUP BY wait_event_type;

-- locks by type

CREATE VIEW locks_by_type AS
SELECT locktype, count(*) from pg_locks
 GROUP BY locktype;

-- locks by mode
CREATE VIEW locks_by_mode AS
SELECT mode, count(*) from pg_locks 
 GROUP BY mode;

-- connections by ip address source

CREATE VIEW connections_by_ip_source as
SELECT client_addr, count(*) from pg_stat_activity
 GROUP BY client_addr;

-- table access stats

CREATE VIEW tuple_access_stats AS
select schemaname, relname, 
       seq_scan, seq_tup_read, 
       idx_scan, idx_tup_fetch, 
       n_tup_ins, n_tup_upd, n_tup_del, n_tup_hot_upd, n_live_tup, n_dead_tup, 
       n_mod_since_analyze
  FROM pg_stat_user_tables;

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

-- query stats

-- this is intended to reduce overhead by allowing us to retrieve the
-- queries when we don't get one we have seen.

CREATE VIEW statement_query_by_id AS
SELECT queryid, query FROM pg_stat_statements
GROUP BY queryid, query;

-- call, time, rows

CREATE VIEW statement_query_rows_time AS
SELECT datname, queryid, sum(calls) as calls, 
       sum(total_time) as total_time, sum(rows) as rows
  FROM pg_stat_statements
  JOIN pg_database d ON d.oid = dbid
 GROUP BY datname, queryid;

-- buffers
CREATE VIEW statement_query_buffers AS 
SELECT datname, queryid, sum(calls), 
       sum(shared_blks_hit) as shared_blks_hit,
       sum(shared_blks_read) as shared_blks_read, 
       sum(shared_blks_dirtied) as shared_blks_dirtied, 
       sum(shared_blks_written) as shared_blks_written,
       sum(temp_blks_read) as tmp_blkd_read,
       sum(temp_blks_written) as tmp_blkd_written
  FROM pg_stat_statements
  JOIN pg_database d ON d.oid = dbid
 GROUP BY datname, queryid;



-- WAL last state

CREATE TABLE pg_telemetry_wal_log (
   run_time numeric unique, -- epoch timestamp
   timestamp timestamp unique,
   lsn pg_lsn
);

-- WAL telemetry

create function wal_telemetry() returns table (
   current_epoch numeric, last_epoch numeric, secs_elapsed numeric,
   current_lsn pg_lsn, last_lsn pg_lsn, bytes_elapsed numeric,
   bytes_per_sec numeric
) language sql as $$
WITH current_record AS (
       insert into pg_telemetry_wal_log
       select extract('epoch' from now()), now(),
              case when pg_is_in_recovery()
                   then pg_last_xlog_replay_location()
                   else pg_current_xlog_location() end as wal_location
       returning *
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

-- Replication slots

CREATE OR REPLACE VIEW replication_slot_lag as
SELECT slot_name, slot_type, active, restart_lsn, to_jsonb(s) as full_data,
       now() as querytime, CASE WHEN pg_is_in_recovery()
                                THEN pg_last_xlog_replay_location()
                                ELSE pg_current_xlog_location() END
                           AS pg_current_xlog_location,
       CASE WHEN pg_is_in_recovery() THEN null::int
            ELSE pg_current_xlog_location() - restart_lsn END
       AS current_lag_bytes
  FROM pg_replication_slots s
 ORDER BY s.slot_name;
