-- Add 'status' column to payments table for 2-step verification
ALTER TABLE payments ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'confirmed';
