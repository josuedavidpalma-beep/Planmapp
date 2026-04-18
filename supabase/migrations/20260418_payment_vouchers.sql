-- Create Storage Bucket for Vouchers if it doesn't exist
insert into storage.buckets (id, name, public)
values ('payment_vouchers', 'payment_vouchers', true)
on conflict (id) do nothing;

-- Ensure the public policy allows reading
drop policy if exists "Enable read access for all on payment_vouchers" on storage.objects;
create policy "Enable read access for all on payment_vouchers"
on storage.objects for select using ( bucket_id = 'payment_vouchers' );

-- Ensure authenticated users can upload
drop policy if exists "Enable insert for authenticated users on payment_vouchers" on storage.objects;
create policy "Enable insert for authenticated users on payment_vouchers"
on storage.objects for insert to authenticated with check ( bucket_id = 'payment_vouchers' );

-- Add column to expense_participant_status
ALTER TABLE public.expense_participant_status 
ADD COLUMN IF NOT EXISTS receipt_url TEXT;

-- Create Trigger for INSERTS on polls (for new poll notifications)
DROP TRIGGER IF EXISTS on_polls_insert_fcm ON public.polls;
CREATE TRIGGER on_polls_insert_fcm
AFTER INSERT ON public.polls
FOR EACH ROW
EXECUTE FUNCTION public.trigger_fcm_webhook();
