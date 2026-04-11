
-- 1. Plans Table (Core entity)
create table if not exists public.plans (
  id uuid default gen_random_uuid() primary key,
  creator_id uuid references auth.users(id) not null,
  title text not null,
  description text,
  event_date timestamp with time zone,
  location_name text,
  status text default 'draft', -- draft, active, completed, cancelled
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable RLS for plans
alter table public.plans enable row level security;

create policy "Users can view plans they created"
  on public.plans for select
  using (auth.uid() = creator_id);

create policy "Users can update plans they created"
  on public.plans for update
  using (auth.uid() = creator_id);

create policy "Users can insert plans"
  on public.plans for insert
  with check (auth.uid() = creator_id);


-- 2. Plan Members Table (Relational entity)
create table if not exists public.plan_members (
  id uuid default gen_random_uuid() primary key,
  plan_id uuid references public.plans(id) on delete cascade not null,
  user_id uuid references auth.users(id) not null,
  role text default 'member', -- admin, member
  status text default 'accepted', -- invited, accepted, declined
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  unique(plan_id, user_id)
);

-- Enable RLS for members
alter table public.plan_members enable row level security;

create policy "Users can view members of plans they are in"
  on public.plan_members for select
  using (
    exists (
      select 1 from public.plan_members pm
      where pm.plan_id = plan_members.plan_id
      and pm.user_id = auth.uid()
    )
    or
    user_id = auth.uid()
  );

create policy "Creator can add members"
  on public.plan_members for insert
  with check (
    exists (
      select 1 from public.plans
      where id = plan_members.plan_id
      and creator_id = auth.uid()
    )
  );


-- 3. Expenses Table (From previous step)
create table if not exists public.expenses (
  id uuid default gen_random_uuid() primary key,
  plan_id uuid references public.plans(id) on delete cascade not null,
  created_by uuid references auth.users(id) on delete cascade not null,
  title text not null,
  total_amount numeric(10,2) not null default 0,
  currency text default 'COP',
  receipt_image_url text,
  ocr_raw_data jsonb,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.expenses enable row level security;

create policy "Users can view expenses of plans they belong to"
  on public.expenses for select
  using (
    exists (
      select 1 from public.plan_members
      where plan_members.plan_id = expenses.plan_id
      and plan_members.user_id = auth.uid()
    )
  );

create policy "Users can insert expenses to plans they belong to"
  on public.expenses for insert
  with check (
    exists (
      select 1 from public.plan_members
      where plan_members.plan_id = expenses.plan_id
      and plan_members.user_id = auth.uid()
    )
  );

-- 4. Expense Items Table
create table if not exists public.expense_items (
  id uuid default gen_random_uuid() primary key,
  expense_id uuid references public.expenses(id) on delete cascade not null,
  name text not null,
  price numeric(10,2) not null,
  quantity integer default 1,
  assigned_to uuid[] default array[]::uuid[],
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.expense_items enable row level security;

create policy "Users can view items of visible expenses"
  on public.expense_items for select
  using (
    exists (
      select 1 from public.expenses
      inner join public.plan_members on plan_members.plan_id = expenses.plan_id
      where expenses.id = expense_items.expense_id
      and plan_members.user_id = auth.uid()
    )
  );

create policy "Users can insert items to visible expenses"
  on public.expense_items for insert
  with check (
    exists (
      select 1 from public.expenses
      inner join public.plan_members on plan_members.plan_id = expenses.plan_id
      where expenses.id = expense_items.expense_id
      and plan_members.user_id = auth.uid()
    )
  );
