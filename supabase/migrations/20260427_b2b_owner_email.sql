-- Añadir campo de correo del dueño a la tabla de restaurantes
ALTER TABLE public.restaurants
ADD COLUMN IF NOT EXISTS owner_email TEXT;
