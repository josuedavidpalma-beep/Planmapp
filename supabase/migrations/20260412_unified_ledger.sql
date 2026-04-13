ALTER TABLE public.payment_trackers 
ADD COLUMN IF NOT EXISTS bill_id uuid REFERENCES public.bills(id) ON DELETE CASCADE,
ADD COLUMN IF NOT EXISTS description text;
