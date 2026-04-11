-- Migration: Add onboarding profile fields
-- Date: 2026-04-11
-- Adds nickname, birth_date, budget_level and interests to profiles table

ALTER TABLE public.profiles 
  ADD COLUMN IF NOT EXISTS nickname TEXT,
  ADD COLUMN IF NOT EXISTS birth_date DATE,
  ADD COLUMN IF NOT EXISTS budget_level TEXT DEFAULT 'bacano' CHECK (budget_level IN ('economico', 'bacano', 'play')),
  ADD COLUMN IF NOT EXISTS interests TEXT[] DEFAULT '{}';

-- Index for matching friends by common interests
CREATE INDEX IF NOT EXISTS idx_profiles_interests ON public.profiles USING GIN(interests);

-- Comment the columns for documentation
COMMENT ON COLUMN public.profiles.nickname IS 'Friendly name shown in plans e.g. El Checho, La Negra';
COMMENT ON COLUMN public.profiles.birth_date IS 'Used for age-appropriate plan suggestions';
COMMENT ON COLUMN public.profiles.budget_level IS 'economico | bacano | play - Used for AI plan matching';
COMMENT ON COLUMN public.profiles.interests IS 'Array of interest keys: gastronomia, vida_nocturna, deporte, cultura, aventura, chill';
