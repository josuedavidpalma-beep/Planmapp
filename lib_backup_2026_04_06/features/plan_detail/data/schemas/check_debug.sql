-- CHECK LATEST PLAN AND POLLS
-- Get the last created plan
WITH last_plan AS (
    SELECT id, title, created_at, creator_id 
    FROM plans 
    ORDER BY created_at DESC 
    LIMIT 1
)
SELECT 
    p.title as plan_title,
    p.id as plan_id,
    po.id as poll_id,
    po.question,
    po.status,
    po.type,
    po.created_at as poll_created_at
FROM last_plan p
LEFT JOIN polls po ON po.plan_id = p.id;
