-- Create Logistics Table (Collaborative Checklist)
CREATE TABLE IF NOT EXISTS logistics_items (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    plan_id uuid REFERENCES plans(id) ON DELETE CASCADE,
    description text NOT NULL,
    assigned_user_id uuid REFERENCES profiles(id) ON DELETE SET NULL,
    assigned_guest_name text,
    is_completed boolean DEFAULT false,
    creator_id uuid REFERENCES auth.users(id),
    created_at timestamp with time zone DEFAULT now()
);

-- RLS
ALTER TABLE logistics_items ENABLE ROW LEVEL SECURITY;

-- Allow read/write for plan members/participants
CREATE POLICY "Enable read for plan participants" ON logistics_items
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM plan_members pm 
            WHERE pm.plan_id = logistics_items.plan_id 
            AND pm.user_id = auth.uid()
        )
        OR 
        EXISTS (SELECT 1 FROM plans WHERE id = logistics_items.plan_id AND creator_id = auth.uid())
    );

CREATE POLICY "Enable insert for plan participants" ON logistics_items
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM plan_members pm 
            WHERE pm.plan_id = logistics_items.plan_id 
            AND pm.user_id = auth.uid()
        )
        OR 
        EXISTS (SELECT 1 FROM plans WHERE id = logistics_items.plan_id AND creator_id = auth.uid())
    );

CREATE POLICY "Enable update for plan participants" ON logistics_items
    FOR UPDATE USING (
        EXISTS (
             SELECT 1 FROM plan_members pm 
            WHERE pm.plan_id = logistics_items.plan_id 
            AND pm.user_id = auth.uid()
        )
        OR 
        EXISTS (SELECT 1 FROM plans WHERE id = logistics_items.plan_id AND creator_id = auth.uid())
    );

CREATE POLICY "Enable delete for creator or item owner" ON logistics_items
    FOR DELETE USING (
        creator_id = auth.uid() 
        OR 
        EXISTS (SELECT 1 FROM plans WHERE id = logistics_items.plan_id AND creator_id = auth.uid())
    );
