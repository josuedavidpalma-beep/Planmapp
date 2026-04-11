
-- FIX: Update RLS policies to allow Plan Creators to access their own plan's data
-- independent of the plan_members table status.

-- 1. Drop old policies (to be safe and replace them)
drop policy if exists "Users can view expenses of plans they belong to" on public.expenses;
drop policy if exists "Users can insert expenses to plans they belong to" on public.expenses;

drop policy if exists "Users can view items of visible expenses" on public.expense_items;
drop policy if exists "Users can insert items to visible expenses" on public.expense_items;

-- 2. New Expenses Policies
create policy "Creators and Members can view expenses"
  on public.expenses for select
  using (
    (select creator_id from public.plans where id = plan_id) = auth.uid()
    OR
    exists (
      select 1 from public.plan_members
      where plan_members.plan_id = expenses.plan_id
      and plan_members.user_id = auth.uid()
    )
  );

create policy "Creators and Members can insert expenses"
  on public.expenses for insert
  with check (
    (select creator_id from public.plans where id = plan_id) = auth.uid()
    OR
    exists (
      select 1 from public.plan_members
      where plan_members.plan_id = expenses.plan_id
      and plan_members.user_id = auth.uid()
    )
  );

-- 3. New Expense Items Policies
create policy "Creators and Members can view expense items"
  on public.expense_items for select
  using (
    exists (
      select 1 from public.expenses
      left join public.plans on plans.id = expenses.plan_id
      left join public.plan_members on plan_members.plan_id = expenses.plan_id
      where expenses.id = expense_items.expense_id
      and (
        plans.creator_id = auth.uid() 
        OR 
        plan_members.user_id = auth.uid()
      )
    )
  );

create policy "Creators and Members can insert expense items"
  on public.expense_items for insert
  with check (
    exists (
      select 1 from public.expenses
      left join public.plans on plans.id = expenses.plan_id
      left join public.plan_members on plan_members.plan_id = expenses.plan_id
      where expenses.id = expense_items.expense_id
      and (
        plans.creator_id = auth.uid() 
        OR 
        plan_members.user_id = auth.uid()
      )
    )
  );
