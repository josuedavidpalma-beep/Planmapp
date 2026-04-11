-- ==============================================================================
-- SECURE GUEST ACCESS ("Web Guest Flow")
-- ==============================================================================
-- This script implements the "Link de Cobro Rápido" functionality securely.
-- Instead of exposing tables with RLS (which risks exposing lists), we use a
-- SECURITY DEFINER function that returns specific data for a valid plan UUID only.
-- This meets strict requirements: Public Access ONLY if ID is known. No SELECT *.

-- 1. Create the Function
CREATE OR REPLACE FUNCTION get_guest_plan_summary(p_plan_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER -- Runs with privileges of the creator (postgres/admin), bypassing RLS
SET search_path = public -- Secure search path
AS $$
DECLARE
    v_plan_title text;
    v_event_date timestamp with time zone;
    v_location text;
    v_total_debt numeric;
    v_items json;
BEGIN
    -- 1. Validate existence and fetch basic info
    SELECT title, event_date, location_name
    INTO v_plan_title, v_event_date, v_location
    FROM plans
    WHERE id = p_plan_id;

    IF NOT FOUND THEN
        -- Return null to indicate invalid ID (or handle as error in client)
        RETURN json_build_object('error', 'Plan not found');
    END IF;

    -- 2. Fetch all expenses and items for this plan to build the structure
    -- We want to return a summary. Front-end will filter by "Guest Name".
    -- To facilitate the frontend "Search Name", we return a list of debts.
    -- SECURITY NOTE: This exposes the names of participants to anyone with the link.
    -- Acceptable for "Plan Sharing".

    WITH plan_expenses AS (
        SELECT id, title, total_amount, currency
        FROM expenses
        WHERE plan_id = p_plan_id
    ),
    all_debts AS (
        -- Combine registered users and guests debts
        SELECT 
            coalesce(u.display_name, u.email, 'Usuario') as name,
            u.id as user_id,
            null as guest_name,
            sum(ps.amount_owed) as total_owed,
            array_agg(json_build_object('expense', e.title, 'amount', ps.amount_owed)) as details
        FROM expense_participant_status ps
        JOIN expenses e ON e.id = ps.expense_id
        JOIN profiles u ON u.id = ps.user_id
        WHERE e.plan_id = p_plan_id AND ps.is_paid = false
        GROUP BY u.id, u.display_name, u.email
        
        UNION ALL
        
        SELECT 
            ps.guest_name as name,
            null as user_id,
            ps.guest_name,
            sum(ps.amount_owed) as total_owed,
            array_agg(json_build_object('expense', e.title, 'amount', ps.amount_owed)) as details
        FROM expense_participant_status ps
        JOIN expenses e ON e.id = ps.expense_id
        WHERE e.plan_id = p_plan_id AND ps.user_id IS NULL AND ps.guest_name IS NOT NULL AND ps.is_paid = false
        GROUP BY ps.guest_name
    )
    SELECT json_agg(row_to_json(d)) INTO v_items FROM all_debts d;

    -- 3. Construct Final JSON
    RETURN json_build_object(
        'plan_id', p_plan_id,
        'title', v_plan_title,
        -- Format date nicely if needed, or send raw
        'event_date', v_event_date, 
        'location', v_location,
        'debts_summary', coalesce(v_items, '[]'::json)
    );
END;
$$;

-- 2. Grant Access to Anonymous Users
GRANT EXECUTE ON FUNCTION get_guest_plan_summary(uuid) TO anon;
GRANT EXECUTE ON FUNCTION get_guest_plan_summary(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION get_guest_plan_summary(uuid) TO service_role;

-- 3. Ensure Tables are NOT publicly readable directly (Strict Requirement)
-- Revoke just in case they were granted previously, or ensure RLS is ENABLED.
ALTER TABLE plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE expense_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE expense_participant_status ENABLE ROW LEVEL SECURITY;

-- Note: We do NOT need to add policies for 'anon' because the function bypasses them (SECURITY DEFINER).
-- This fulfills: "No quiero que un usuario anónimo pueda hacer un SELECT * FROM planes".
-- They can ONLY call this function with a specific UUID.

