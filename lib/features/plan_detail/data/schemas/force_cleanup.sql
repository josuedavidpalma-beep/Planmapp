-- FORCE DELETE ALL PLANS FOR A SPECIFIC USER (Manual Mode)

-- 1. Helper function that takes a User ID explicitly
create or replace function wipe_plans_for_user(target_user_id uuid)
returns void
language plpgsql
security definer
as $$
begin
  -- 1. Delete poll votes in plans created by user
  delete from poll_votes where poll_id in (select id from polls where plan_id in (select id from plans where creator_id = target_user_id));
  -- 2. Delete poll options
  delete from poll_options where poll_id in (select id from polls where plan_id in (select id from plans where creator_id = target_user_id));
  -- 3. Delete polls
  delete from polls where plan_id in (select id from plans where creator_id = target_user_id);
  
  -- 4. Delete other dependencies
  delete from expenses where plan_id in (select id from plans where creator_id = target_user_id);
  delete from budget_items where plan_id in (select id from plans where creator_id = target_user_id);
  delete from activities where plan_id in (select id from plans where creator_id = target_user_id);
  delete from messages where plan_id in (select id from plans where creator_id = target_user_id);
  delete from plan_members where plan_id in (select id from plans where creator_id = target_user_id);
  
  -- 5. Delete the plans
  delete from plans where creator_id = target_user_id;

  -- 6. Clean up where user is just a member
  delete from plan_members where user_id = target_user_id;
  
end;
$$;

-- INSTRUCTIONS:
-- 1. Run the huge block above to create the function.
-- 2. Find your User ID running this:
--    SELECT id, email FROM auth.users;
-- 3. Run the cleanup function with your ID:
--    SELECT wipe_plans_for_user('tu-id-aqui-xxxx-xxxx-xxxx');
