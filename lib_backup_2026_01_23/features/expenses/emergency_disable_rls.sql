
-- EMERGENCY DEBUG: Temporarily Bypass RLS for Budget Tables
-- This will confirm if the issue is strictly permissions logic.

-- 1. Disable RLS entirely for these tables (Reset to public)
alter table public.budget_items disable row level security;
alter table public.payment_trackers disable row level security;

-- NOTE: Now ANYONE can read/write.
-- Try the app. 
-- If it works -> The logic is fine, policies were wrong.
-- If it fails -> The issue is code/data (e.g. invalid foreign keys, UUIDs).

-- We can re-enable later with:
-- alter table public.budget_items enable row level security;
-- alter table public.payment_trackers enable row level security;
