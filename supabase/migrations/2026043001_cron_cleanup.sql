-- ==========================================
-- SQL Migration: Automated Cleanup & Cron Jobs
-- ==========================================
-- Objective: Automatically clean up old plans/events (> 14 days) and inactive anonymous users
-- to maintain database performance and reduce storage costs.

-- 1. Function to clean up Anonymous Users inactive for more than 14 days
CREATE OR REPLACE FUNCTION public.cleanup_inactive_guests()
RETURNS void AS $$
BEGIN
  -- We delete from auth.users. Supabase's ON DELETE CASCADE will handle public.profiles and related data.
  DELETE FROM auth.users
  WHERE is_anonymous = true
  AND (last_sign_in_at < NOW() - INTERVAL '14 days' OR (last_sign_in_at IS NULL AND created_at < NOW() - INTERVAL '14 days'));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Function to clean up old Local Events (Scraped events)
CREATE OR REPLACE FUNCTION public.cleanup_old_local_events()
RETURNS void AS $$
BEGIN
  DELETE FROM public.local_events
  WHERE date < NOW() - INTERVAL '14 days';
END;
$$ LANGUAGE plpgsql;

-- 3. Function to clean up old User Plans
CREATE OR REPLACE FUNCTION public.cleanup_old_plans()
RETURNS void AS $$
BEGIN
  DELETE FROM public.plans
  WHERE date_time < NOW() - INTERVAL '14 days';
END;
$$ LANGUAGE plpgsql;

-- 4. Storage Cleanup Triggers
-- When a plan is deleted, we must also delete its image from the plans_images bucket
CREATE OR REPLACE FUNCTION public.delete_plan_storage_file()
RETURNS TRIGGER AS $$
DECLARE
  file_path TEXT;
BEGIN
  IF OLD.image_url IS NOT NULL AND OLD.image_url LIKE '%/storage/v1/object/public/plans_images/%' THEN
    file_path := substring(OLD.image_url from '%/storage/v1/object/public/plans_images/(.*)');
    DELETE FROM storage.objects WHERE bucket_id = 'plans_images' AND name = file_path;
  END IF;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_delete_plan_storage ON public.plans;
CREATE TRIGGER tr_delete_plan_storage
AFTER DELETE ON public.plans
FOR EACH ROW EXECUTE FUNCTION public.delete_plan_storage_file();

-- When a payment tracker is deleted (via cascade from plans or manually), delete its receipt image
CREATE OR REPLACE FUNCTION public.delete_receipt_storage_file()
RETURNS TRIGGER AS $$
DECLARE
  file_path TEXT;
BEGIN
  IF OLD.receipt_url IS NOT NULL AND OLD.receipt_url LIKE '%/storage/v1/object/public/payment_vouchers/%' THEN
    file_path := substring(OLD.receipt_url from '%/storage/v1/object/public/payment_vouchers/(.*)');
    DELETE FROM storage.objects WHERE bucket_id = 'payment_vouchers' AND name = file_path;
  END IF;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_delete_receipt_storage ON public.payment_trackers;
CREATE TRIGGER tr_delete_receipt_storage
AFTER DELETE ON public.payment_trackers
FOR EACH ROW EXECUTE FUNCTION public.delete_receipt_storage_file();

-- 5. Unified Cleanup Wrapper
CREATE OR REPLACE FUNCTION public.run_daily_maintenance()
RETURNS void AS $$
BEGIN
  PERFORM public.cleanup_inactive_guests();
  PERFORM public.cleanup_old_local_events();
  PERFORM public.cleanup_old_plans();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. Setup pg_cron to run every day at 3:00 AM
-- Note: This requires the pg_cron extension to be enabled in Supabase.
DO $$
BEGIN
  -- Check if pg_cron is available
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    -- Try to unschedule if it exists, ignore error if it doesn't
    BEGIN
      PERFORM cron.unschedule('daily_maintenance_job');
    EXCEPTION WHEN OTHERS THEN
      -- Ignore
    END;
    -- Schedule to run at 3:00 AM every day
    PERFORM cron.schedule('daily_maintenance_job', '0 3 * * *', 'SELECT public.run_daily_maintenance()');
  END IF;
END $$;
