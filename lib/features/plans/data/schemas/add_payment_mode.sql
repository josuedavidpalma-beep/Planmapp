-- Add payment_mode column to plans table for Itinerary 2.0
-- Values: 'individual', 'pool', 'guest', 'split'
ALTER TABLE plans ADD COLUMN IF NOT EXISTS payment_mode text DEFAULT 'individual';

-- Optional: Check constraint to ensure valid values
ALTER TABLE plans ADD CONSTRAINT valid_payment_mode CHECK (payment_mode IN ('individual', 'pool', 'guest', 'split'));
