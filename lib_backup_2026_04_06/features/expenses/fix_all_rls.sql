-- FIX PERMISSIONS (RLS) script

-- 1. Enable RLS on tables (good practice, but we will be permissive)
alter table public.plans enable row level security;
alter table public.budget_items enable row level security;
alter table public.payment_trackers enable row level security;

-- 2. Drop potential conflicting policies (Clean slate)
drop policy if exists "Enable read access for all users" on public.plans;
drop policy if exists "Enable insert for authenticated users" on public.plans;
drop policy if exists "Enable update for creators" on public.plans;
drop policy if exists "Allow all for budget items" on public.budget_items;
drop policy if exists "Allow all for trackers" on public.payment_trackers;
drop policy if exists "Public plans access" on public.plans;
drop policy if exists "Creator access" on public.plans;

-- 3. Create PERMISSIVE policies for MVP (Allow logged-in users to do everything)
-- For PLANS
create policy "Allow All Authenticated Plans"
on public.plans
for all
to authenticated
using (true)
with check (true);

-- For BUDGET ITEMS
create policy "Allow All Authenticated Budget"
on public.budget_items
for all
to authenticated
using (true)
with check (true);

-- For PAYMENT TRACKERS
create policy "Allow All Authenticated Trackers"
on public.payment_trackers
for all
to authenticated
using (true)
with check (true);

-- DONE
