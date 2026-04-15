
-- Add reservation_link and contact_info to plans table
ALTER TABLE public.plans 
ADD COLUMN IF NOT EXISTS reservation_link TEXT,
ADD COLUMN IF NOT EXISTS contact_info TEXT;

-- Update RLS if needed (already broad for members usually)
