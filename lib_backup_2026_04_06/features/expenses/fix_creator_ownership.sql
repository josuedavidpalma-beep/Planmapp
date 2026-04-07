-- FORCE OWNERSHIP SCRIPT
-- This script makes the currently logged-in user the CREATOR of ALL plans.
-- Useful for development when you are the only real user but specific plans might have corrupted creator_ids.

-- 1. Update plans
update public.plans 
set creator_id = auth.uid()
where true; -- Applied to ALL rows

-- 2. Ensure the user is also a member (just in case)
insert into public.plan_members (plan_id, user_id, role)
select id, auth.uid(), 'admin'
from public.plans
on conflict (plan_id, user_id) do update set role = 'admin';

-- 3. Ensure Profiles has PHONE column
alter table public.profiles 
add column if not exists phone text;

-- 4. Ensure Profiles has display_name column
alter table public.profiles 
add column if not exists display_name text;
