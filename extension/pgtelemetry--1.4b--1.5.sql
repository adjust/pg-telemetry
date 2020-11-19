DROP VIEW statement_query_rows_time;

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
