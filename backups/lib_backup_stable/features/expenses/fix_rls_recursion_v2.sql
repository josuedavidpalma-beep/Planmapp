-- ==========================================
-- FIX RLS INFINITE RECURSION (V2 - ROBUST)
-- ==========================================
-- Problem: 'plan_members' policies refer to 'plan_members', creating a loop.
-- Even 'OR' conditions in policies can trigger the loop if Postgres keeps evaluating.

-- SOLUTION: Move ALL recursive logic into "Security Definer" functions.
-- These functions run as "Admin" and bypass RLS, breaking the chain.

-- 1. Helper: Get my plan IDs safely
create or replace function public.get_my_plan_ids()
returns setof uuid
security definer set search_path = public
as $$
begin
  return query select plan_id from public.plan_members where user_id = auth.uid();
end;
$$ language plpgsql;

-- 2. Helper: Check if I am admin safely
create or replace function public.is_plan_admin(_plan_id uuid)
returns boolean
security definer set search_path = public
as $$
begin
  return exists (
    select 1 from public.plan_members 
    where plan_id = _plan_id 
    and user_id = auth.uid() 
    and role = 'admin'
  );
end;
$$ language plpgsql;

-- 3. RESET POLICIES on plan_members
-- We drop everything to be dry and clean
drop policy if exists "Members view other members" on public.plan_members;
drop policy if exists "Admins manage members" on public.plan_members;
drop policy if exists "Enable read access for all users" on public.plan_members;
drop policy if exists "Enable insert for authenticated users" on public.plan_members;

-- 4. NEW POLICIES (Using the safe functions)

-- VIEW: I see rows if it's ME, or if we share a plan
create policy "Safe view members"
on public.plan_members for select
using (
   user_id = auth.uid()
   OR 
   plan_id in ( select get_my_plan_ids() )
);

-- INSERT: I can insert if I'm creating a plan (adding myself) OR if I am an admin adding others
create policy "Safe insert members"
on public.plan_members for insert
with check (
   user_id = auth.uid() -- Self-add (Creator flow)
   OR 
   is_plan_admin(plan_id) -- Admin adding others
);

-- UPDATE/DELETE: Admins only
create policy "Safe update members"
on public.plan_members for update
using ( is_plan_admin(plan_id) );

create policy "Safe delete members"
on public.plan_members for delete
using ( is_plan_admin(plan_id) OR user_id = auth.uid() );
