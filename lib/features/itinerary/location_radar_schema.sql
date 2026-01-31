-- Create table for real-time location sharing
CREATE TABLE public.user_locations (
    user_id UUID REFERENCES auth.users(id) NOT NULL,
    plan_id UUID REFERENCES public.plans(id) ON DELETE CASCADE NOT NULL,
    lat DOUBLE PRECISION NOT NULL,
    lng DOUBLE PRECISION NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (user_id, plan_id)
);

-- Enable RLS
ALTER TABLE public.user_locations ENABLE ROW LEVEL SECURITY;

-- Enable Realtime for this table
ALTER PUBLICATION supabase_realtime ADD TABLE public.user_locations;

-- Policies
-- 1. Users can upsert their OWN location
CREATE POLICY "Users can update own location" ON public.user_locations
    FOR INSERT
    WITH CHECK (auth.uid() = user_id)
    ON CONFLICT (user_id, plan_id) DO UPDATE SET lat = EXCLUDED.lat, lng = EXCLUDED.lng, updated_at = now();

CREATE POLICY "Users can update own location update" ON public.user_locations
    FOR UPDATE
    USING (auth.uid() = user_id);

-- 2. Plan Members can VIEW locations of others in the same plan
CREATE POLICY "Members can view plan locations" ON public.user_locations
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.plan_members
            WHERE plan_members.plan_id = user_locations.plan_id
            AND plan_members.user_id = auth.uid()
        )
    );
