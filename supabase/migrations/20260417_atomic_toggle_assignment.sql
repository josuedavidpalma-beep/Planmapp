-- Migration: Atomic toggle array function for bill_items
-- Created at: 2026-04-17

CREATE OR REPLACE FUNCTION toggle_bill_item_assignment(
  p_item_id UUID,
  p_user_id TEXT
) RETURNS text[] AS $$
DECLARE
  v_assigned text[];
BEGIN
  -- Get current array and lock row to prevent race conditions
  SELECT assigned_to INTO v_assigned
  FROM bill_items
  WHERE id = p_item_id
  FOR UPDATE;

  -- Toggle logic
  IF p_user_id = ANY(v_assigned) THEN
    -- Remove
    v_assigned := array_remove(v_assigned, p_user_id);
  ELSE
    -- Add
    v_assigned := array_append(v_assigned, p_user_id);
  END IF;

  -- Ensure it's not null
  IF v_assigned IS NULL THEN
    v_assigned := ARRAY[]::text[];
  END IF;

  -- Update the item
  UPDATE bill_items
  SET assigned_to = v_assigned
  WHERE id = p_item_id;

  RETURN v_assigned;
END;
$$ LANGUAGE plpgsql;
