-- Add type to polls
ALTER TABLE public.polls 
ADD COLUMN IF NOT EXISTS type text DEFAULT 'text'; -- 'text', 'date', 'time', 'items'

-- Add quantity to poll_options
ALTER TABLE public.poll_options 
ADD COLUMN IF NOT EXISTS quantity integer DEFAULT 1;

NOTIFY pgrst, 'reload schema';
