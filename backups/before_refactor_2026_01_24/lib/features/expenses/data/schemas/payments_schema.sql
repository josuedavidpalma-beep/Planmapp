
-- 1. Payments / Settlements Table
-- Records direct money transfers between users to settle debts.
create table if not exists public.payments (
    id uuid default gen_random_uuid() primary key,
    plan_id uuid references public.plans(id) on delete cascade not null,
    from_user_id uuid references auth.users(id) not null,
    to_user_id uuid references auth.users(id) not null,
    amount numeric(10,2) not null check (amount > 0),
    currency text default 'COP',
    method text default 'cash', -- cash, zelle, transfer, etc.
    note text,
    confirmed_at timestamp with time zone, -- If null, it's pending approval
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable RLS
alter table public.payments enable row level security;

-- Policies
create policy "Members can view payments in their plan"
    on public.payments for select
    using (
        exists (
            select 1 from public.plan_members
            where plan_id = payments.plan_id
            and user_id = auth.uid()
        )
    );

create policy "Users can record payments they make"
    on public.payments for insert
    with check (
        auth.uid() = from_user_id
        and exists (
            select 1 from public.plan_members
            where plan_id = payments.plan_id
            and user_id = auth.uid()
        )
    );

create policy "Users can update payments involving them"
    on public.payments for update
    using (
       auth.uid() = from_user_id or auth.uid() = to_user_id
    );

-- 2. Helper View for Debt Calculation (Simplified)
-- This view flattens the expense_items.assigned_to array to rows
create or replace view public.view_expense_obligations as
select
    e.plan_id,
    e.created_by as creditor_id, -- The one who paid the expense
    unnest(ei.assigned_to) as debtor_id, -- The one who owes
    (ei.price * ei.quantity) / array_length(ei.assigned_to, 1) as amount -- Simple split
from public.expenses e
join public.expense_items ei on e.id = ei.expense_id
where array_length(ei.assigned_to, 1) > 0;
