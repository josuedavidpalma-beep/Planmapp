-- =============================================================================
-- MIGRATION: RPC to Bypass RLS for My Plans
-- Description: Provides a direct SECURITY DEFINER function to retrieve plans
-- bypassing complex RLS policies that might be failing.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.get_my_plans(p_is_chat BOOLEAN)
RETURNS SETOF public.plans
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT * FROM public.plans
  WHERE (
      creator_id = auth.uid() 
      OR id IN (SELECT plan_id FROM public.plan_members WHERE user_id = auth.uid())
  )
  AND (
      is_direct_chat = p_is_chat 
      OR (p_is_chat = false AND is_direct_chat IS NULL)
  )
  AND deleted_at IS NULL
  AND archived_at IS NULL
  AND title != '__PLANMAPP_TOOLS_MODE__'
  ORDER BY created_at DESC;
$$;
