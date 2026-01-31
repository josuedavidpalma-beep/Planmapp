-- Migration: Add Responsible User to Payment Trackers
-- This allows linking a Guest (who has no account) to a Real User (who is responsible for collecting their share).

alter table public.payment_trackers
add column if not exists responsible_user_id uuid references auth.users(id);

comment on column public.payment_trackers.responsible_user_id is 'The user ID of the person responsible for this tracker (e.g. the one who invited the guest)';
