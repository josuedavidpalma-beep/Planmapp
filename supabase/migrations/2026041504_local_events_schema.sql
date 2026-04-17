
-- Migration: Create local_events table
CREATE TABLE IF NOT EXISTS public.local_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_name TEXT NOT NULL,
    description TEXT,
    date DATE NOT NULL,
    end_date DATE,
    venue_name TEXT,
    address TEXT,
    reservation_link TEXT,
    contact_phone TEXT,
    price_range TEXT,
    primary_source TEXT,
    image_url TEXT,
    city TEXT NOT NULL,
    vibe_tag TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Prevent duplicates by name, date and city
    UNIQUE(event_name, date, city)
);

-- RLS
ALTER TABLE public.local_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow public read access to local_events" ON public.local_events;
CREATE POLICY "Allow public read access to local_events" 
ON public.local_events FOR SELECT 
USING (true);

DROP POLICY IF EXISTS "Allow authenticated users to insert local_events" ON public.local_events;
CREATE POLICY "Allow authenticated users to insert local_events"
ON public.local_events FOR INSERT
WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Allow individual update to local_events" ON public.local_events;
CREATE POLICY "Allow individual update to local_events"
ON public.local_events FOR UPDATE
USING (auth.role() = 'authenticated')
WITH CHECK (auth.role() = 'authenticated');

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_local_events_city ON public.local_events(city);
CREATE INDEX IF NOT EXISTS idx_local_events_date ON public.local_events(date);
CREATE INDEX IF NOT EXISTS idx_local_events_vibe ON public.local_events(vibe_tag);
