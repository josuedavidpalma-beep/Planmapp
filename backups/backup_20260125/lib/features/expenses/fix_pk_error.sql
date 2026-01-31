-- FIX EXPENSE PARTICIPANT STATUS PK
-- Primary Keys cannot contain NULL values. 
-- expense_participant_status had (expense_id, user_id, guest_name) as PK, but user_id is null for guests.
-- This causes issues. We will switch to a synthetic ID and Unique Constraints.

-- 1. Recreate table with proper constraints
drop table if exists public.expense_participant_status cascade;

create table public.expense_participant_status (
    id uuid default gen_random_uuid() primary key,
    expense_id uuid references public.expenses(id) on delete cascade not null,
    
    user_id uuid references auth.users(id), 
    guest_name text,
    
    amount_owed numeric default 0,
    is_paid boolean default false,
    
    -- Ensure either user_id OR guest_name is present
    constraint check_participant_identity check (
        (user_id is not null and guest_name is null) or 
        (user_id is null and guest_name is not null)
    ),
    
    -- Uniqueness
    constraint unique_user_per_expense unique nulls not distinct (expense_id, user_id),
    constraint unique_guest_per_expense unique nulls not distinct (expense_id, guest_name)
);

-- 2. Re-enable RLS
alter table public.expense_participant_status enable row level security;
create policy "Allow all for participant status" on public.expense_participant_status for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
