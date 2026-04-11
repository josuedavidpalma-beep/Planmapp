-- ==========================================
-- FIX RLS INFINITE RECURSION (FINAL CLEANUP)
-- ==========================================
-- Problem: 'Policy already exists'. 
-- This happens if you run the script twice: the first time it creates the policy, 
-- and the second time it fails because we forgot to DROP the *new* name.

-- 1. Ensure Functions exist (these are safe to replace)
create or replace function public.get_my_plan_ids()
returns setof uuid
security definer set search_path = public
as $$
begin
  return query select plan_id from public.plan_members where user_id = auth.uid();
end;
$$ language plpgsql;

create or replace function public.is_plan_admin(_plan_id uuid)
returns boolean
security definer set search_path = public
as $$
begin
  return exists (select 1 from public.plan_members where plan_id = _plan_id and user_id = auth.uid() and role = 'admin');
end;
$$ language plpgsql;

-- 2. DROP EVERYTHING (Old and User-Reported collisions)
drop policy if exists "Members view other members" on public.plan_members;
drop policy if exists "Admins manage members" on public.plan_members;
drop policy if exists "Safe view members" on public.plan_members;   -- <--- Added this
drop policy if exists "Safe insert members" on public.plan_members; -- <--- Added this
drop policy if exists "Safe update members" on public.plan_members; -- <--- Added this
drop policy if exists "Safe delete members" on public.plan_members; -- <--- Added this

-- 3. RE-CREATE POLICIES
create policy "Safe view members"
on public.plan_members for select
using (
   user_id = auth.uid() OR plan_id in (select get_my_plan_ids())
);

create policy "Safe insert members"
on public.plan_members for insert
with check (
   user_id = auth.uid() OR is_plan_admin(plan_id)
);

create policy "Safe update members"
on public.plan_members for update
using ( is_plan_admin(plan_id) );

create policy "Safe delete members"
on public.plan_members for delete
using ( is_plan_admin(plan_id) OR user_id = auth.uid() );
