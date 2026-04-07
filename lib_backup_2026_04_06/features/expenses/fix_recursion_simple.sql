-- SIMPLE & POWERFUL FIX FOR "INFINITE RECURSION" 🛡️
-- Run this in Supabase SQL Editor

-- 1. DROP PROBLEMATIC POLICIES (The ones causing loops)
DROP POLICY IF EXISTS "Plans visible to members" ON public.plans;
DROP POLICY IF EXISTS "Members view other members" ON public.plan_members;
DROP POLICY IF EXISTS "Member view members" ON public.plan_members;

-- 1.1 DROP NEW POLICIES (To avoid 'Already Exists' error on re-run)
DROP POLICY IF EXISTS "Plans visible to everyone relevant" ON public.plans;
DROP POLICY IF EXISTS "See co-members" ON public.plan_members;
DROP POLICY IF EXISTS "Insert Plans" ON public.plans;
DROP POLICY IF EXISTS "Self Join" ON public.plan_members;

-- 2. CREATE A SAFELIST FUNCTION (Bypasses RLS logic)
CREATE OR REPLACE FUNCTION public.get_my_plan_ids()
RETURNS SETOF uuid
LANGUAGE plpgsql
SECURITY DEFINER -- Critical: Runs as superuser
SET search_path = public
AS $$
BEGIN
    RETURN QUERY SELECT plan_id FROM public.plan_members WHERE user_id = auth.uid();
END;
$$;

-- 3. RECREATE POLICIES USING SAFELIST
-- Plans: I can see plans if I created them OR if I am in the list of my plans
CREATE POLICY "Plans visible to everyone relevant" ON public.plans
FOR SELECT USING (
    creator_id = auth.uid() 
    OR 
    id IN (SELECT get_my_plan_ids())
);

-- Plan Members: I can see rows where the plan_id is one of my plans
CREATE POLICY "See co-members" ON public.plan_members
FOR SELECT USING (
    plan_id IN (SELECT get_my_plan_ids())
);

-- 4. INSERT/UPDATE permissions (Standard)
CREATE POLICY "Insert Plans" ON public.plans FOR INSERT WITH CHECK (auth.uid() = creator_id);
CREATE POLICY "Self Join" ON public.plan_members FOR INSERT WITH CHECK (auth.uid() = user_id);
