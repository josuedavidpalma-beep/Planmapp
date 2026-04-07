-- Migration: Add Reminder fields to Plans
-- Allows storing frequency of automatic reminders (simulated manually for now)

alter table public.plans
add column if not exists reminder_frequency_days integer default 0, -- 0 = Off
add column if not exists last_reminder_sent timestamp with time zone;

comment on column public.plans.reminder_frequency_days is '0=Off, 1=Daily, 7=Weekly, etc.';
