-- Create Activities table for Itinerary
CREATE TABLE public.activities (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    plan_id UUID REFERENCES public.plans(id) ON DELETE CASCADE NOT NULL,
    title TEXT NOT NULL,
    description TEXT,
    location_name TEXT,
    location_lat DOUBLE PRECISION,
    location_lng DOUBLE PRECISION,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ,
    category TEXT CHECK (category IN ('transport', 'food', 'lodging', 'activity', 'other')) DEFAULT 'other',
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.activities ENABLE ROW LEVEL SECURITY;

-- Helper function to check if user is admin or creator
-- (Assuming we reuse the helper functions from expenses module if available, otherwise defining inline logic)

-- Policy: Members can VIEW activities
CREATE POLICY "Members can view activities" ON public.activities
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.plan_members
            WHERE plan_members.plan_id = activities.plan_id
            AND plan_members.user_id = auth.uid()
        )
    );

-- Policy: Only Admins/Treasurers (or Plan Creator) can INSERT/UPDATE/DELETE
-- Reusing the is_admin_or_treasurer logic implicitly by checking role in plan_members
CREATE POLICY "Admins can manage activities" ON public.activities
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.plan_members
            WHERE plan_members.plan_id = activities.plan_id
            AND plan_members.user_id = auth.uid()
            AND plan_members.role IN ('admin', 'treasurer')
        )
    );
