-- ⚡ ENABLE REALTIME & FIX UPDATES ⚡
-- Run this in Supabase SQL Editor

-- 1. Enable Realtime Replication for Tables
-- This ensures 'stream()' works for these tables.
alter publication supabase_realtime add table messages;
alter publication supabase_realtime add table polls;
alter publication supabase_realtime add table poll_votes;
alter publication supabase_realtime add table poll_options;

-- 2. POLLS REFRESH TRIGGER 🔄
-- Problem: 'stream(polls)' doesn't detect when a VOTE happens in 'poll_votes'.
-- Solution: We update the 'polls' table timestamp whenever a vote occurs.

ALTER TABLE public.polls ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

CREATE OR REPLACE FUNCTION public.touch_poll_updated_at()
RETURNS TRIGGER 
SECURITY DEFINER
AS $$
BEGIN
    UPDATE public.polls
    SET updated_at = now()
    WHERE id = NEW.poll_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_vote_update_poll ON public.poll_votes;
CREATE TRIGGER on_vote_update_poll
AFTER INSERT OR DELETE ON public.poll_votes
FOR EACH ROW EXECUTE FUNCTION public.touch_poll_updated_at();

-- 3. CHAT REFRESH
-- Messages usually work if Realtime is enabled (Step 1).
-- We ensure the 'messages' table allows appropriate access.
-- (RLS Policies should be already fixed by previous scripts)
