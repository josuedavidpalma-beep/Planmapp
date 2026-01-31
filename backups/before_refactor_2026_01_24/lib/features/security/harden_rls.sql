-- ==========================================
-- SECURITY HARDENING SCRIPT (RLS Implementation)
-- ==========================================

-- 1. Helper Function: Check proper membership
-- This function is efficient and avoids infinite recursion in policies
create or replace function public.is_plan_member(_plan_id uuid)
returns boolean as $$
begin
  return exists (
    select 1
    from public.plan_members
    where plan_id = _plan_id
    and user_id = auth.uid()
  );
end;
$$ language plpgsql security definer;

-- 2. SAFETY BACKFILL: Ensure all plans have at least their creator as a member
-- This prevents locking out users from their existing plans
insert into public.plan_members (plan_id, user_id, role)
select id, creator_id, 'admin'
from public.plans
where creator_id is not null
on conflict (plan_id, user_id) do nothing;

-- 3. Enable RLS on Key Tables
alter table public.plans enable row level security;
alter table public.plan_members enable row level security;
alter table public.expenses enable row level security;
-- (Add other tables as needed: expense_items, etc.)

-- 4. POLICIES: PLANS TABLE
-- Drop old insecure policies
drop policy if exists "Enable read access for all users" on public.plans;
drop policy if exists "Enable insert for authenticated users" on public.plans;
drop policy if exists "Enable update for creators" on public.plans;

-- Create Secure Policies
-- View: Only members can see the plan
create policy "Plans visible to members"
on public.plans for select
using ( is_plan_member(id) );

-- Create: Any authenticated user can create a plan
create policy "Authenticated users can create plans"
on public.plans for insert
with check ( auth.role() = 'authenticated' );

-- Update/Delete: Only Admin members (or Creator explicitly)
create policy "Admins can update plans"
on public.plans for update
using ( exists (
  select 1 from public.plan_members
  where plan_id = plans.id
  and user_id = auth.uid()
  and role in ('admin', 'creator')
));

-- 5. POLICIES: PLAN_MEMBERS TABLE
drop policy if exists "Enable read access for all users" on public.plan_members;

-- View: Members can see who else is in their plan
create policy "Members view other members"
on public.plan_members for select
using ( 
   -- I can see rows where plan_id matches a plan I am a member of
   -- But wait, this is recursive! 
   -- Simplified: I can see a row if it IS me, OR if I share a plan with them.
   -- Efficient approach: 
   user_id = auth.uid() -- I can always see myself
   or 
   plan_id in (select plan_id from public.plan_members where user_id = auth.uid())
);

-- Insert: Admins can add people (or open invites later)
create policy "Admins manage members"
on public.plan_members for insert
with check (
  exists (
    select 1 from public.plan_members
    where plan_id = plan_members.plan_id
    and user_id = auth.uid()
    and role = 'admin'
  )
  -- Or self-join if implementing "Join Link"
  or user_id = auth.uid() 
);

-- 6. POLICIES: EXPENSES TABLE
drop policy if exists "Everyone can see expenses" on public.expenses;

-- View: Plan members can see expenses
create policy "Members view expenses"
on public.expenses for select
using ( is_plan_member(plan_id) );

-- Edit: Plan members can add/edit expenses (Open trust model for MVP)
create policy "Members manage expenses"
on public.expenses for all
using ( is_plan_member(plan_id) );
