-- Add Reminder Columns to PLANS table
-- The user reported missing 'reminder_channel' error.

alter table public.plans 
add column if not exists reminder_channel text default 'whatsapp',
add column if not exists reminder_frequency text default 'weekly';
