-- Add missing triggers to fcm-dispatcher

-- 1. Polls (Creation)
DROP TRIGGER IF EXISTS on_polls_insert_fcm ON public.polls;
CREATE TRIGGER on_polls_insert_fcm
AFTER INSERT ON public.polls
FOR EACH ROW
EXECUTE FUNCTION public.trigger_fcm_webhook();

-- 2. Payment Receipts (Creation)
DROP TRIGGER IF EXISTS on_payment_receipts_insert_fcm ON public.payment_receipts;
CREATE TRIGGER on_payment_receipts_insert_fcm
AFTER INSERT ON public.payment_receipts
FOR EACH ROW
EXECUTE FUNCTION public.trigger_fcm_webhook();

-- 3. Payment Receipts (Update - for approvals/rejections)
DROP TRIGGER IF EXISTS on_payment_receipts_update_fcm ON public.payment_receipts;
CREATE TRIGGER on_payment_receipts_update_fcm
AFTER UPDATE ON public.payment_receipts
FOR EACH ROW
WHEN (OLD.status IS DISTINCT FROM NEW.status AND NEW.status IN ('approved', 'rejected'))
EXECUTE FUNCTION public.trigger_fcm_webhook();
