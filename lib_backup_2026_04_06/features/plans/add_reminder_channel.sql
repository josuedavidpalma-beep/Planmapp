-- Add Reminder Channel
alter table public.plans
add column if not exists reminder_channel text default 'whatsapp'; -- 'email', 'whatsapp', 'push'
