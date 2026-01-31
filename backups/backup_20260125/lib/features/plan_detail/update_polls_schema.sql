
-- Update Polls table to support Closing
alter table public.polls 
add column if not exists is_closed boolean default false;

-- Policy update (Optional): Ensure creators can update polls (e.g. to close them).
-- Usually 'update' policy might be missing for polls. Let's add it safely.
drop policy if exists "Creators can update polls" on public.polls;
create policy "Creators can update polls"
  on public.polls for update
  using (
    (select creator_id from public.plans where id = plan_id) = auth.uid()
  );
