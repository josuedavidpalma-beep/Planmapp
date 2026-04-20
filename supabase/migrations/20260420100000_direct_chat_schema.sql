-- Migration: Add direct_chat flag to plans
-- Created at: 2026-04-20

-- Agregamos la columna boolean
ALTER TABLE public.plans ADD COLUMN IF NOT EXISTS is_direct_chat BOOLEAN DEFAULT false;

-- Add email to profiles to support querying by email
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS email text;

-- Backfill from auth.users (requires superuser or bypass rls, but this runs as postgres)
UPDATE public.profiles p
SET email = u.email
FROM auth.users u
WHERE p.id = u.id;

-- Make sure handle_new_user populates it. Let's redefine or just rely on a new trigger?
-- Since handle_new_user might be complex, let's create a backup trigger explicitly for email sync
CREATE OR REPLACE FUNCTION public.sync_profile_email()
RETURNS trigger AS $$
BEGIN
  UPDATE public.profiles SET email = new.email WHERE id = new.id;
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop if exists, then create
DROP TRIGGER IF EXISTS on_auth_user_email_sync ON auth.users;
CREATE TRIGGER on_auth_user_email_sync
  AFTER UPDATE OF email ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.sync_profile_email();
  
  -- Para los nuevos
CREATE OR REPLACE FUNCTION public.sync_new_profile_email()
RETURNS trigger AS $$
BEGIN
  -- Intentar hacer update si el handle_new_user ya lo creó, o insertarlo.
  UPDATE public.profiles SET email = new.email WHERE id = new.id;
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created_sync ON auth.users;
CREATE TRIGGER on_auth_user_created_sync
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.sync_new_profile_email();

