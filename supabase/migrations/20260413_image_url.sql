-- Añadir imagen referencial a los planes
ALTER TABLE public.plans ADD COLUMN IF NOT EXISTS image_url text;
