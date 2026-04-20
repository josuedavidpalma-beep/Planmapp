-- Migration: Add Fiabilidad (Reputation Score) System
-- Created at: 2026-04-20

ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS reputation_score INT DEFAULT 100;

-- Function to handle reputation changes
CREATE OR REPLACE FUNCTION handle_payment_reputation()
RETURNS TRIGGER AS $$
DECLARE
    time_taken INTERVAL;
    points INT;
BEGIN
    -- Only act if status changed to 'paid' and it was 'pending' before
    IF NEW.status = 'paid' AND OLD.status != 'paid' THEN
        -- Only apply if it's a registered user, not a guest
        IF NEW.user_id IS NOT NULL THEN
            time_taken := NOW() - OLD.created_at;
            
            IF EXTRACT(EPOCH FROM time_taken) < 172800 THEN -- 48 hours in seconds
                points := 5;
            ELSE
                points := -2;
            END IF;
            
            UPDATE public.profiles 
            SET reputation_score = GREATEST(reputation_score + points, 0)
            WHERE id = NEW.user_id;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger
DROP TRIGGER IF EXISTS trg_payment_reputation ON public.payment_trackers;
CREATE TRIGGER trg_payment_reputation
AFTER UPDATE ON public.payment_trackers
FOR EACH ROW
EXECUTE FUNCTION handle_payment_reputation();
