
-- Add promo_highlights to local_events and plans
ALTER TABLE public.local_events 
ADD COLUMN IF NOT EXISTS promo_highlights TEXT;

ALTER TABLE public.plans 
ADD COLUMN IF NOT EXISTS promo_highlights TEXT;
