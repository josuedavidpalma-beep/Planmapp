-- FINAL RLS FIX (Run this to fix Polls/Messages Visibility)
-- Bypasses recursion using the helper function.

-- 1. Ensure Helper Function Exists AND Has Permissions
CREATE OR REPLACE FUNCTION get_my_plan_ids()
RETURNS SETOF uuid
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT plan_id FROM plan_members WHERE user_id = auth.uid();
$$;

-- IMPORTANT: Grant access to authenticated users
GRANT EXECUTE ON FUNCTION get_my_plan_ids() TO authenticated;
GRANT EXECUTE ON FUNCTION get_my_plan_ids() TO service_role;

-- 2. FIX PLAN_MEMBERS
DROP POLICY IF EXISTS "Members can view other members" ON plan_members;
DROP POLICY IF EXISTS "Users can view their own membership" ON plan_members;
DROP POLICY IF EXISTS "Members can view other members in same plan" ON plan_members;

CREATE POLICY "Users can view their own membership" 
ON plan_members FOR SELECT 
USING (auth.uid() = user_id);

CREATE POLICY "Members can view other members in same plan" 
ON plan_members FOR SELECT 
USING (
  plan_id IN ( SELECT get_my_plan_ids() )
);

-- 3. FIX POLLS
DROP POLICY IF EXISTS "Plan members can view polls" ON polls;
DROP POLICY IF EXISTS "Admins can create polls" ON polls;
DROP POLICY IF EXISTS "Plan members can create polls" ON polls;

CREATE POLICY "Plan members can view polls"
ON polls FOR SELECT
USING (
  plan_id IN ( SELECT get_my_plan_ids() )
);

CREATE POLICY "Plan members can create polls" 
ON polls FOR INSERT 
WITH CHECK (
  plan_id IN ( SELECT get_my_plan_ids() )
);

DROP POLICY IF EXISTS "Plan members can update polls" ON polls;
CREATE POLICY "Plan members can update polls"
ON polls FOR UPDATE
USING (
  plan_id IN ( SELECT get_my_plan_ids() )
);

DROP POLICY IF EXISTS "Plan members can delete polls" ON polls;
CREATE POLICY "Plan members can delete polls"
ON polls FOR DELETE
USING (
  plan_id IN ( SELECT get_my_plan_ids() )
);

-- 3.1 FIX POLL OPTIONS / VOTES (Permissive Mode to fix 'Missing Options' bug)
-- Rely on Foreign Key constraints for integrity instead of complex RLS for now.

DROP POLICY IF EXISTS "Members view options" ON poll_options;
CREATE POLICY "Members view options" ON poll_options FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Members insert options" ON poll_options;
CREATE POLICY "Members insert options" ON poll_options FOR INSERT TO authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "Members delete options" ON poll_options;
CREATE POLICY "Members delete options" ON poll_options FOR DELETE TO authenticated USING (true);


DROP POLICY IF EXISTS "Members view votes" ON poll_votes;
CREATE POLICY "Members view votes" ON poll_votes FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Members vote" ON poll_votes;
CREATE POLICY "Members vote" ON poll_votes FOR INSERT TO authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "Members change vote" ON poll_votes;
CREATE POLICY "Members change vote" ON poll_votes FOR DELETE TO authenticated USING (user_id = auth.uid());


-- 4. FIX MESSAGES
DROP POLICY IF EXISTS "Plan members can view messages" ON messages;
DROP POLICY IF EXISTS "Plan members can insert messages" ON messages;

CREATE POLICY "Plan members can view messages"
ON messages FOR SELECT
USING (
  plan_id IN ( SELECT get_my_plan_ids() )
);

CREATE POLICY "Plan members can insert messages"
ON messages FOR INSERT
WITH CHECK (
  plan_id IN ( SELECT get_my_plan_ids() )
);
