-- Add metadata column to messages table to support richer content
ALTER TABLE public.messages 
ADD COLUMN IF NOT EXISTS metadata jsonb DEFAULT '{}'::jsonb;
