-- Formalizing Payment Status logic in expense_participant_status
ALTER TABLE public.expense_participant_status 
ADD COLUMN IF NOT EXISTS status text DEFAULT 'pending';

-- Make sure existing null statuses become 'pending'
UPDATE public.expense_participant_status 
SET status = 'pending' 
WHERE status IS NULL;
