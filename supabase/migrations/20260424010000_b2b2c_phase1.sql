-- 1. Crear la Tabla de Restaurantes Afiliados
CREATE TABLE public.restaurants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    address TEXT,
    menu_url TEXT,
    survey_schema JSONB DEFAULT '[]'::jsonb, -- Estructura de la encuesta del restaurante
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Habilitar RLS en restaurantes
ALTER TABLE public.restaurants ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can view restaurants" ON public.restaurants FOR SELECT USING (true);


-- 2. Modificar la Tabla de Planes
ALTER TABLE public.plans
    ADD COLUMN IF NOT EXISTS is_temporal BOOLEAN DEFAULT false,
    ADD COLUMN IF NOT EXISTS restaurant_id UUID REFERENCES public.restaurants(id) ON DELETE SET NULL;


-- 3. Crear la tabla permanente de Encuestas
CREATE TABLE public.survey_responses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    restaurant_id UUID REFERENCES public.restaurants(id) ON DELETE CASCADE,
    plan_id UUID, 
    responses JSONB NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Habilitar RLS en respuestas
ALTER TABLE public.survey_responses ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Only admin can view survey responses" ON public.survey_responses FOR SELECT USING (
    auth.jwt() ->> 'email' = 'Josuedavidpalma@gmail.com'
);
CREATE POLICY "Anyone can insert survey response" ON public.survey_responses FOR INSERT WITH CHECK (true);


-- 4. Sistema de Limpieza Automática (Garbage Collection via pg_cron)
CREATE EXTENSION IF NOT EXISTS pg_cron;

SELECT cron.schedule(
    'purge-temporal-plans', 
    '0 * * * *',
    $$ DELETE FROM public.plans WHERE is_temporal = true AND created_at < NOW() - INTERVAL '30 minutes' $$
);
