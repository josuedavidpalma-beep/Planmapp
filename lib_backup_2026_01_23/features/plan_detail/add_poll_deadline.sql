ALTER TABLE polls 
ADD COLUMN expires_at TIMESTAMP WITH TIME ZONE NULL;

-- Comment on column
COMMENT ON COLUMN polls.expires_at IS 'Optional deadline for the poll. If null, poll never expires.';
