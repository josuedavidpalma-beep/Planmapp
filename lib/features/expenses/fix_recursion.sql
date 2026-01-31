
-- FIX: Infinite Recursion (Error 42P17)
-- We will implement a "Security Definer" function. 
-- This function runs with the privileges of the database owner, bypassing RLS.
-- This allows us to check membership inside an RLS policy without causing an infinite loop.

-- 1. Create Helper Function
create or replace function public.is_plan_member(_plan_id uuid)
returns boolean 
language plpgsql 
security definer -- BYPASS RLS
as $$
begin
  return exists (
    select 1 from public.plan_members
    where plan_id = _plan_id
    and user_id = auth.uid()
  );
end;
$$;

-- 2. Drop recursively problematic policies on `plan_members`
drop policy if exists "Users can view members of plans they are in" on public.plan_members;
drop policy if exists "Creator can add members" on public.plan_members;

-- 3. Re-create `plan_members` policies using the secure function or simpler attributes
-- Viewing: I can see a row in plan_members if:
-- A) It's me (user_id = auth.uid())
-- B) I created the plan (join plans)
-- C) I am a member of that plan (recursion break via function)

create policy "Safe view members"
  on public.plan_members for select
  using (
    user_id = auth.uid() -- It's me
    OR
    (select creator_id from public.plans where id = plan_id) = auth.uid() -- I'm creator
    OR
    public.is_plan_member(plan_id) -- I'm a member (using security definer function)
  );

create policy "Safe insert members"
  on public.plan_members for insert
  with check (
    (select creator_id from public.plans where id = plan_id) = auth.uid()
  );

-- 4. Update Expenses Policies to use the function too (Cleaner and Faster)
drop policy if exists "Creators and Members can view expenses" on public.expenses;
drop policy if exists "Creators and Members can insert expenses" on public.expenses;

create policy "View expenses safe"
  on public.expenses for select
  using (
    (select creator_id from public.plans where id = plan_id) = auth.uid()
    OR
    public.is_plan_member(plan_id)
  );

create policy "Insert expenses safe"
  on public.expenses for insert
  with check (
    (select creator_id from public.plans where id = plan_id) = auth.uid()
    OR
    public.is_plan_member(plan_id)
  );

-- 5. Update Expense Items Policies
drop policy if exists "Creators and Members can view expense items" on public.expense_items;
drop policy if exists "Creators and Members can insert expense items" on public.expense_items;

create policy "View items safe"
  on public.expense_items for select
  using (
    exists (
        select 1 from public.expenses e
        where e.id = expense_items.expense_id
        and (
            (select creator_id from public.plans where id = e.plan_id) = auth.uid()
            OR
            public.is_plan_member(e.plan_id)
        )
    )
  );

create policy "Insert items safe"
  on public.expense_items for insert
  with check (
    exists (
        select 1 from public.expenses e
        where e.id = expense_items.expense_id
        and (
            (select creator_id from public.plans where id = e.plan_id) = auth.uid()
            OR
            public.is_plan_member(e.plan_id)
        )
    )
  );
