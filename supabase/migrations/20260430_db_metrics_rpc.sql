CREATE OR REPLACE FUNCTION get_database_metrics()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    total_db_size TEXT;
    table_sizes JSONB;
BEGIN
    -- Get total size of current database
    SELECT pg_size_pretty(pg_database_size(current_database())) INTO total_db_size;

    -- Get sizes of main tables (top 10 largest user tables)
    SELECT jsonb_agg(
        jsonb_build_object(
            'table_name', relname,
            'size', pg_size_pretty(pg_total_relation_size(relid)),
            'bytes', pg_total_relation_size(relid)
        )
    )
    INTO table_sizes
    FROM pg_catalog.pg_statio_user_tables
    ORDER BY pg_total_relation_size(relid) DESC
    LIMIT 10;

    RETURN jsonb_build_object(
        'total_db_size', total_db_size,
        'table_sizes', table_sizes
    );
END;
$$;
