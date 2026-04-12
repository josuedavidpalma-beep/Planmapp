-- =============================================================================
-- MIGRATION: Add geocoding fields to events table for Research Agent v2.0
-- Adds: latitude, longitude, google_place_id, rating_google, user_ratings_total
-- Also adds source_url unique constraint for upsert deduplication
-- =============================================================================

-- Add geocoding columns
ALTER TABLE public.events
  ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS google_place_id TEXT,
  ADD COLUMN IF NOT EXISTS rating_google NUMERIC(3,1),
  ADD COLUMN IF NOT EXISTS user_ratings_total INTEGER,
  ADD COLUMN IF NOT EXISTS address TEXT,
  ADD COLUMN IF NOT EXISTS city TEXT;

-- Add unique constraint on source_url for upsert deduplication
-- (If constraint already exists, this is a no-op)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'events_source_url_key'
  ) THEN
    ALTER TABLE public.events ADD CONSTRAINT events_source_url_key UNIQUE (source_url);
  END IF;
END
$$;

-- Update the insert policy to allow authenticated users
-- Using DO block because PostgreSQL doesn't support IF NOT EXISTS for policies
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'events'
    AND policyname = 'Allow authenticated insert'
  ) THEN
    EXECUTE 'CREATE POLICY "Allow authenticated insert" ON public.events FOR INSERT TO authenticated WITH CHECK (true)';
  END IF;
END
$$;

-- Create index on city for faster filtering
CREATE INDEX IF NOT EXISTS events_city_idx ON public.events (city);
CREATE INDEX IF NOT EXISTS events_category_idx ON public.events (category);
CREATE INDEX IF NOT EXISTS events_date_idx ON public.events (date);
