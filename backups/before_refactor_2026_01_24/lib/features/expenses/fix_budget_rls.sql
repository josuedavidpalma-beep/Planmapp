
-- FIX BUDGET RLS: Split "ALL" policies into specific INSERT/UPDATE/SELECT to be safer and more explicit.
-- Sometimes 'FOR ALL' with 'USING' can be tricky for Inserts if Supabase client sends partial data?

-- 1. Budget Items
drop policy if exists "Creator/Admin manage budget" on public.budget_items;

create policy "Creator manage budget select"
  on public.budget_items for select
  using (
    (select creator_id from public.plans where id = plan_id) = auth.uid()
  );

create policy "Creator manage budget insert"
  on public.budget_items for insert
  with check (
    (select creator_id from public.plans where id = plan_id) = auth.uid()
  );

create policy "Creator manage budget update"
  on public.budget_items for update
  using ((select creator_id from public.plans where id = plan_id) = auth.uid());

create policy "Creator manage budget delete"
  on public.budget_items for delete
  using ((select creator_id from public.plans where id = plan_id) = auth.uid());


-- 2. Payment Trackers
drop policy if exists "Creator manage payments" on public.payment_trackers;

create policy "Creator manage payments insert"
  on public.payment_trackers for insert
  with check (
    (select creator_id from public.plans where id = plan_id) = auth.uid()
  );

create policy "Creator manage payments update"
  on public.payment_trackers for update
  using ((select creator_id from public.plans where id = plan_id) = auth.uid());

create policy "Creator manage payments delete"
  on public.payment_trackers for delete
  using ((select creator_id from public.plans where id = plan_id) = auth.uid());

-- NOTE: Select policies were already defined separately in previous script ("Safe view...") so we leave them or recreate if needed.
-- We will recreate them to be sure.
drop policy if exists "Safe view budget" on public.budget_items;
create policy "Safe view budget"
  on public.budget_items for select
  using (
    (select creator_id from public.plans where id = plan_id) = auth.uid()
    OR
    public.is_plan_member(plan_id)
  );

drop policy if exists "Safe view payments" on public.payment_trackers;
create policy "Safe view payments"
  on public.payment_trackers for select
  using (
    (select creator_id from public.plans where id = plan_id) = auth.uid()
    OR
    public.is_plan_member(plan_id)
  );
