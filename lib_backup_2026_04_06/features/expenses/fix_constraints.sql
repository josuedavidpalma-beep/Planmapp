-- FIX CONSTRAINTS
-- The previous constraints used "NULLS NOT DISTINCT" which prevented multiple guests (because user_id is null for all guests)
-- and multiple users (because guest_name is null for all users).

-- 1. Drop the incorrect constraints
alter table public.expense_participant_status 
drop constraint if exists unique_user_per_expense,
drop constraint if exists unique_guest_per_expense;

-- 2. Add standard UNIQUE constraints (where NULLs are distinct by default)
-- This allows:
-- - Multiple rows with user_id = NULL (multiple guests) as long as guest_name is different (handled by business logic & PK mostly)
-- - Multiple rows with guest_name = NULL (multiple users) as long as user_id is different.

alter table public.expense_participant_status
add constraint unique_user_per_expense unique (expense_id, user_id),
add constraint unique_guest_per_expense unique (expense_id, guest_name);
