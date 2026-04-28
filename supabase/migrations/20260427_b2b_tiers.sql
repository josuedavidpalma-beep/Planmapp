-- Añadir campos para integración de Tiers B2B con la sección Explorar

ALTER TABLE public.restaurants
ADD COLUMN IF NOT EXISTS google_place_id TEXT UNIQUE,
ADD COLUMN IF NOT EXISTS is_verified BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS whatsapp_link TEXT,
ADD COLUMN IF NOT EXISTS promo_text TEXT,
ADD COLUMN IF NOT EXISTS is_featured BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS google_maps_url TEXT;

-- Crear un índice en google_place_id para búsquedas ultra rápidas desde el Feed Explorar
CREATE INDEX IF NOT EXISTS idx_restaurants_google_place_id ON public.restaurants(google_place_id);

-- Añadir campos para el Dashboard de KPIs (Admin)
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS origin TEXT DEFAULT 'organic';

ALTER TABLE public.plans
ADD COLUMN IF NOT EXISTS plan_type TEXT DEFAULT 'organized';
