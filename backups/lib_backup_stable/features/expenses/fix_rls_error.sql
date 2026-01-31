-- ==========================================
-- FIX RLS CREATOR ACCESS
-- ==========================================
-- Problem: Users cannot create plans because RLS blocks them from seeing 
-- the plan immediately after insertion (before they are added as members).

-- 1. Drop the strict policy
drop policy "Plans visible to members" on public.plans;

-- 2. Create the corrected policy
-- Allow access if:
-- A) User is a member (via plan_members table)
-- OR
-- B) User is the CREATOR (via creator_id column) -> This covers the creation moment.
create policy "Plans visible to members and creators"
on public.plans for select
using ( 
    is_plan_member(id) 
    OR 
    creator_id = auth.uid() 
);

-- Note: The "Admins can update plans" policy might need a similar check if updates happen immediately,
-- but usually membership is established by then. Fixing SELECT usually solves the RETURNING clause issue.
