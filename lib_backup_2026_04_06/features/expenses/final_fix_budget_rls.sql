
-- FINAL FIX: RLS "Forbidden" on Subqueries
-- The issue is likely that the policy cannot "see" the plan record to verify you are the creator
-- because RLS on the 'plans' table itself restricts it or verification is complex.

-- 1. Create a helper for Creator check (Bypasses RLS safe)
create or replace function public.is_plan_creator(_plan_id uuid)
returns boolean 
language plpgsql 
security definer 
as $$
begin
  return exists (select 1 from public.plans where id = _plan_id and creator_id = auth.uid());
end;
$$;

-- 2. Update Budget Items Policies to use this function
drop policy if exists "Creator manage budget insert" on public.budget_items;
drop policy if exists "Creator manage budget update" on public.budget_items;
drop policy if exists "Creator manage budget delete" on public.budget_items;

create policy "Creator manage budget insert"
  on public.budget_items for insert
  with check ( public.is_plan_creator(plan_id) );

create policy "Creator manage budget update"
  on public.budget_items for update
  using ( public.is_plan_creator(plan_id) );

create policy "Creator manage budget delete"
  on public.budget_items for delete
  using ( public.is_plan_creator(plan_id) );

-- 3. Update Payment Trackers Policies
drop policy if exists "Creator manage payments insert" on public.payment_trackers;
drop policy if exists "Creator manage payments update" on public.payment_trackers;
drop policy if exists "Creator manage payments delete" on public.payment_trackers;

create policy "Creator manage payments insert"
  on public.payment_trackers for insert
  with check ( public.is_plan_creator(plan_id) );

create policy "Creator manage payments update"
  on public.payment_trackers for update
  using ( public.is_plan_creator(plan_id) );

create policy "Creator manage payments delete"
  on public.payment_trackers for delete
  using ( public.is_plan_creator(plan_id) );

 -- 4. DEBUG: Allow Members to also Insert (if you want friends to help)
 -- Optional: Uncomment if the above still fails for some reason, implying you are NOT creator.
 -- create policy "Members can add items" on public.budget_items for insert with check (public.is_plan_member(plan_id));
