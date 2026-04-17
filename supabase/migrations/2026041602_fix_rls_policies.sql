-- 1. Fix RLS for cached_places (Allow UPSERT from Frontend)
-- Currently it only allows SELECT, which blocks the app from saving Google results.

DROP POLICY IF EXISTS "Allow anonymous and authenticated insert to cached_places" ON public.cached_places;
CREATE POLICY "Allow anonymous and authenticated insert to cached_places" 
ON public.cached_places FOR INSERT 
TO public 
WITH CHECK (true);

DROP POLICY IF EXISTS "Allow anonymous and authenticated update to cached_places" ON public.cached_places;
CREATE POLICY "Allow anonymous and authenticated update to cached_places" 
ON public.cached_places FOR UPDATE 
TO public 
USING (true)
WITH CHECK (true);

-- 2. Ensure local_events is readable (Should be done, but double check)
-- This ensures the Scraper results are visible to todos.
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'local_events' AND policyname = 'Allow public read access to local_events'
    ) THEN
        CREATE POLICY "Allow public read access to local_events" 
        ON public.local_events FOR SELECT 
        USING (true);
    END IF;
END $$;
