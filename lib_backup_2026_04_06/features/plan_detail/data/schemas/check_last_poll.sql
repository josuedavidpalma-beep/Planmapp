-- Check the last created poll and its options
WITH last_poll AS (
    SELECT * FROM polls ORDER BY created_at DESC LIMIT 1
)
SELECT 
    p.id as poll_id, 
    p.question, 
    p.created_at, 
    (SELECT count(*) FROM poll_options WHERE poll_id = p.id) as option_count,
    (SELECT string_agg(text, ', ') FROM poll_options WHERE poll_id = p.id) as option_texts
FROM last_poll p;
