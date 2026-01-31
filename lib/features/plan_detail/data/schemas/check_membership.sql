-- CHECK MEMBERSHIP OF LATEST PLAN
-- This helps us verify if the Creator was actually added to the 'plan_members' table.

WITH last_plan AS (
    SELECT id, title, creator_id, created_at
    FROM plans 
    ORDER BY created_at DESC 
    LIMIT 1
)
SELECT 
    p.title as plan_title,
    p.id as plan_id,
    p.creator_id as creator_uuid,
    pm.user_id as member_uuid,
    pm.role as member_role
FROM last_plan p
LEFT JOIN plan_members pm ON pm.plan_id = p.id;
