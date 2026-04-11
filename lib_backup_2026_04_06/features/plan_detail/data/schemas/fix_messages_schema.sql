-- FIX: Add missing 'type' column to messages table
-- This is required for Chat, Roulette, and System Messages to work.

ALTER TABLE messages 
ADD COLUMN IF NOT EXISTS type TEXT DEFAULT 'text';

ALTER TABLE messages 
ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}'::jsonb;

-- Update existing rows to have a default type if they are system messages or text
UPDATE messages SET type = 'system' WHERE is_system_message = true AND type IS NULL;
UPDATE messages SET type = 'text' WHERE type IS NULL;
