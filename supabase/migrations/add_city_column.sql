-- Add city column to events table
ALTER TABLE events ADD COLUMN city TEXT DEFAULT 'Bogotá';

-- Update existing records if needed (already set by default, but good practice to be explicit if table wasn't empty and default didn't apply retrospectively in some SQL dialects, though Postgres does)
UPDATE events SET city = 'Bogotá' WHERE city IS NULL;
