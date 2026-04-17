-- Migration: Add metadata columns for Premium UI (Price & Hours)

-- 1. Updates for cached_places
ALTER TABLE public.cached_places ADD COLUMN IF NOT EXISTS price_level TEXT;
ALTER TABLE public.cached_places ADD COLUMN IF NOT EXISTS open_now BOOLEAN;

-- 2. Updates for local_events
ALTER TABLE public.local_events ADD COLUMN IF NOT EXISTS price_level TEXT;

-- 3. Update RLS policies to allow updating these new columns
-- (The existing policies with USING(true)/WITH CHECK(true) should already cover this,
-- but we ensure the schema is fresh).
