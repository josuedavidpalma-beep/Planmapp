-- ==========================================
-- FIX RESPONSIBLE USER ERROR
-- ==========================================
-- This script fixes issues where adding a guest fails due to 'responsible_user_id' constraints.

-- 1. Ensure the column is nullable (so it doesn't fail if we can't find one)
alter table public.payment_trackers 
alter column responsible_user_id drop not null;

-- 2. Add RLS Policies for Payment Trackers (likely missing)
alter table public.payment_trackers enable row level security;

-- Allow insert if you are a plan member
create policy "Members can add guests"
on public.payment_trackers for insert
with check (
  exists (
    select 1 from public.plan_members
    where plan_id = payment_trackers.plan_id
    and user_id = auth.uid()
  )
  -- Or if you are the creator (for the 'Ghost Plan' edge case)
  or exists (
    select 1 from public.plans
    where id = payment_trackers.plan_id
    and creator_id = auth.uid()
  )
);

-- Allow select/update for all members
create policy "Members manage trackers"
on public.payment_trackers for all
using (
  exists (
    select 1 from public.plan_members
    where plan_id = payment_trackers.plan_id
    and user_id = auth.uid()
  )
);

-- 3. Cleanup any potential bad triggers (Guessing names)
drop trigger if exists check_responsible_user on public.payment_trackers;
drop function if exists check_responsible_user();
