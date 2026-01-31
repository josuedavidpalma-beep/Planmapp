-- ROLES & PERMISSIONS MIGRATION
-- Defines strict roles: admin (Organizador), member (Participante), treasurer (Cobrador).

-- 1. Ensure Role Column Exists and is Enforced
-- (Assuming plan_members table exists, if not, create it minimal)
create table if not exists public.plan_members (
    id uuid default gen_random_uuid() primary key,
    plan_id uuid references public.plans(id) on delete cascade not null,
    user_id uuid references auth.users(id) not null,
    role text default 'member' check (role in ('admin', 'member', 'treasurer')),
    status text default 'active',
    created_at timestamp with time zone default now(),
    unique(plan_id, user_id)
);

-- If table existed but check missing:
alter table public.plan_members drop constraint if exists plan_members_role_check;
alter table public.plan_members add constraint plan_members_role_check check (role in ('admin', 'member', 'treasurer'));

-- 2. Helper Functions for RLS
create or replace function public.get_member_role(p_plan_id uuid)
returns text as $$
  select role from public.plan_members
  where plan_id = p_plan_id
  and user_id = auth.uid()
  limit 1;
$$ language sql security definer;

create or replace function public.is_plan_admin(p_plan_id uuid)
returns boolean as $$
  select exists (
    select 1 from public.plans where id = p_plan_id and creator_id = auth.uid()
  ) or (
    public.get_member_role(p_plan_id) = 'admin'
  );
$$ language sql security definer;

create or replace function public.is_admin_or_treasurer(p_plan_id uuid)
returns boolean as $$
  select public.is_plan_admin(p_plan_id) or (
    public.get_member_role(p_plan_id) = 'treasurer'
  );
$$ language sql security definer;

-- 3. Update Policies

-- A. BUDGET (Only Admin/Organizer)
drop policy if exists "Creator manage budget insert" on public.budget_items;
create policy "Admin manage budget insert" on public.budget_items for insert with check (public.is_plan_admin(plan_id));

drop policy if exists "Creator manage budget update" on public.budget_items;
create policy "Admin manage budget update" on public.budget_items for update using (public.is_plan_admin(plan_id));

drop policy if exists "Creator manage budget delete" on public.budget_items;
create policy "Admin manage budget delete" on public.budget_items for delete using (public.is_plan_admin(plan_id));

-- B. EXPENSES (Admin + Treasurer/Cobrador)
-- Members can VIEW, but only Authorized roles can INSERT/UPDATE/DELETE expenses.
-- (Unless we want "Splitwise" style where anyone adds? User said "Cobrador registra", implies restriction.)

alter table public.expenses enable row level security;

drop policy if exists "Enable all for users" on public.expenses; -- Clean up old permissive policies
drop policy if exists "Allow all for authenticated" on public.expenses;

create policy "All members view expenses" on public.expenses for select
using (public.is_plan_member(plan_id) or public.is_plan_admin(plan_id));

create policy "Authorized add expenses" on public.expenses for insert
with check (public.is_admin_or_treasurer(plan_id));

create policy "Authorized update expenses" on public.expenses for update
using (public.is_admin_or_treasurer(plan_id));

create policy "Authorized delete expenses" on public.expenses for delete
using (public.is_admin_or_treasurer(plan_id));

-- C. PAYMENT TRACKERS (Admin manages frequency, Treasurer might update status?)
-- For now, payment_trackers structure defines the rules.
drop policy if exists "Creator manage payments insert" on public.payment_trackers;
create policy "Admin manage payments insert" on public.payment_trackers for insert with check (public.is_plan_admin(plan_id));

drop policy if exists "Creator manage payments update" on public.payment_trackers;
create policy "Admin manage payments update" on public.payment_trackers for update using (public.is_plan_admin(plan_id));

-- D. PARTICIPANT STATUS (Debt tracking)
-- Treasurer needs to mark them as Paid.
drop policy if exists "Allow all for participant status" on public.expense_participant_status;

create policy "View debt status" on public.expense_participant_status for select
using (
    exists (select 1 from public.expenses e where e.id = expense_id and (public.is_plan_member(e.plan_id) or public.is_plan_admin(e.plan_id)))
);

-- Only Authorized roles can update debt status (Mark as Paid)
create policy "Manage debt status" on public.expense_participant_status for update
using (
    exists (select 1 from public.expenses e where e.id = expense_id and public.is_admin_or_treasurer(e.plan_id))
);

-- Insert happens automatically internally or via authorized expense creation, so we can allow insert if expense exists
create policy "Insert debt status" on public.expense_participant_status for insert
with check (
    exists (select 1 from public.expenses e where e.id = expense_id and public.is_admin_or_treasurer(e.plan_id))
);
