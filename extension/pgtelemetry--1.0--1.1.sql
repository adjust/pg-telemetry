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
