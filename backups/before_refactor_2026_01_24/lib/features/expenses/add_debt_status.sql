-- Migration: Add Status to Expense Participant Status
-- Replaces simple boolean is_paid with a richer status for "Debt Recovery" panel.

alter table public.expense_participant_status
add column if not exists status text default 'pending';

-- Optional: Copy is_paid data to status for backward compatibility
update public.expense_participant_status
set status = 'paid'
where is_paid = true;

comment on column public.expense_participant_status.status is 'pending, reminded, paid';
