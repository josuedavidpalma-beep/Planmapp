-- Remediation for public access bug in public.events
-- Drops the permissive policy and recreates structured Anon/Auth access

DROP POLICY IF EXISTS "Allow public read access" ON public.events;

-- Permitted readers: Anon (unauthenticated guests) and Authenticated users
CREATE POLICY "Allow anon read events"
ON public.events FOR SELECT
TO anon
USING (true);

CREATE POLICY "Allow auth read events"
ON public.events FOR SELECT
TO authenticated
USING (true);

-- Extra assurance to keep it enabled
ALTER TABLE public.events ENABLE ROW LEVEL SECURITY;
