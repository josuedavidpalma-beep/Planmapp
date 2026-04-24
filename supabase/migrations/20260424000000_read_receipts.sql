-- Migration: Add read_by array to messages tables for WhatsApp-style read receipts
-- 2026-04-23_read_receipts.sql

ALTER TABLE public.messages 
ADD COLUMN IF NOT EXISTS read_by text[] DEFAULT '{}'::text[];


CREATE OR REPLACE FUNCTION mark_messages_read(p_plan_id text, p_user_id text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.messages
  SET read_by = array_append(read_by, p_user_id)
  WHERE plan_id = p_plan_id AND (read_by IS NULL OR NOT (read_by @> ARRAY[p_user_id]::text[]));
END;
$$;
