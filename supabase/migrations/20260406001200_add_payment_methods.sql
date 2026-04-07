-- Add payment_methods column to profiles table
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS payment_methods JSONB DEFAULT '[]'::jsonb;

-- Typical structure of payment_methods array:
-- [
--   {
--     "type": "Nequi",
--     "number": "3001234567"
--   },
--   {
--     "type": "Bancolombia",
--     "number": "Ahorros 123-456789-01"
--   }
-- ]
