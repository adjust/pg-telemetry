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
  (0, 'pg\_dump', null, null, interval'6 hours'), -- pg_dump 6 hours
  (0, 'pg2ch', null, null, interval'3 hours'), -- pg2ch 3 hours
  (100, null, null, 'idle in transaction', interval'5 minutes'); -- any idle transaction 5 minutes
  (100, null, null, 'idle in transaction (aborted)', interval'5 minutes'); -- same as above, except one of the statements in the transaction caused an error
  (1000, null, null, null, interval'1 hour'); -- anything else 1 hour

create or replace view @extschema@.long_running_queries
(
    duration,
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
        now() - p.query_start as duration,
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
                    active_until
                from @extschema@.long_running_query_rules l
                where
                        coalesce(p.application_name ilike l.application_name_ilike, true)
                    and coalesce(p.usename = l.usename, true)
                    and coalesce(p.state = l.state, true)
                order by priority asc
                limit 1
        ) l
    where
            p.state != 'idle'
        and backend_type = 'client backend'
        and age(now(), query_start) > l.alert_threshold
        and coalesce(now() >= l.active_since, true)
        and coalesce(now() <= l.active_until, true)
    order by duration desc;
