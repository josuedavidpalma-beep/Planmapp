-- EXPENSES V2 SCHEMA

-- 1. Update EXPENSES table
alter table public.expenses 
add column if not exists payment_method text; -- e.g. "Nequi to 300...", "Cash", etc.

-- 2. Create EXPENSE_PARTICIPANT_STATUS table
-- Tracks how much each person owes for a specific expense and if they have paid.
create table if not exists public.expense_participant_status (
    expense_id uuid references public.expenses(id) on delete cascade,
    user_id uuid references auth.users(id), -- Nullable if guest? No, guests managed differently or mapped to null.
    guest_name text, -- If user_id is null, this must be set
    
    amount_owed numeric default 0,
    is_paid boolean default false,
    
    primary key (expense_id, user_id, guest_name)
);

-- 3. Create EXPENSE_ASSIGNMENTS table (Granular Splitting)
-- Replaces the simple array in expense_items
create table if not exists public.expense_assignments (
    id uuid default gen_random_uuid() primary key,
    expense_item_id uuid references public.expense_items(id) on delete cascade,
    
    user_id uuid references auth.users(id), -- Nullable for guests
    guest_name text, -- For "Novia de Joshua"
    
    quantity numeric default 1, -- Can be 0.5 for half a pizza
    
    created_at timestamp with time zone default now()
);

-- 4. Enable RLS
alter table public.expense_participant_status enable row level security;
alter table public.expense_assignments enable row level security;

-- 5. Policies (Open for MVP development)
create policy "Allow all for participant status" on public.expense_participant_status for all using (true) with check (true);
create policy "Allow all for assignments" on public.expense_assignments for all using (true) with check (true);
