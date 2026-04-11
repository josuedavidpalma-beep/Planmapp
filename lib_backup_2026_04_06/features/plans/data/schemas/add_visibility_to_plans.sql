
-- Add visibility column to plans
ALTER TABLE public.plans 
ADD COLUMN IF NOT EXISTS visibility text DEFAULT 'private' CHECK (visibility IN ('public', 'private'));

-- Update RLS for Public Plans
-- We want public plans to be viewable by ANY authenticated user (or just friends, but let's start with auth users for simplicity of "Public")
-- Existing policy usually checks for plan_members. We need to OR that with visibility = 'public'

DROP POLICY IF EXISTS "Enable read access for all users" ON public.plans; -- Remove old if exists
DROP POLICY IF EXISTS "Enable read for plan members" ON public.plans; 

CREATE POLICY "Enable read for members and public" ON public.plans
    FOR SELECT USING (
        (visibility = 'public') -- Public plans are open to read
        OR
        (auth.uid() = creator_id) -- Creator can always read
        OR
        EXISTS ( -- Members can read
            SELECT 1 FROM public.plan_members pm 
            WHERE pm.plan_id = id AND pm.user_id = auth.uid()
        )
    );

-- Ensure Insert/Update/Delete remains restricted (usually handled by other policies, but let's be safe)
-- We assume existing insert/update/delete policies are strictly for creator/members and don't need changing for visibility logic.
