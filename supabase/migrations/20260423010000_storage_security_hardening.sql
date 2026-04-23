-- Security hardening for storage objects

DROP POLICY IF EXISTS " Enable read access for all on payment_vouchers\ ON storage.objects;

-- Only allow users to select/list their OWN uploaded vouchers, but the public URL still works via opaque UUIDs.
CREATE POLICY \Read own vouchers\ ON storage.objects FOR SELECT TO authenticated USING ( bucket_id = 'payment_vouchers' AND (storage.foldername(name))[1] = auth.uid()::text );

-- Deletion allowed only by the owner
CREATE POLICY \Delete own vouchers\ ON storage.objects FOR DELETE TO authenticated USING ( bucket_id = 'payment_vouchers' AND (storage.foldername(name))[1] = auth.uid()::text );
