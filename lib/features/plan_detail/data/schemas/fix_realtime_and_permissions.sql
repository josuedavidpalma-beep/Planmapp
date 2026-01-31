-- FIX FOR VISIBILITY (Attempt 3 - Corrected Drops)

-- 1. TEMPORARY: Make Policies Extremely Permissive to Rule out Logic Errors
-- We will revert this to the secure version later, but first we MUST see the data.

-- POLLS
DROP POLICY IF EXISTS "Plan members can view polls" ON polls;
CREATE POLICY "Plan members can view polls" ON polls FOR SELECT USING (true); -- Public for authenticated users

DROP POLICY IF EXISTS "Plan members can create polls" ON polls;
CREATE POLICY "Plan members can create polls" ON polls FOR INSERT WITH CHECK (true);

-- POLL OPTIONS (Fixing the error here)
DROP POLICY IF EXISTS "Members view options" ON poll_options;
CREATE POLICY "Members view options" ON poll_options FOR SELECT USING (true);

DROP POLICY IF EXISTS "Members insert options" ON poll_options;
CREATE POLICY "Members insert options" ON poll_options FOR INSERT WITH CHECK (true);

-- POLL VOTES
DROP POLICY IF EXISTS "Members view votes" ON poll_votes;
CREATE POLICY "Members view votes" ON poll_votes FOR SELECT USING (true);

DROP POLICY IF EXISTS "Members vote" ON poll_votes;
CREATE POLICY "Members vote" ON poll_votes FOR INSERT WITH CHECK (true);

-- 2. CONFIRMATION
-- Run this, then try the Debug Button again.
