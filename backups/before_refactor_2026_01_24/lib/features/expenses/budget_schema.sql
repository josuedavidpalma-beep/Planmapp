
-- BUDGET MODULE SCHEMA

-- 1. Budget Items Table
-- Stores the planned lines (e.g., "Hotel: $500.000")
create table if not exists public.budget_items (
  id uuid default gen_random_uuid() primary key,
  plan_id uuid references public.plans(id) on delete cascade not null,
  category text not null, -- 'Hospedaje', 'Alimentación', 'Transporte', 'Entretenimiento', 'Otros'
  description text, -- Optional detail ('Hotel Dann Carlton', etc.)
  estimated_amount numeric(12,2) not null default 0,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- RLS for Budget Items
alter table public.budget_items enable row level security;

create policy "Safe view budget"
  on public.budget_items for select
  using (
    (select creator_id from public.plans where id = plan_id) = auth.uid()
    OR
    public.is_plan_member(plan_id)
  );

create policy "Creator/Admin manage budget"
  on public.budget_items for all
  using (
    (select creator_id from public.plans where id = plan_id) = auth.uid()
  );


-- 2. Payment Tracking Table
-- Stores the collection status per member/guest
create table if not exists public.payment_trackers (
  id uuid default gen_random_uuid() primary key,
  plan_id uuid references public.plans(id) on delete cascade not null,
  
  -- Link to real user OR manual guest name. One must be set.
  user_id uuid references auth.users(id), 
  guest_name text, 
  
  status text default 'pending', -- pending, paid, partial, verifying
  
  amount_paid numeric(12,2) default 0, -- How much they have actually paid
  amount_owe numeric(12,2) default 0, -- How much they SHOULD pay (calculated quota)
  
  reminder_frequency text, -- 'daily', 'weekly', null (none)
  next_reminder timestamp with time zone,
  
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  
  constraint user_or_guest check (
    (user_id is not null and guest_name is null) or 
    (user_id is null and guest_name is not null)
  )
);

-- RLS for Payments
alter table public.payment_trackers enable row level security;

create policy "Safe view payments"
  on public.payment_trackers for select
  using (
    (select creator_id from public.plans where id = plan_id) = auth.uid()
    OR
    public.is_plan_member(plan_id)
  );

create policy "Creator manage payments"
  on public.payment_trackers for all
  using (
    (select creator_id from public.plans where id = plan_id) = auth.uid()
  );

-- Function to Auto-Init payments when Budget Updates? 
-- Ideally done in app logic for MVP to avoid complex triggers.
