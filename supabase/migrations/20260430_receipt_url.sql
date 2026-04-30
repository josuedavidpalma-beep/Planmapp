-- Agregar campo para la foto del comprobante de pago
ALTER TABLE public.payment_trackers ADD COLUMN IF NOT EXISTS receipt_url TEXT;
