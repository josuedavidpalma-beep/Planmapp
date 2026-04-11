-- Adding status column to expenses table to support draft/published states
ALTER TABLE public.expenses 
ADD COLUMN IF NOT EXISTS status text DEFAULT 'published';

-- Update existing expenses to be 'published'
UPDATE public.expenses 
SET status = 'published' 
WHERE status IS NULL;
