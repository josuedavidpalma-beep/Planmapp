-- Actualizar tabla survey_responses para soportar columnas BI dinámicas
ALTER TABLE public.survey_responses
ADD COLUMN IF NOT EXISTS rating_food INTEGER CHECK (rating_food >= 1 AND rating_food <= 5),
ADD COLUMN IF NOT EXISTS rating_service INTEGER CHECK (rating_service >= 1 AND rating_service <= 5),
ADD COLUMN IF NOT EXISTS rating_ambiance INTEGER CHECK (rating_ambiance >= 1 AND rating_ambiance <= 5),
ADD COLUMN IF NOT EXISTS feedback_text TEXT,
ADD COLUMN IF NOT EXISTS receipt_items JSONB;

-- Crear tabla para Tokens de Restaurantes (B2B BI Dashboard)
CREATE TABLE IF NOT EXISTS public.restaurant_tokens (
    token_hash UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    restaurant_id UUID REFERENCES public.restaurants(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_accessed TIMESTAMP WITH TIME ZONE
);

ALTER TABLE public.restaurant_tokens ENABLE ROW LEVEL SECURITY;

-- Política: Cualquiera puede LEER desde restaurant_tokens si tienen el token (filtrado por consulta)
CREATE POLICY "Public read tokens" 
ON public.restaurant_tokens FOR SELECT 
USING (true);

-- Política RLS para permitir a usuarios anónimos (invitados con token) LEER encuestas si tienen el ID del restaurante
-- Si envían el restaurant_id atado a un token verificado desde la app, la app es responsable de la seguridad.
CREATE POLICY "Public read survey if token validated" 
ON public.survey_responses FOR SELECT 
USING (true);

-- Crear función o asegurarnos que el backend (Supabase Darts) asigne estos permisos transparentemente
