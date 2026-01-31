-- 2.1 Tabla: invoices (Cabecera)
create table public.invoices (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users not null,
  plan_id uuid references public.plans not null, -- Added plan_id to link to specific plan
  vendor_name text,
  invoice_date date,
  total_amount numeric(10,2), -- Importante: usar numeric para cálculos financieros exactos
  currency text default 'COP',
  scan_image_url text, -- URL de la imagen en Supabase Storage
  status text check (status in ('pending_review', 'approved', 'rejected')) default 'pending_review',
  created_at timestamp with time zone default timezone('utc'::text, now())
);

-- 2.2 Tabla: invoice_items (Detalle)
create table public.invoice_items (
  id uuid default gen_random_uuid() primary key,
  invoice_id uuid references public.invoices on delete cascade not null,
  description text,
  quantity numeric(10,2) default 1,
  unit_price numeric(10,2),
  total_line_amount numeric(10,2) -- quantity * unit_price
);

-- RLS Policies
alter table public.invoices enable row level security;
alter table public.invoice_items enable row level security;

-- Allow read access to plan members
create policy "Invoices are viewable by plan members"
on public.invoices for select
using (
  exists (
    select 1 from public.plan_members
    where plan_members.plan_id = invoices.plan_id
    and plan_members.user_id = auth.uid()
  )
);

-- Allow insert by plan members
create policy "Plan members can upload invoices"
on public.invoices for insert
with check (
  exists (
    select 1 from public.plan_members
    where plan_members.plan_id = invoices.plan_id
    and plan_members.user_id = auth.uid()
  )
);
