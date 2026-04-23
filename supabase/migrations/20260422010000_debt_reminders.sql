-- Add last_notified_at to payment_trackers
ALTER TABLE public.payment_trackers ADD COLUMN IF NOT EXISTS last_notified_at TIMESTAMP WITH TIME ZONE;

-- Enable pg_cron (if not already enabled)
CREATE EXTENSION IF NOT EXISTS pg_cron;
-- Enable pg_net to make HTTP requests from inside pg_cron (if not already enabled)
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Create the scheduled job for daily debt verification
-- This is scheduled to run every day at 12:00 UTC
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM cron.job WHERE jobname = 'daily-debt-reminders'
  ) THEN
    PERFORM cron.schedule(
      'daily-debt-reminders',
      '0 12 * * *',
      $$
      SELECT net.http_post(
          url:='https://pthiaalrizufhlplbjht.supabase.co/functions/v1/notify-debts',
          headers:='{"Content-Type": "application/json"}'
      );
      $$
    );
  END IF;
END $$;
