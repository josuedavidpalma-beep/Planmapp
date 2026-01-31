-- FIX RLS INFINITE RECURSION
-- We need to break the loop where "checking permission" triggers "checking permission".
-- Method: Use a SECURITY DEFINER function to read plan_members without triggering RLS.

-- 1. Helper Function (Bypasses RLS)
CREATE OR REPLACE FUNCTION get_my_plan_ids()
RETURNS SETOF uuid
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT plan_id FROM plan_members WHERE user_id = auth.uid();
$$;

-- 2. Update the Policy for "Viewing Others"
DROP POLICY IF EXISTS "Members can view other members in same plan" ON plan_members;

CREATE POLICY "Members can view other members in same plan" 
ON plan_members FOR SELECT 
USING (
  plan_id IN (
    SELECT get_my_plan_ids()
  )
);

-- Note: The "Users can view their own membership" policy is fine and can stay.
-- But just in case, let's ensure it exists.
DROP POLICY IF EXISTS "Users can view their own membership" ON plan_members;
CREATE POLICY "Users can view their own membership" 
ON plan_members FOR SELECT 
USING (auth.uid() = user_id);
