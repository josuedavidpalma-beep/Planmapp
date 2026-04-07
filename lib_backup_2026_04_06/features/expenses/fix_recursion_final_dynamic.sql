-- ☢️ NUCLEAR V2: DYNAMIC POLICY CLEANUP ☢️
-- Run this in Supabase SQL Editor.
-- It will find and DELETE ALL policies on 'plans' and 'plan_members', regardless of their name.

DO $$ 
DECLARE 
  r RECORD; 
BEGIN 
  -- 1. Drop ALL policies on 'plan_members'
  FOR r IN (SELECT policyname FROM pg_policies WHERE tablename = 'plan_members' AND schemaname = 'public') LOOP 
    EXECUTE 'DROP POLICY IF EXISTS "' || r.policyname || '" ON public.plan_members'; 
    RAISE NOTICE 'Dropped policy: % on plan_members', r.policyname;
  END LOOP; 
  
  -- 2. Drop ALL policies on 'plans'
  FOR r IN (SELECT policyname FROM pg_policies WHERE tablename = 'plans' AND schemaname = 'public') LOOP 
    EXECUTE 'DROP POLICY IF EXISTS "' || r.policyname || '" ON public.plans'; 
    RAISE NOTICE 'Dropped policy: % on plans', r.policyname;
  END LOOP; 
END $$;

-- 3. SAFER FUNCTIONS (Security Definer)
CREATE OR REPLACE FUNCTION public.get_my_plan_ids()
RETURNS SETOF uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Directly query table to avoid recursion
    RETURN QUERY SELECT plan_id FROM public.plan_members WHERE user_id = auth.uid();
END;
$$;

-- 4. NEW SIMPLE POLICIES
ALTER TABLE public.plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.plan_members ENABLE ROW LEVEL SECURITY;

-- Plans: View if Creator OR Member (using safe function)
CREATE POLICY "Plans_Select_Safe" ON public.plans FOR SELECT
USING ( creator_id = auth.uid() OR id IN (SELECT get_my_plan_ids()) );

CREATE POLICY "Plans_Insert_Safe" ON public.plans FOR INSERT
WITH CHECK ( auth.uid() = creator_id );

CREATE POLICY "Plans_All_Safe" ON public.plans FOR ALL
USING ( creator_id = auth.uid() OR id IN (SELECT get_my_plan_ids()) );

-- Members: View if in same plan
CREATE POLICY "Members_Select_Safe" ON public.plan_members FOR SELECT
USING ( plan_id IN (SELECT get_my_plan_ids()) );

CREATE POLICY "Members_Self_Insert" ON public.plan_members FOR INSERT
WITH CHECK ( auth.uid() = user_id );

CREATE POLICY "Members_All_Safe" ON public.plan_members FOR ALL
USING ( plan_id IN (SELECT get_my_plan_ids()) );

-- 5. AUTO BUDGET TRIGGER (Re-apply purely to be safe)
CREATE OR REPLACE FUNCTION public.auto_add_to_budget()
RETURNS TRIGGER SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO public.payment_trackers (plan_id, user_id)
  VALUES (NEW.plan_id, NEW.user_id) ON CONFLICT DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_member_joined_budget ON public.plan_members;
CREATE TRIGGER on_member_joined_budget
AFTER INSERT ON public.plan_members
FOR EACH ROW EXECUTE FUNCTION public.auto_add_to_budget();

-- 6. Grant Permissions (Just in case)
GRANT USAGE ON SCHEMA public TO postgres, anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO postgres, anon, authenticated, service_role;
