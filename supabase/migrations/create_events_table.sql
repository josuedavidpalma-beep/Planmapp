-- Create events table
create table public.events (
  id uuid default gen_random_uuid() primary key,
  title text not null,
  description text,
  date text, -- Storing as text for flexibility (e.g. "Próximamente", "2023-10-20")
  location text,
  category text,
  image_url text,
  source_url text,
  created_at timestamp with time zone default timezone('utc', now()) not null
);

-- Enable Row Level Security
alter table public.events enable row level security;

-- Create policy to allow public read access
create policy "Allow public read access"
on public.events
for select
to public
using (true);

-- Create policy to allow insert only by authenticated users (service role)
-- In the python script we use the service role key or a user with write access.
-- If using anon key with specific logic, adjust here. 
-- For simplicity in this automation context, we'll assume the script uses a key with rights.
create policy "Allow service role insert"
on public.events
for insert
to service_role
with check (true);
