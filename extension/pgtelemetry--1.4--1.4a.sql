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
        now() - coalesce(p.state_change, p.query_start) as duration,
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
                    and coalesce(now() >= l.active_since, true)
                    and coalesce(now() <= l.active_until, true)
                order by priority asc
                limit 1
        ) l
    where
            p.state != 'idle'
        and backend_type = 'client backend'
        and age(now(), query_start) > l.alert_threshold
    order by duration desc;
