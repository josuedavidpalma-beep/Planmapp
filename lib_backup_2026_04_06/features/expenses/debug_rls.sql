
-- DEBUG: Temporarily allow all inserts to isolate the issue
drop policy if exists "Insert expenses safe" on public.expenses;

create policy "Debug insert expenses"
  on public.expenses for insert
  with check (auth.uid() = auth.uid()); -- Allow any auth user to insert

-- If this works, we know the previous logic (creator check or is_member) was failing.
-- Usually it fails because the user is NOT creator (maybe id mismatch?) and NOT member.
