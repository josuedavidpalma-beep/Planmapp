-- Migration: Add place_id to local_events
-- Created at: 2026-04-23

-- 1. Add place_id column to local_events
ALTER TABLE public.local_events ADD COLUMN IF NOT EXISTS place_id TEXT REFERENCES public.cached_places(place_id) ON DELETE SET NULL;

-- 2. Create index for fast joins
CREATE INDEX IF NOT EXISTS idx_local_events_place_id ON public.local_events(place_id);
