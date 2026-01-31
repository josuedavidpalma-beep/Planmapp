-- Migration to add 'metadata' column to 'messages' table if it doesn't exist
ALTER TABLE public.messages 
ADD COLUMN IF NOT EXISTS metadata jsonb DEFAULT '{}'::jsonb;

-- Update the schema cache (handled automatically by Supabase usually, but good to know)
NOTIFY pgrst, 'reload schema';
