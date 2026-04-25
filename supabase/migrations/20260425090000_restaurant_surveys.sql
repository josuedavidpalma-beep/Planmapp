-- Añadir configuración de encuestas para el sistema B2B2C

ALTER TABLE public.restaurants 
ADD COLUMN IF NOT EXISTS survey_settings JSONB DEFAULT '{"questions": ["¿Cómo calificarías tu experiencia?", "¿Qué podríamos mejorar?"]}';

-- Asegurar políticas para lectura publica de información del restaurante (necesario para cuando el invitado lea la encuesta)
CREATE POLICY "Anyone can read restaurants" ON public.restaurants FOR SELECT USING (true);
