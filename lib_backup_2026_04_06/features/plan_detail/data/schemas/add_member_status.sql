-- Add status column to plan_members for RSVP tracking
ALTER TABLE plan_members ADD COLUMN IF NOT EXISTS status text DEFAULT 'pending';

-- Optional: Create an index if we query by status often
CREATE INDEX IF NOT EXISTS idx_plan_members_status ON plan_members(status);
