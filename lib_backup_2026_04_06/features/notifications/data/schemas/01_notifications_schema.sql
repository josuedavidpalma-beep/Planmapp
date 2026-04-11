-- Enable RLS
alter table if exists public.notifications enable row level security;

-- Create Notifications Table
create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  body text not null,
  type text not null, -- 'invite', 'chat', 'poll', 'general'
  data jsonb default '{}'::jsonb, -- Store related IDs (plan_id, etc.)
  is_read boolean default false,
  created_at timestamptz default now()
);

-- RLS Policies
create policy "Users can view their own notifications"
  on public.notifications for select
  using (auth.uid() = user_id);

create policy "Users can update their own notifications (mark as read)"
  on public.notifications for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Function to handle new plan invitations
create or replace function public.handle_new_plan_member()
returns trigger as $$
declare
  plan_title text;
  inviter_name text;
begin
  -- Get plan title
  select title into plan_title from public.plans where id = new.plan_id;
  
  -- Get inviter name (optional, if we track who invited)
  -- For now, just generic message
  
  -- Only notify if the user is not the creator (assuming creator is added automatically, handled by app logic)
  -- Or strictly notify on 'invited' status if that column exists. 
  -- Assuming simple membership insert for now.

  insert into public.notifications (user_id, title, body, type, data)
  values (
    new.user_id,
    'Nueva Invitación',
    'Has sido invitado al plan: ' || coalesce(plan_title, 'Sin nombre'),
    'invite',
    jsonb_build_object('plan_id', new.plan_id)
  );

  return new;
end;
$$ language plpgsql security definer;

-- Trigger for Plan Members
-- Note: Check if plan_members table exists and structure matches. 
-- Creating trigger conditionally or assuming it exists.
drop trigger if exists on_plan_member_added on public.plan_members;

create trigger on_plan_member_added
  after insert on public.plan_members
  for each row
  execute procedure public.handle_new_plan_member();
