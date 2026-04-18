-- Migration: Atomic toggle array function for expense_assignments
-- Created at: 2026-04-17

CREATE OR REPLACE FUNCTION toggle_expense_assignment(
  p_item_id UUID,
  p_user_id UUID,
  p_guest_name TEXT,
  p_qty NUMERIC
) RETURNS void AS $$
DECLARE
  v_exists BOOLEAN;
BEGIN
  -- Check if assignment exists
  IF p_user_id IS NOT NULL THEN
    SELECT true INTO v_exists FROM expense_assignments WHERE expense_item_id = p_item_id AND user_id = p_user_id;
  ELSE
    SELECT true INTO v_exists FROM expense_assignments WHERE expense_item_id = p_item_id AND guest_name = p_guest_name;
  END IF;

  IF v_exists THEN
    IF p_qty <= 0 THEN
      -- Delete
      IF p_user_id IS NOT NULL THEN
        DELETE FROM expense_assignments WHERE expense_item_id = p_item_id AND user_id = p_user_id;
      ELSE
        DELETE FROM expense_assignments WHERE expense_item_id = p_item_id AND guest_name = p_guest_name;
      END IF;
    ELSE
      -- Update
      IF p_user_id IS NOT NULL THEN
        UPDATE expense_assignments SET quantity = p_qty WHERE expense_item_id = p_item_id AND user_id = p_user_id;
      ELSE
        UPDATE expense_assignments SET quantity = p_qty WHERE expense_item_id = p_item_id AND guest_name = p_guest_name;
      END IF;
    END IF;
  ELSE
    IF p_qty > 0 THEN
      -- Insert
      INSERT INTO expense_assignments (expense_item_id, user_id, guest_name, quantity) 
      VALUES (p_item_id, p_user_id, p_guest_name, p_qty);
    END IF;
  END IF;
END;
$$ LANGUAGE plpgsql;
