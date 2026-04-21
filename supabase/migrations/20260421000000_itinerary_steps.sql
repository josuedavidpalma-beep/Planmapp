-- Añadir soporte nativo para pasos de itinerario generados por IA
ALTER TABLE plans ADD COLUMN IF NOT EXISTS itinerary_steps JSONB DEFAULT '[]'::jsonb;
