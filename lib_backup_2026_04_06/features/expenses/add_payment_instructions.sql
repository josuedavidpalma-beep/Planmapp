-- Add payment_instructions column to store Nequi/Bank details
ALTER TABLE public.expenses 
ADD COLUMN IF NOT EXISTS payment_instructions TEXT;

-- Update RLS if needed (usually not if policies cover 'all columns')
-- Existing policies on 'expenses' should be fine as they allow INSERT/SELECT based on plan membership.
