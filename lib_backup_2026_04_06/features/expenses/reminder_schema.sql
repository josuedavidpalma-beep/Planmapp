
-- Add Budget and Reminder settings to Plans
alter table public.plans 
add column if not exists budget_deadline timestamp with time zone,
add column if not exists reminder_frequency_days int default 0,
add column if not exists last_reminder_sent timestamp with time zone; -- 0 = off

-- Also, adding a 'status' column to handle archiving (Part of a previous suggestion)
do $$ 
begin
    if not exists (select 1 from information_schema.columns where table_name='plans' and column_name='status') then
        alter table public.plans add column status text default 'active';
    end if;
end $$;
