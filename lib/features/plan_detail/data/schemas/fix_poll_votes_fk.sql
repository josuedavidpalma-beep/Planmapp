-- Force fix of the relationship
-- First, drop the valid constraint if it exists (maybe it points to auth.users?)
ALTER TABLE poll_votes DROP CONSTRAINT IF EXISTS poll_votes_user_id_fkey;

-- Now recreate it explicitly pointing to PUBLIC.PROFILES
ALTER TABLE poll_votes
ADD CONSTRAINT poll_votes_user_id_fkey
FOREIGN KEY (user_id)
REFERENCES public.profiles(id)
ON DELETE CASCADE;

-- Refresh schema cache (usually automatic, but changing constraint helps)
NOTIFY pgrst, 'reload config';
