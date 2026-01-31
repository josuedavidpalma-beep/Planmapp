-- CHECK AND CREATE PROFILES TABLE

-- 1. Create table if not exists
create table if not exists public.profiles (
  id uuid references auth.users on delete cascade not null primary key,
  updated_at timestamp with time zone,
  full_name text,
  display_name text,
  avatar_url text,
  phone text,
  country_code text default '+57',
  birthday timestamp with time zone,
  preferences text[],
  
  constraint username_length check (char_length(full_name) >= 3)
);

-- 2. Enable RLS
alter table public.profiles enable row level security;

-- 3. Create policies (Open for MVP)
create policy "Public profiles are viewable by everyone." on public.profiles
  for select using (true);

create policy "Users can insert their own profile." on public.profiles
  for insert with check (auth.uid() = id);

create policy "Users can update own profile." on public.profiles
  for update using (auth.uid() = id);

-- 4. Auto-create profile on signup (Trigger)
-- This ensures that every new user in auth.users has a matching row in public.profiles
create or replace function public.handle_new_user() 
returns trigger as $$
begin
  insert into public.profiles (id, full_name, avatar_url)
  values (new.id, new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'avatar_url');
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();
