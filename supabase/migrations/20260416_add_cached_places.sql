-- Migration: Add cached_places and update local_events status
-- Created at: 2026-04-16

-- 1. Create cached_places table
CREATE TABLE IF NOT EXISTS public.cached_places (
    place_id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    address TEXT,
    rating DOUBLE PRECISION,
    photo_reference TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    city TEXT DEFAULT 'Barranquilla',
    category TEXT, -- e.g. 'restaurant', 'bar', 'park'
    last_updated TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- RLS for cached_places
ALTER TABLE public.cached_places ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow public read access to cached_places" 
ON public.cached_places FOR SELECT 
USING (true);

CREATE POLICY "Allow anonymous insert to cached_places" 
ON public.cached_places FOR INSERT 
TO public 
WITH CHECK (true);

CREATE POLICY "Allow anonymous update to cached_places" 
ON public.cached_places FOR UPDATE 
TO public 
USING (true);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_cached_places_city ON public.cached_places(city);
CREATE INDEX IF NOT EXISTS idx_cached_places_category ON public.cached_places(category);
CREATE INDEX IF NOT EXISTS idx_cached_places_last_updated ON public.cached_places(last_updated);

-- 2. Add status column to local_events
ALTER TABLE public.local_events ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'active'; -- 'active', 'sold_out', 'cancelled'
CREATE INDEX IF NOT EXISTS idx_local_events_status ON public.local_events(status);
