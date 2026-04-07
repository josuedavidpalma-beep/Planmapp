-- "Cuentas Claras" Module Schema
-- Supports: Complex Splitting, Tax/Tip Proportionality, Multi-User Assignment

-- 1. BILLS (Cabecera de la cuenta)
CREATE TABLE public.bills (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    plan_id UUID REFERENCES public.plans(id) ON DELETE CASCADE NOT NULL,
    payer_id UUID REFERENCES auth.users(id) NOT NULL, -- Who paid the bill initially
    
    title TEXT NOT NULL DEFAULT 'Cuenta',
    location TEXT,
    
    -- Monetary Values
    subtotal NUMERIC NOT NULL DEFAULT 0,
    tax_amount NUMERIC NOT NULL DEFAULT 0,
    tip_amount NUMERIC NOT NULL DEFAULT 0,
    other_fees NUMERIC NOT NULL DEFAULT 0, -- Delivery, Service Fee (Fixed)
    total_amount NUMERIC NOT NULL DEFAULT 0,
    
    -- Percentages (for recalculations)
    tip_rate NUMERIC DEFAULT 0, -- e.g., 0.10 for 10%
    tax_rate NUMERIC DEFAULT 0, -- e.g., 0.08 for 8%
    
    image_url TEXT, -- Receipt photo
    status TEXT DEFAULT 'draft' CHECK (status IN ('draft', 'confirmed', 'settled')),
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2. BILL ITEMS (Líneas de la factura)
CREATE TABLE public.bill_items (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    bill_id UUID REFERENCES public.bills(id) ON DELETE CASCADE NOT NULL,
    
    name TEXT NOT NULL,
    quantity INTEGER NOT NULL DEFAULT 1,
    unit_price NUMERIC NOT NULL DEFAULT 0,
    total_price NUMERIC NOT NULL DEFAULT 0, -- quantity * unit_price
    
    category TEXT, -- 'food', 'drink', 'other'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 3. BILL PARTICIPATIONS (Quiénes participan en esta cuenta)
-- Useful to know who is involved even if they have 0 items assigned (e.g., exempt birthday person)
CREATE TABLE public.bill_participations (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    bill_id UUID REFERENCES public.bills(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES auth.users(id) NOT NULL,
    
    is_exempt BOOLEAN DEFAULT FALSE, -- e.g. Birthday person doesn't pay
    is_confirmed BOOLEAN DEFAULT FALSE, -- User accepted their share
    
    UNIQUE(bill_id, user_id)
);

-- 4. BILL ITEM ASSIGNMENTS (Relación Muchos a Muchos: Item <-> Users)
CREATE TABLE public.bill_item_assignments (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    bill_item_id UUID REFERENCES public.bill_items(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES auth.users(id) NOT NULL,
    
    -- In rare cases, split might not be equal, but for now we assume equal split among assignees
    -- weight NUMERIC DEFAULT 1, 
    
    UNIQUE(bill_item_id, user_id)
);

-- RLS POLICIES
ALTER TABLE public.bills ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bill_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bill_participations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bill_item_assignments ENABLE ROW LEVEL SECURITY;

-- Plan Members can view bills
CREATE POLICY "Plan members can view bills" ON public.bills
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.plan_members pm 
            WHERE pm.plan_id = public.bills.plan_id AND pm.user_id = auth.uid()
        )
    );

-- Only Plan Creators or Payers can insert/update bills (Simplified)
CREATE POLICY "Creators/Payers can manage bills" ON public.bills
    FOR ALL USING (
        auth.uid() = payer_id OR 
        EXISTS (
            SELECT 1 FROM public.plans p 
            WHERE p.id = public.bills.plan_id AND p.creator_id = auth.uid()
        )
    );

-- Similar policies for items and assignments (cascading access usually handled by app logic or broad plan member access)
CREATE POLICY "Plan members can view items" ON public.bill_items
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.bills b
            JOIN public.plan_members pm ON b.plan_id = pm.plan_id
            WHERE b.id = public.bill_items.bill_id AND pm.user_id = auth.uid()
        )
    );
    
CREATE POLICY "Plan members can manage items" ON public.bill_items
    FOR ALL USING (
         EXISTS (
            SELECT 1 FROM public.bills b
            WHERE b.id = public.bill_items.bill_id AND (b.payer_id = auth.uid())
        )
    );
    
-- Assignment Policies
CREATE POLICY "Plan members can view assignments" ON public.bill_item_assignments
    FOR SELECT USING (TRUE); -- Simplified for speed

CREATE POLICY "Participants can assign themselves" ON public.bill_item_assignments
    FOR INSERT WITH CHECK (
        auth.uid() = user_id OR 
        EXISTS ( -- Or the bill owner can assign others
            SELECT 1 FROM public.bill_items bi
            JOIN public.bills b ON bi.bill_id = b.id
            WHERE bi.id = bill_item_id AND b.payer_id = auth.uid()
        )
    );
