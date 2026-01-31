-- ==========================================
-- FIX MISSING COLUMN AND PERMISSIONS
-- ==========================================

-- 1. Create the column (This was missing!)
alter table public.payment_trackers 
add column if not exists responsible_user_id uuid references auth.users(id);

-- 2. Make it optional (Nullable)
alter table public.payment_trackers 
alter column responsible_user_id drop not null;

-- 3. Enable Security (RLS)
alter table public.payment_trackers enable row level security;

-- 4. Clean up old policies to avoid "already exists" errors
drop policy if exists "Members can add guests" on public.payment_trackers;
drop policy if exists "Members manage trackers" on public.payment_trackers;
drop policy if exists "Allow all for trackers" on public.payment_trackers;

-- 5. Create the Master Policy
-- Allows members (and creator) to View, Add, and Edit trackers
create policy "Members manage trackers"
on public.payment_trackers for all
using (
  exists (
    select 1 from public.plan_members
    where plan_id = payment_trackers.plan_id
    and user_id = auth.uid()
  )
  or exists (
    select 1 from public.plans
    where id = payment_trackers.plan_id
    and creator_id = auth.uid()
  )
);
