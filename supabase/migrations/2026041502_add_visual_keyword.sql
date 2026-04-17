
-- Migration: Add visual_keyword column to local_events
ALTER TABLE public.local_events 
ADD COLUMN IF NOT EXISTS visual_keyword TEXT;
