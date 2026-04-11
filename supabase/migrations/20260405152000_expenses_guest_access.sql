-- ==========================================
-- SQL Migration: Guest Access for Expenses
-- ==========================================

-- 1. Enable RLS on all related tables
ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expense_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expense_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expense_participant_status ENABLE ROW LEVEL SECURITY;

-- 2. POLICIES FOR 'expenses'
DROP POLICY IF EXISTS "Anyone can select expense by ID" ON public.expenses;
CREATE POLICY "Anyone can select expense by ID" ON public.expenses 
FOR SELECT USING (true); -- Scope is handled by the knowledge of UUID

DROP POLICY IF EXISTS "Admins can manage expenses" ON public.expenses;
CREATE POLICY "Admins can manage expenses" ON public.expenses 
FOR ALL USING (auth.uid() = created_by);

-- 3. POLICIES FOR 'expense_items'
DROP POLICY IF EXISTS "Anyone can select items" ON public.expense_items;
CREATE POLICY "Anyone can select items" ON public.expense_items 
FOR SELECT USING (true);

DROP POLICY IF EXISTS "Admins can manage items" ON public.expense_items;
CREATE POLICY "Admins can manage items" ON public.expense_items 
FOR ALL USING (
    EXISTS (SELECT 1 FROM public.expenses WHERE id = expense_id AND created_by = auth.uid())
);

-- 4. POLICIES FOR 'expense_assignments' (The core of guest splitting)
DROP POLICY IF EXISTS "Anyone can select assignments" ON public.expense_assignments;
CREATE POLICY "Anyone can select assignments" ON public.expense_assignments 
FOR SELECT USING (true);

DROP POLICY IF EXISTS "Anyone can join an item" ON public.expense_assignments;
CREATE POLICY "Anyone can join an item" ON public.expense_assignments 
FOR INSERT WITH CHECK (
    -- Allow if unauthenticated (anon) OR if authenticated
    (auth.role() = 'anon' AND guest_name IS NOT NULL) OR (auth.uid() IS NOT NULL)
);

DROP POLICY IF EXISTS "Users/Guests can update/delete their own assignments" ON public.expense_assignments;
CREATE POLICY "Users/Guests can update/delete their own assignments" ON public.expense_assignments 
FOR ALL USING (
    (auth.uid() = user_id) OR (guest_name IS NOT NULL AND auth.role() = 'anon')
);

-- 5. POLICIES FOR 'expense_participant_status' (Debt Tracking)
DROP POLICY IF EXISTS "Anyone can view their debt status" ON public.expense_participant_status;
CREATE POLICY "Anyone can view their debt status" ON public.expense_participant_status 
FOR SELECT USING (true);

DROP POLICY IF EXISTS "Guests can report payments or see their share" ON public.expense_participant_status;
CREATE POLICY "Guests can report payments or see their share" ON public.expense_participant_status 
FOR ALL USING (
    (auth.uid() = user_id) OR (guest_name IS NOT NULL AND auth.role() = 'anon')
);
