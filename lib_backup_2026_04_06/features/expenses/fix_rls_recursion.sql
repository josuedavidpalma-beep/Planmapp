-- ==========================================
-- FIX RLS INFINITE RECURSION
-- ==========================================
-- Problem: The policy on 'plan_members' queries 'plan_members' to find shared plans.
-- This creates an Infinite Loop (Recursion).
-- Solution: Use a "Security Definer" function that runs with Admin privileges 
-- to fetch the list of plans My User belongs to, bypassing the RLS check for that specific query.

-- 1. Create a secure "Bypass" function to get my plans
create or replace function public.get_my_plan_ids()
returns setof uuid
security definer -- ✨ Runs as Admin/Owner, bypassing RLS ✨
set search_path = public -- Security best practice
as $$
begin
  return query
  select plan_id 
  from public.plan_members 
  where user_id = auth.uid();
end;
$$ language plpgsql;

-- 2. Fix 'plan_members' Policies to use this bypass
drop policy if exists "Members view other members" on public.plan_members;

create policy "Members view other members"
on public.plan_members for select
using (
   -- I can see it if it's MY row
   user_id = auth.uid()
   OR 
   -- OR if it belongs to one of MY plans (fetching my plans safely now)
   plan_id in ( select get_my_plan_ids() )
);

-- 3. Fix 'plans' Policies (Just in case, ensuring they use the safe check too)
-- (The is_plan_member function is also good, let's keep it but ensure it's safe)
create or replace function public.is_plan_member(_plan_id uuid)
returns boolean
security definer
set search_path = public
as $$
begin
  return exists (
    select 1
    from public.plan_members
    where plan_id = _plan_id
    and user_id = auth.uid()
  );
end;
$$ language plpgsql;
