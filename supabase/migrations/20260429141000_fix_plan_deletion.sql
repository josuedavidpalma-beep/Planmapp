-- =============================================================================
-- MIGRATION: Fix Plan Deletion
-- Description: Drops the trigger that attempts to directly DELETE FROM storage.objects
-- which is now forbidden by Supabase (Code 42501).
-- =============================================================================

DROP TRIGGER IF EXISTS trigger_delete_plan_storage ON public.plans;
DROP FUNCTION IF EXISTS public.delete_plan_storage_objects();
