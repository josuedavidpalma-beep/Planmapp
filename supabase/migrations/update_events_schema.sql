-- Add new columns for enhanced event details
ALTER TABLE public.events 
ADD COLUMN IF NOT EXISTS end_date TEXT,
ADD COLUMN IF NOT EXISTS address TEXT,
ADD COLUMN IF NOT EXISTS contact_info TEXT;

-- Comment on columns for clarity
COMMENT ON COLUMN public.events.end_date IS 'Closing date of the event in YYYY-MM-DD format if applicable';
COMMENT ON COLUMN public.events.address IS 'Physical address of the event venue';
COMMENT ON COLUMN public.events.contact_info IS 'Phone number, email, or social handle for inquiries';
